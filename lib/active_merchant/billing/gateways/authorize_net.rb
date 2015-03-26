require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AuthorizeNetGateway < Gateway
      include Empty

      self.test_url = 'https://apitest.authorize.net/xml/v1/request.api'
      self.live_url = 'https://api.authorize.net/xml/v1/request.api'

      self.supported_countries = %w(AD AT AU BE BG CA CH CY CZ DE DK ES FI FR GB GB GI GR HU IE IT LI LU MC MT NL NO PL PT RO SE SI SK SM TR US VA)
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb, :maestro]

      self.homepage_url = 'http://www.authorize.net/'
      self.display_name = 'Authorize.Net'

      class_attribute :duplicate_window

      APPROVED, DECLINED, ERROR, FRAUD_REVIEW = 1, 2, 3, 4
      TRANSACTION_ALREADY_ACTIONED = %w(310 311)

      CARD_CODE_ERRORS = %w(N S)
      AVS_ERRORS = %w(A E N R W Z)
      AVS_REASON_CODES = %w(27 45)

      TRACKS = {
          1 => /^%(?<format_code>.)(?<pan>[\d]{1,19}+)\^(?<name>.{2,26})\^(?<expiration>[\d]{0,4}|\^)(?<service_code>[\d]{0,3}|\^)(?<discretionary_data>.*)\?\Z/,
          2 => /\A;(?<pan>[\d]{1,19}+)=(?<expiration>[\d]{0,4}|=)(?<service_code>[\d]{0,3}|=)(?<discretionary_data>.*)\?\Z/
      }.freeze

      APPLE_PAY_DATA_DESCRIPTOR = "COMMON.APPLE.INAPP.PAYMENT"

      def initialize(options={})
        requires!(options, :login, :password)
        super
      end

      def purchase(amount, payment, options = {})
        commit("AUTH_CAPTURE") do |xml|
          add_order_id(xml, options)
          xml.transactionRequest do
            xml.transactionType('authCaptureTransaction')
            xml.amount(amount(amount))

            add_payment_source(xml, payment)
            add_invoice(xml, options)
            add_customer_data(xml, payment, options)
            add_retail_data(xml, payment)
            add_settings(xml, payment, options)
            add_user_fields(xml, amount, options)
          end
        end
      end

      def authorize(amount, payment, options={})
        commit("AUTH_ONLY") do |xml|
          add_order_id(xml, options)
          xml.transactionRequest do
            xml.transactionType('authOnlyTransaction')
            xml.amount(amount(amount))

            add_payment_source(xml, payment)
            add_invoice(xml, options)
            add_customer_data(xml, payment, options)
            add_settings(xml, payment, options)
            add_user_fields(xml, amount, options)
          end
        end
      end

      def capture(amount, authorization, options={})
        commit("PRIOR_AUTH_CAPTURE") do |xml|
          add_order_id(xml, options)
          xml.transactionRequest do
            xml.transactionType('priorAuthCaptureTransaction')
            xml.amount(amount(amount))
            xml.refTransId(split_authorization(authorization)[0])

            add_invoice(xml, options)
            add_user_fields(xml, amount, options)
          end
        end
      end

      def refund(amount, authorization, options={})
        transaction_id, card_number = split_authorization(authorization)
        commit("CREDIT") do |xml|
          xml.transactionRequest do
            xml.transactionType('refundTransaction')
            xml.amount(amount.nil? ? 0 : amount(amount))
            xml.payment do
              xml.creditCard do
                xml.cardNumber(card_number || options[:card_number])
                xml.expirationDate('XXXX')
              end
            end
            xml.refTransId(transaction_id)

            add_customer_data(xml, nil, options)
            add_user_fields(xml, amount, options)
          end
        end
      end

      def void(authorization, options={})
        commit("VOID") do |xml|
          add_order_id(xml, options)
          xml.transactionRequest do
            xml.transactionType('voidTransaction')
            xml.refTransId(split_authorization(authorization)[0])

            add_user_fields(xml, nil, options)
          end
        end
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<cardNumber>).+(</cardNumber>)), '\1[FILTERED]\2').
          gsub(%r((<cardCode>).+(</cardCode>)), '\1[FILTERED]\2')
      end

      private

      def add_payment_source(xml, source)
        return unless source
        if card_brand(source) == 'check'
          add_check(xml, source)
        elsif card_brand(source) == 'apple_pay'
          add_apple_pay_payment_token(xml, source)
        else
          add_credit_card(xml, source)
        end
      end

      def add_settings(xml, source, options)
        xml.transactionSettings do
          if card_brand(source) == "check" && options[:recurring]
            xml.setting do
              xml.settingName("recurringBilling")
              xml.settingValue("true")
            end
          end
          if options[:duplicate_window]
            set_duplicate_window(xml, options[:duplicate_window])
          elsif self.class.duplicate_window
            ActiveMerchant.deprecated "Using the duplicate_window class_attribute is deprecated. Use the transaction options hash instead."
            set_duplicate_window(xml, self.class.duplicate_window)
          end
        end
      end

      def set_duplicate_window(xml, value)
        xml.setting do
          xml.settingName("duplicateWindow")
          xml.settingValue(value)
        end
      end

      def add_user_fields(xml, amount, options)
        xml.userFields do
          if currency = (options[:currency] || currency(amount))
            xml.userField do
              xml.name("x_currency_code")
              xml.value(currency)
            end
          end
          if application_id.present? && application_id != "ActiveMerchant"
            xml.userField do
              xml.name("x_solution_id")
              xml.value(application_id)
            end
          end
        end
      end

      def add_credit_card(xml, credit_card)
        if credit_card.track_data
          add_swipe_data(xml, credit_card)
        else
          xml.payment do
            xml.creditCard do
              xml.cardNumber(credit_card.number)
              xml.expirationDate(format(credit_card.month, :two_digits) + '/' + format(credit_card.year, :four_digits))
              unless empty?(credit_card.verification_value)
                xml.cardCode(credit_card.verification_value)
              end
            end
          end
        end
      end

      def add_swipe_data(xml, credit_card)
        TRACKS.each do |key, regex|
          if regex.match(credit_card.track_data)
            @valid_track_data = true
            xml.payment do
              xml.trackData do
                xml.public_send(:"track#{key}", credit_card.track_data)
              end
            end
          end
        end
      end

      # http://developer.authorize.net/api/reference/#apple-pay-transactions
      def add_apple_pay_payment_token(xml, apple_pay_payment_token)
        xml.payment do
          xml.opaqueData do
            xml.dataDescriptor(APPLE_PAY_DATA_DESCRIPTOR)
            xml.dataValue(Base64.strict_encode64(apple_pay_payment_token.payment_data.to_json))
          end
        end
      end

      def add_retail_data(xml, payment)
        return unless valid_track_data
        xml.retail do
          # As per http://www.authorize.net/support/CP_guide.pdf, '2' is for Retail, the only current market_type
          xml.marketType(2)
        end
      end

      def valid_track_data
        @valid_track_data ||= false
      end

      def add_check(xml, check)
        xml.payment do
          xml.bankAccount do
            xml.routingNumber(check.routing_number)
            xml.accountNumber(check.account_number)
            xml.nameOnAccount(check.name)
            xml.echeckType("WEB")
            xml.bankName(check.bank_name)
            xml.checkNumber(check.number)
          end
        end
      end

      def add_customer_data(xml, payment_source, options)
        billing_address = options[:billing_address] || options[:address] || {}
        shipping_address = options[:shipping_address] || options[:address] || {}

        xml.customer do
          xml.id(options[:customer]) unless empty?(options[:customer]) || options[:customer] !~ /^\d+$/
          xml.email(options[:email]) unless empty?(options[:email])
        end

        xml.billTo do
          first_name, last_name = names_from(payment_source, billing_address, options)
          xml.firstName(truncate(first_name, 50)) unless empty?(first_name)
          xml.lastName(truncate(last_name, 50)) unless empty?(last_name)

          xml.company(truncate(billing_address[:company], 50)) unless empty?(billing_address[:company])
          xml.address(truncate(billing_address[:address1], 60))
          xml.city(truncate(billing_address[:city], 40))
          xml.state(empty?(billing_address[:state]) ? 'n/a' : truncate(billing_address[:state], 40))
          xml.zip(truncate((billing_address[:zip] || options[:zip]), 20))
          xml.country(truncate(billing_address[:country], 60))
          xml.phoneNumber(truncate(billing_address[:phone], 25)) unless empty?(billing_address[:phone])
          xml.faxNumber(truncate(billing_address[:fax], 25)) unless empty?(billing_address[:fax])
        end

        unless shipping_address.blank?
          xml.shipTo do
            (first_name, last_name) = if shipping_address[:name]
              shipping_address[:name].split
            else
              [shipping_address[:first_name], shipping_address[:last_name]]
            end
            xml.firstName(truncate(first_name, 50)) unless empty?(first_name)
            xml.lastName(truncate(last_name, 50)) unless empty?(last_name)

            xml.company(truncate(shipping_address[:company], 50)) unless empty?(shipping_address[:company])
            xml.address(truncate(shipping_address[:address1], 60))
            xml.city(truncate(shipping_address[:city], 40))
            xml.state(truncate(shipping_address[:state], 40))
            xml.zip(truncate(shipping_address[:zip], 20))
            xml.country(truncate(shipping_address[:country], 60))
          end
        end

        xml.customerIP(options[:ip]) unless empty?(options[:ip])

        xml.cardholderAuthentication do
          xml.authenticationIndicator(options[:authentication_indicator])
          xml.cardholderAuthenticationValue(options[:cardholder_authentication_value])
        end
      end

      def add_order_id(xml, options)
        xml.refId(truncate(options[:order_id], 20))
      end

      def add_invoice(xml, options)
        xml.order do
          xml.invoiceNumber(truncate(options[:order_id], 20))
          xml.description(truncate(options[:description], 255))
        end
      end

      def names_from(payment_source, address, options)
        if payment_source && !payment_source.is_a?(PaymentToken)
          first_name, last_name = (address[:name] || "").split
          [(payment_source.first_name || first_name), (payment_source.last_name || last_name)]
        else
          [options[:first_name], options[:last_name]]
        end
      end

      def commit(action, &payload)
        url = (test? ? test_url : live_url)
        response = parse(action, ssl_post(url, post_data(&payload), 'Content-Type' => 'text/xml'))

        avs_result = AVSResult.new(code: response[:avs_result_code])
        cvv_result = CVVResult.new(response[:card_code])
        if using_live_gateway_in_test_mode?(response)
          Response.new(false, "Using a live Authorize.net account in Test Mode is not permitted.")
        else
          Response.new(
            success_from(response),
            message_from(response, avs_result, cvv_result),
            response,
            authorization: authorization_from(response),
            test: test?,
            avs_result: avs_result,
            cvv_result: cvv_result,
            fraud_review: fraud_review?(response)
          )
        end
      end

      def post_data
        Nokogiri::XML::Builder.new do |xml|
          xml.createTransactionRequest('xmlns' => 'AnetApi/xml/v1/schema/AnetApiSchema.xsd') do
            xml.merchantAuthentication do
              xml.name(@options[:login])
              xml.transactionKey(@options[:password])
            end
            yield(xml)
          end
        end.to_xml(indent: 0)
      end

      def parse(action, body)
        doc = Nokogiri::XML(body)
        doc.remove_namespaces!

        response = {action: action}

        response[:response_code] = if(element = doc.at_xpath("//transactionResponse/responseCode"))
          (empty?(element.content) ? nil : element.content.to_i)
        end

        if(element = doc.at_xpath("//errors/error"))
          response[:response_reason_code] = element.at_xpath("errorCode").content[/0*(\d+)$/, 1]
          response[:response_reason_text] = element.at_xpath("errorText").content.chomp('.')
        elsif(element = doc.at_xpath("//transactionResponse/messages/message"))
          response[:response_reason_code] = element.at_xpath("code").content[/0*(\d+)$/, 1]
          response[:response_reason_text] = element.at_xpath("description").content.chomp('.')
        elsif(element = doc.at_xpath("//messages/message"))
          response[:response_reason_code] = element.at_xpath("code").content[/0*(\d+)$/, 1]
          response[:response_reason_text] = element.at_xpath("text").content.chomp('.')
        else
          response[:response_reason_code] = nil
          response[:response_reason_text] = ""
        end

        response[:avs_result_code] = if(element = doc.at_xpath("//avsResultCode"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:transaction_id] = if(element = doc.at_xpath("//transId"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:card_code] = if(element = doc.at_xpath("//cvvResultCode"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:authorization_code] = if(element = doc.at_xpath("//authCode"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:cardholder_authentication_code] = if(element = doc.at_xpath("//cavvResultCode"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:account_number] = if(element = doc.at_xpath("//accountNumber"))
          (empty?(element.content) ? nil : element.content[-4..-1])
        end

        response[:test_request] = if(element = doc.at_xpath("//testRequest"))
          (empty?(element.content) ? nil : element.content)
        end

        response
      end

      def success_from(response)
        (
          response[:response_code] == APPROVED &&
          TRANSACTION_ALREADY_ACTIONED.exclude?(response[:response_reason_code])
        )
      end

      def message_from(response, avs_result, cvv_result)
        if response[:response_code] == DECLINED
          if CARD_CODE_ERRORS.include?(cvv_result.code)
            return cvv_result.message
          elsif(AVS_REASON_CODES.include?(response[:response_reason_code]) && AVS_ERRORS.include?(avs_result.code))
            return avs_result.message
          end
        end

        response[:response_reason_text]
      end

      def authorization_from(response)
        [response[:transaction_id], response[:account_number]].join("#")
      end

      def split_authorization(authorization)
        transaction_id, card_number = authorization.split("#")
        [transaction_id, card_number]
      end

      def fraud_review?(response)
        (response[:response_code] == FRAUD_REVIEW)
      end

      def truncate(value, max_size)
        return nil unless value
        value.to_s[0, max_size]
      end

      def using_live_gateway_in_test_mode?(response)
        !test? && response[:test_request] == "1"
      end
    end
  end
end
