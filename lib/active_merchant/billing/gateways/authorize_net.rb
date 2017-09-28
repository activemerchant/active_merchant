require 'nokogiri'

module ActiveMerchant
  module Billing
    class AuthorizeNetGateway < Gateway
      include Empty

      self.test_url = 'https://apitest.authorize.net/xml/v1/request.api'
      self.live_url = 'https://api2.authorize.net/xml/v1/request.api'

      self.supported_countries = %w(AD AT AU BE BG CA CH CY CZ DE DK EE ES FI FR GB GI GR HU IE IL IS IT LI LT LU LV MC MT NL NO PL PT RO SE SI SK SM TR US VA)
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb, :maestro]

      self.homepage_url = 'http://www.authorize.net/'
      self.display_name = 'Authorize.Net'

      # Authorize.net has slightly different definitions for returned AVS codes
      # that have been mapped to the closest equivalent AM standard AVSResult codes
      # Authorize.net's descriptions noted below
      STANDARD_AVS_CODE_MAPPING = {
        'A' => 'A', # Street Address: Match -- First 5 Digits of ZIP: No Match
        'B' => 'I', # Address not provided for AVS check or street address match, postal code could not be verified
        'E' => 'E', # AVS Error
        'G' => 'G', # Non U.S. Card Issuing Bank
        'N' => 'N', # Street Address: No Match -- First 5 Digits of ZIP: No Match
        'P' => 'I', # AVS not applicable for this transaction
        'R' => 'R', # Retry, System Is Unavailable
        'S' => 'S', # AVS Not Supported by Card Issuing Bank
        'U' => 'U', # Address Information For This Cardholder Is Unavailable
        'W' => 'W', # Street Address: No Match -- All 9 Digits of ZIP: Match
        'X' => 'X', # Street Address: Match -- All 9 Digits of ZIP: Match
        'Y' => 'Y', # Street Address: Match - First 5 Digits of ZIP: Match
        'Z' => 'Z'  # Street Address: No Match - First 5 Digits of ZIP: Match
      }

      STANDARD_ERROR_CODE_MAPPING = {
        '2127' => STANDARD_ERROR_CODE[:incorrect_address],
        '22' => STANDARD_ERROR_CODE[:card_declined],
        '227' => STANDARD_ERROR_CODE[:incorrect_address],
        '23' => STANDARD_ERROR_CODE[:card_declined],
        '2315' => STANDARD_ERROR_CODE[:invalid_number],
        '2316' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '2317' => STANDARD_ERROR_CODE[:expired_card],
        '235' => STANDARD_ERROR_CODE[:processing_error],
        '237' => STANDARD_ERROR_CODE[:invalid_number],
        '24' => STANDARD_ERROR_CODE[:pickup_card],
        '244' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '300' => STANDARD_ERROR_CODE[:config_error],
        '3153' => STANDARD_ERROR_CODE[:processing_error],
        '3155' => STANDARD_ERROR_CODE[:unsupported_feature],
        '36' => STANDARD_ERROR_CODE[:incorrect_number],
        '37' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '378' => STANDARD_ERROR_CODE[:invalid_cvc],
        '38' => STANDARD_ERROR_CODE[:expired_card],
        '384' => STANDARD_ERROR_CODE[:config_error],
      }

      MARKET_TYPE = {
        :moto  => '1',
        :retail  => '2'
      }

      DEVICE_TYPE = {
        :unknown => '1',
        :unattended_terminal => '2',
        :self_service_terminal => '3',
        :electronic_cash_register => '4',
        :personal_computer_terminal => '5',
        :airpay => '6',
        :wireless_pos => '7',
        :website => '8',
        :dial_terminal => '9',
        :virtual_terminal => '10'
      }

      class_attribute :duplicate_window

      APPROVED, DECLINED, ERROR, FRAUD_REVIEW = 1, 2, 3, 4
      TRANSACTION_ALREADY_ACTIONED = %w(310 311)

      CARD_CODE_ERRORS = %w(N S)
      AVS_ERRORS = %w(A E I N R W Z)
      AVS_REASON_CODES = %w(27 45)

      TRACKS = {
          1 => /^%(?<format_code>.)(?<pan>[\d]{1,19}+)\^(?<name>.{2,26})\^(?<expiration>[\d]{0,4}|\^)(?<service_code>[\d]{0,3}|\^)(?<discretionary_data>.*)\?\Z/,
          2 => /\A;(?<pan>[\d]{1,19}+)=(?<expiration>[\d]{0,4}|=)(?<service_code>[\d]{0,3}|=)(?<discretionary_data>.*)\?\Z/
      }.freeze

      APPLE_PAY_DATA_DESCRIPTOR = "COMMON.APPLE.INAPP.PAYMENT"

      PAYMENT_METHOD_NOT_SUPPORTED_ERROR = "155"
      INELIGIBLE_FOR_ISSUING_CREDIT_ERROR = "54"

      def initialize(options={})
        requires!(options, :login, :password)
        super
      end

      def purchase(amount, payment, options = {})
        if payment.is_a?(String)
          commit(:cim_purchase) do |xml|
            add_cim_auth_purchase(xml, "profileTransAuthCapture", amount, payment, options)
          end
        else
          commit(:purchase) do |xml|
            add_auth_purchase(xml, "authCaptureTransaction", amount, payment, options)
          end
        end
      end

      def authorize(amount, payment, options={})
        if payment.is_a?(String)
          commit(:cim_authorize) do |xml|
            add_cim_auth_purchase(xml, "profileTransAuthOnly", amount, payment, options)
          end
        else
          commit(:authorize) do |xml|
            add_auth_purchase(xml, "authOnlyTransaction", amount, payment, options)
          end
        end
      end

      def capture(amount, authorization, options={})
        if auth_was_for_cim?(authorization)
          cim_capture(amount, authorization, options)
        else
          normal_capture(amount, authorization, options)
        end
      end

      def refund(amount, authorization, options={})
        response = if auth_was_for_cim?(authorization)
          cim_refund(amount, authorization, options)
        else
          normal_refund(amount, authorization, options)
        end

        return response if response.success?
        return response unless options[:force_full_refund_if_unsettled]

        if response.params["response_reason_code"] == INELIGIBLE_FOR_ISSUING_CREDIT_ERROR
          void(authorization, options)
        else
          response
        end
      end

      def void(authorization, options={})
        if auth_was_for_cim?(authorization)
          cim_void(authorization, options)
        else
          normal_void(authorization, options)
        end
      end

      def credit(amount, payment, options={})
        if payment.is_a?(String)
          raise ArgumentError, "Reference credits are not supported. Please supply the original credit card or use the #refund method."
        end

        commit(:credit) do |xml|
          add_order_id(xml, options)
          xml.transactionRequest do
            xml.transactionType('refundTransaction')
            xml.amount(amount(amount))

            add_payment_source(xml, payment)
            add_invoice(xml, 'refundTransaction', options)
            add_customer_data(xml, payment, options)
            add_settings(xml, payment, options)
            add_user_fields(xml, amount, options)
          end
        end
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(credit_card, options = {})
        if options[:customer_profile_id]
          create_customer_payment_profile(credit_card, options)
        else
          create_customer_profile(credit_card, options)
        end
      end

      def unstore(authorization)
        customer_profile_id, _, _ = split_authorization(authorization)

        delete_customer_profile(customer_profile_id)
      end

      def verify_credentials
        response = commit(:verify_credentials) { }
        response.success?
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((<transactionKey>).+(</transactionKey>)), '\1[FILTERED]\2').
          gsub(%r((<cardNumber>).+(</cardNumber>)), '\1[FILTERED]\2').
          gsub(%r((<cardCode>).+(</cardCode>)), '\1[FILTERED]\2').
          gsub(%r((<track1>).+(</track1>)), '\1[FILTERED]\2').
          gsub(%r((<track2>).+(</track2>)), '\1[FILTERED]\2').
          gsub(/(<routingNumber>).+(<\/routingNumber>)/, '\1[FILTERED]\2').
          gsub(/(<accountNumber>).+(<\/accountNumber>)/, '\1[FILTERED]\2').
          gsub(%r((<cryptogram>).+(</cryptogram>)), '\1[FILTERED]\2')
      end

      def supports_network_tokenization?
        card = Billing::NetworkTokenizationCreditCard.new({
          :number => "4111111111111111",
          :month => 12,
          :year => 20,
          :first_name => 'John',
          :last_name => 'Smith',
          :brand => 'visa',
          :payment_cryptogram => 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
        })

        request = post_data(:authorize) do |xml|
          add_auth_purchase(xml, "authOnlyTransaction", 1, card, {})
        end
        raw_response = ssl_post(url, request, headers)
        response = parse(:authorize, raw_response)
        response[:response_reason_code].to_s != PAYMENT_METHOD_NOT_SUPPORTED_ERROR
      end

      private

      def add_auth_purchase(xml, transaction_type, amount, payment, options)
        add_order_id(xml, options)
        xml.transactionRequest do
          xml.transactionType(transaction_type)
          xml.amount(amount(amount))
          add_payment_source(xml, payment)
          add_invoice(xml, transaction_type, options)
          add_tax_fields(xml, options)
          add_duty_fields(xml, options)
          add_shipping_fields(xml, options)
          add_tax_exempt_status(xml, options)
          add_po_number(xml, options)
          add_customer_data(xml, payment, options)
          add_market_type_device_type(xml, payment, options)
          add_settings(xml, payment, options)
          add_user_fields(xml, amount, options)
        end
      end

      def add_cim_auth_purchase(xml, transaction_type, amount, payment, options)
        add_order_id(xml, options)
        xml.transaction do
          xml.send(transaction_type) do
            xml.amount(amount(amount))
            add_tax_fields(xml, options)
            add_shipping_fields(xml, options)
            add_duty_fields(xml, options)
            add_payment_source(xml, payment)
            add_invoice(xml, transaction_type, options)
            add_tax_exempt_status(xml, options)
          end
        end
      end

      def cim_capture(amount, authorization, options)
        commit(:cim_capture) do |xml|
          add_order_id(xml, options)
          xml.transaction do
            xml.profileTransPriorAuthCapture do
              xml.amount(amount(amount))
              add_tax_fields(xml, options)
              add_shipping_fields(xml, options)
              add_duty_fields(xml, options)
              xml.transId(transaction_id_from(authorization))
            end
          end
        end
      end

      def normal_capture(amount, authorization, options)
        commit(:capture) do |xml|
          add_order_id(xml, options)
          xml.transactionRequest do
            xml.transactionType('priorAuthCaptureTransaction')
            xml.amount(amount(amount))
            add_tax_fields(xml, options)
            add_duty_fields(xml, options)
            add_shipping_fields(xml, options)
            add_tax_exempt_status(xml, options)
            add_po_number(xml, options)
            xml.refTransId(transaction_id_from(authorization))
            add_invoice(xml, "capture", options)
            add_user_fields(xml, amount, options)
          end
        end
      end

      def cim_refund(amount, authorization, options)
        transaction_id, card_number, _ = split_authorization(authorization)

        commit(:cim_refund) do |xml|
          add_order_id(xml, options)
          xml.transaction do
            xml.profileTransRefund do
              xml.amount(amount(amount))
              add_tax_fields(xml, options)
              add_shipping_fields(xml, options)
              add_duty_fields(xml, options)
              xml.creditCardNumberMasked(card_number)
              add_invoice(xml, "profileTransRefund", options)
              xml.transId(transaction_id)
            end
          end
        end
      end

      def normal_refund(amount, authorization, options)
        transaction_id, card_number, _ = split_authorization(authorization)

        commit(:refund) do |xml|
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

            add_invoice(xml, 'refundTransaction', options)
            add_tax_fields(xml, options)
            add_duty_fields(xml, options)
            add_shipping_fields(xml, options)
            add_tax_exempt_status(xml, options)
            add_po_number(xml, options)
            add_customer_data(xml, nil, options)
            add_user_fields(xml, amount, options)
          end
        end
      end

      def cim_void(authorization, options)
        commit(:cim_void) do |xml|
          add_order_id(xml, options)
          xml.transaction do
            xml.profileTransVoid do
              xml.transId(transaction_id_from(authorization))
            end
          end
        end
      end

      def normal_void(authorization, options)
        commit(:void) do |xml|
          add_order_id(xml, options)
          xml.transactionRequest do
            xml.transactionType('voidTransaction')
            xml.refTransId(transaction_id_from(authorization))
          end
        end
      end

      def add_payment_source(xml, source)
        return unless source
        if source.is_a?(String)
          add_token_payment_method(xml, source)
        elsif card_brand(source) == 'check'
          add_check(xml, source)
        elsif card_brand(source) == 'apple_pay'
          add_apple_pay_payment_token(xml, source)
        else
          add_credit_card(xml, source)
        end
      end

      def camel_case_lower(key)
        String(key).split('_').inject([]){ |buffer,e| buffer.push(buffer.empty? ? e : e.capitalize) }.join
      end

      def add_settings(xml, source, options)
        xml.transactionSettings do
          if options[:recurring]
            xml.setting do
              xml.settingName("recurringBilling")
              xml.settingValue("true")
            end
          end
          if options[:disable_partial_auth]
            xml.setting do
              xml.settingName("allowPartialAuth")
              xml.settingValue("false")
            end
          end
          if options[:duplicate_window]
            set_duplicate_window(xml, options[:duplicate_window])
          elsif self.class.duplicate_window
            ActiveMerchant.deprecated "Using the duplicate_window class_attribute is deprecated. Use the transaction options hash instead."
            set_duplicate_window(xml, self.class.duplicate_window)
          end
          if options[:email_customer]
            xml.setting do
              xml.settingName("emailCustomer")
              xml.settingValue("true")
            end
          end
          if options[:header_email_receipt]
            xml.setting do
              xml.settingName("headerEmailReceipt")
              xml.settingValue(options[:header_email_receipt])
            end
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
          if application_id.present?
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
              xml.cardNumber(truncate(credit_card.number, 16))
              xml.expirationDate(format(credit_card.month, :two_digits) + '/' + format(credit_card.year, :four_digits))
              if credit_card.valid_card_verification_value?(credit_card.verification_value, credit_card.brand)
                xml.cardCode(credit_card.verification_value)
              end
              if credit_card.is_a?(NetworkTokenizationCreditCard)
                xml.cryptogram(credit_card.payment_cryptogram)
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

      def add_token_payment_method(xml, token)
        customer_profile_id, customer_payment_profile_id, _ = split_authorization(token)
        xml.customerProfileId(customer_profile_id)
        xml.customerPaymentProfileId(customer_payment_profile_id)
      end

      def add_apple_pay_payment_token(xml, apple_pay_payment_token)
        xml.payment do
          xml.opaqueData do
            xml.dataDescriptor(APPLE_PAY_DATA_DESCRIPTOR)
            xml.dataValue(Base64.strict_encode64(apple_pay_payment_token.payment_data.to_json))
          end
        end
      end

      def add_market_type_device_type(xml, payment, options)
        return if payment.is_a?(String) || card_brand(payment) == 'check' || card_brand(payment) == 'apple_pay'
        if valid_track_data
          xml.retail do
            xml.marketType(options[:market_type] || MARKET_TYPE[:retail])
            xml.deviceType(options[:device_type] || DEVICE_TYPE[:wireless_pos])
          end
        elsif payment.manual_entry
          xml.retail do
            xml.marketType(options[:market_type] || MARKET_TYPE[:moto])
          end
        else
          if options[:market_type]
            xml.retail do
              xml.marketType(options[:market_type])
            end
          end
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
            xml.nameOnAccount(truncate(check.name, 22))
            xml.bankName(check.bank_name)
            xml.checkNumber(check.number)
          end
        end
      end

      def add_customer_data(xml, payment_source, options)
        xml.customer do
          xml.id(options[:customer]) unless empty?(options[:customer]) || options[:customer] !~ /^\w+$/
          xml.email(options[:email]) unless empty?(options[:email])
        end

        add_billing_address(xml, payment_source, options)
        add_shipping_address(xml, options)

        xml.customerIP(options[:ip]) unless empty?(options[:ip])

        xml.cardholderAuthentication do
          xml.authenticationIndicator(options[:authentication_indicator])
          xml.cardholderAuthenticationValue(options[:cardholder_authentication_value])
        end
      end

      def add_billing_address(xml, payment_source, options)
        address = options[:billing_address] || options[:address] || {}

        xml.billTo do
          first_name, last_name = names_from(payment_source, address, options)
          state = state_from(address, options)
          full_address = "#{address[:address1]} #{address[:address2]}".strip

          xml.firstName(truncate(first_name, 50)) unless empty?(first_name)
          xml.lastName(truncate(last_name, 50)) unless empty?(last_name)
          xml.company(truncate(address[:company], 50)) unless empty?(address[:company])
          xml.address(truncate(full_address, 60))
          xml.city(truncate(address[:city], 40))
          xml.state(truncate(state, 40))
          xml.zip(truncate((address[:zip] || options[:zip]), 20))
          xml.country(truncate(address[:country], 60))
          xml.phoneNumber(truncate(address[:phone], 25)) unless empty?(address[:phone])
          xml.faxNumber(truncate(address[:fax], 25)) unless empty?(address[:fax])
        end
      end

      def add_shipping_address(xml, options, root_node="shipTo")
        address = options[:shipping_address] || options[:address]
        return unless address

        xml.send(root_node) do
          first_name, last_name = if address[:name]
            split_names(address[:name])
          else
            [address[:first_name], address[:last_name]]
          end
          full_address = "#{address[:address1]} #{address[:address2]}".strip

          xml.firstName(truncate(first_name, 50)) unless empty?(first_name)
          xml.lastName(truncate(last_name, 50)) unless empty?(last_name)
          xml.company(truncate(address[:company], 50)) unless empty?(address[:company])
          xml.address(truncate(full_address, 60))
          xml.city(truncate(address[:city], 40))
          xml.state(truncate(address[:state], 40))
          xml.zip(truncate(address[:zip], 20))
          xml.country(truncate(address[:country], 60))
        end

      end

      def add_order_id(xml, options)
        xml.refId(truncate(options[:order_id], 20))
      end

      def add_invoice(xml, transaction_type, options)
        xml.order do
          xml.invoiceNumber(truncate(options[:order_id], 20))
          xml.description(truncate(options[:description], 255))
          xml.purchaseOrderNumber(options[:po_number]) if options[:po_number] && transaction_type.start_with?("profileTrans")
        end

        # Authorize.net API requires lineItems to be placed directly after order tag
        if options[:line_items]
          xml.lineItems do
            options[:line_items].each do |line_item|
              xml.lineItem do
                line_item.each do |key, value|
                  xml.send(camel_case_lower(key), value)
                end
              end
            end
          end
        end
      end

      def add_tax_fields(xml, options)
        tax = options[:tax]
        if tax.is_a?(Hash)
          xml.tax do
            xml.amount(amount(tax[:amount].to_i))
            xml.name(tax[:name])
            xml.description(tax[:description])
          end
        end
      end

      def add_duty_fields(xml, options)
        duty = options[:duty]
        if duty.is_a?(Hash)
          xml.duty do
            xml.amount(amount(duty[:amount].to_i))
            xml.name(duty[:name])
            xml.description(duty[:description])
          end
        end
      end

      def add_shipping_fields(xml, options)
        shipping = options[:shipping]
        if shipping.is_a?(Hash)
          xml.shipping do
            xml.amount(amount(shipping[:amount].to_i))
            xml.name(shipping[:name])
            xml.description(shipping[:description])
          end
        end
      end

      def add_tax_exempt_status(xml, options)
        xml.taxExempt(options[:tax_exempt]) if options[:tax_exempt]
      end

      def add_po_number(xml, options)
        xml.poNumber(options[:po_number]) if options[:po_number]
      end

      def create_customer_payment_profile(credit_card, options)
        commit(:cim_store_update) do |xml|
          xml.customerProfileId options[:customer_profile_id]
          xml.paymentProfile do
            add_billing_address(xml, credit_card, options)
            xml.payment do
              xml.creditCard do
                xml.cardNumber(truncate(credit_card.number, 16))
                xml.expirationDate(format(credit_card.year, :four_digits) + '-' + format(credit_card.month, :two_digits))
                xml.cardCode(credit_card.verification_value) if credit_card.verification_value
              end
            end
          end
        end
      end

      def create_customer_profile(credit_card, options)
        commit(:cim_store) do |xml|
          xml.profile do
            xml.merchantCustomerId(truncate(options[:merchant_customer_id], 20) || SecureRandom.hex(10))
            xml.description(truncate(options[:description], 255)) unless empty?(options[:description])
            xml.email(options[:email]) unless empty?(options[:email])

            xml.paymentProfiles do
              xml.customerType("individual")
              add_billing_address(xml, credit_card, options)
              add_shipping_address(xml, options, "shipToList")
              xml.payment do
                xml.creditCard do
                  xml.cardNumber(truncate(credit_card.number, 16))
                  xml.expirationDate(format(credit_card.year, :four_digits) + '-' + format(credit_card.month, :two_digits))
                  xml.cardCode(credit_card.verification_value) if credit_card.verification_value
                end
              end
            end
          end
        end
      end

      def delete_customer_profile(customer_profile_id)
        commit(:cim_store_delete_customer) do |xml|
          xml.customerProfileId(customer_profile_id)
        end
      end

      def names_from(payment_source, address, options)
        if payment_source && !payment_source.is_a?(PaymentToken) && !payment_source.is_a?(String)
          first_name, last_name = split_names(address[:name])
          [(payment_source.first_name || first_name), (payment_source.last_name || last_name)]
        else
          [options[:first_name], options[:last_name]]
        end
      end

      def state_from(address, options)
        if ["US", "CA"].include?(address[:country])
          address[:state] || 'NC'
        else
          address[:state] || 'n/a'
        end
      end

      def headers
        { 'Content-Type' => 'text/xml' }
      end

      def url
        test? ? test_url : live_url
      end

      def parse(action, raw_response)
        if is_cim_action?(action) || action == :verify_credentials
          parse_cim(raw_response)
        else
          parse_normal(action, raw_response)
        end
      end

      def commit(action, &payload)
        raw_response = ssl_post(url, post_data(action, &payload), headers)
        response = parse(action, raw_response)

        avs_result_code = response[:avs_result_code].upcase if response[:avs_result_code]
        avs_result = AVSResult.new(code: STANDARD_AVS_CODE_MAPPING[avs_result_code])
        cvv_result = CVVResult.new(response[:card_code])
        if using_live_gateway_in_test_mode?(response)
          Response.new(false, "Using a live Authorize.net account in Test Mode is not permitted.")
        else
          Response.new(
            success_from(action, response),
            message_from(action, response, avs_result, cvv_result),
            response,
            authorization: authorization_from(action, response),
            test: test?,
            avs_result: avs_result,
            cvv_result: cvv_result,
            fraud_review: fraud_review?(response),
            error_code: map_error_code(response[:response_code], response[:response_reason_code])
          )
        end
      end

      def is_cim_action?(action)
        action.to_s.start_with?("cim")
      end

      def post_data(action)
        Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.send(root_for(action), 'xmlns' => 'AnetApi/xml/v1/schema/AnetApiSchema.xsd') do
            add_authentication(xml)
            yield(xml)
          end
        end.to_xml(indent: 0)
      end

      def root_for(action)
        if action == :cim_store
          "createCustomerProfileRequest"
        elsif action == :cim_store_update
          "createCustomerPaymentProfileRequest"
        elsif action == :cim_store_delete_customer
          "deleteCustomerProfileRequest"
        elsif action == :verify_credentials
          "authenticateTestRequest"
        elsif is_cim_action?(action)
          "createCustomerProfileTransactionRequest"
        else
          "createTransactionRequest"
        end
      end

      def add_authentication(xml)
        xml.merchantAuthentication do
          xml.name(@options[:login])
          xml.transactionKey(@options[:password])
        end
      end

      def parse_normal(action, body)
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

      def parse_cim(body)
        response = {}

        doc = Nokogiri::XML(body).remove_namespaces!

        if (element = doc.at_xpath("//messages/message"))
          response[:message_code] = element.at_xpath("code").content[/0*(\d+)$/, 1]
          response[:message_text] = element.at_xpath("text").content.chomp('.')
        end

        response[:result_code] = if(element = doc.at_xpath("//messages/resultCode"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:test_request] = if(element = doc.at_xpath("//testRequest"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:customer_profile_id] = if(element = doc.at_xpath("//customerProfileId"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:customer_payment_profile_id] = if(element = doc.at_xpath("//customerPaymentProfileIdList/numericString"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:customer_payment_profile_id] = if(element = doc.at_xpath("//customerPaymentProfileIdList/numericString") ||
                                                              doc.at_xpath("//customerPaymentProfileId"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:direct_response] = if(element = doc.at_xpath("//directResponse"))
          (empty?(element.content) ? nil : element.content)
        end

        response.merge!(parse_direct_response_elements(response))

        response
      end

      def success_from(action, response)
        if cim?(action) || (action == :verify_credentials)
          response[:result_code] == "Ok"
        else
          [APPROVED, FRAUD_REVIEW].include?(response[:response_code]) && TRANSACTION_ALREADY_ACTIONED.exclude?(response[:response_reason_code])
        end
      end

      def message_from(action, response, avs_result, cvv_result)
        if response[:response_code] == DECLINED
          if CARD_CODE_ERRORS.include?(cvv_result.code)
            return cvv_result.message
          elsif(AVS_REASON_CODES.include?(response[:response_reason_code]) && AVS_ERRORS.include?(avs_result.code))
            return avs_result.message
          end
        end

        response[:response_reason_text] || response[:message_text]
      end

      def authorization_from(action, response)
        if cim?(action)
          [response[:customer_profile_id], response[:customer_payment_profile_id], action].join("#")
        else
          [response[:transaction_id], response[:account_number], action].join("#")
        end
      end

      def split_authorization(authorization)
        authorization.split("#")
      end

      def cim?(action)
        (action == :cim_store) || (action == :cim_store_update) || (action == :cim_store_delete_customer)
      end

      def transaction_id_from(authorization)
        transaction_id, _, _ = split_authorization(authorization)
        transaction_id
      end

      def fraud_review?(response)
        (response[:response_code] == FRAUD_REVIEW)
      end

      def using_live_gateway_in_test_mode?(response)
        !test? && response[:test_request] == "1"
      end

      def map_error_code(response_code, response_reason_code)
        STANDARD_ERROR_CODE_MAPPING["#{response_code}#{response_reason_code}"]
      end

      def auth_was_for_cim?(authorization)
        _, _, action = split_authorization(authorization)
        action && is_cim_action?(action)
      end

      def parse_direct_response_elements(response)
        params = response[:direct_response]
        return {} unless params

        parts = params.split(',')
        {
          response_code: parts[0].to_i,
          response_subcode: parts[1],
          response_reason_code: parts[2],
          response_reason_text: parts[3],
          approval_code: parts[4],
          avs_result_code: parts[5],
          transaction_id: parts[6],
          invoice_number: parts[7],
          order_description: parts[8],
          amount: parts[9],
          method: parts[10],
          transaction_type: parts[11],
          customer_id: parts[12],
          first_name: parts[13],
          last_name: parts[14],
          company: parts[15],
          address: parts[16],
          city: parts[17],
          state: parts[18],
          zip_code: parts[19],
          country: parts[20],
          phone: parts[21],
          fax: parts[22],
          email_address: parts[23],
          ship_to_first_name: parts[24],
          ship_to_last_name: parts[25],
          ship_to_company: parts[26],
          ship_to_address: parts[27],
          ship_to_city: parts[28],
          ship_to_state: parts[29],
          ship_to_zip_code: parts[30],
          ship_to_country: parts[31],
          tax: parts[32],
          duty: parts[33],
          freight: parts[34],
          tax_exempt: parts[35],
          purchase_order_number: parts[36],
          md5_hash: parts[37],
          card_code: parts[38],
          cardholder_authentication_verification_response: parts[39],
          account_number: parts[50] || '',
          card_type: parts[51] || '',
          split_tender_id: parts[52] || '',
          requested_amount: parts[53] || '',
          balance_on_card: parts[54] || '',
        }
      end

    end
  end
end
