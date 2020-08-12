require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WorldpayGateway < Gateway
      self.test_url = 'https://secure-test.worldpay.com/jsp/merchant/xml/paymentService.jsp'
      self.live_url = 'https://secure.worldpay.com/jsp/merchant/xml/paymentService.jsp'

      self.default_currency = 'GBP'
      self.money_format = :cents
      self.supported_countries = %w(HK GB AU AD AR BE BR CA CH CN CO CR CY CZ DE DK ES FI FR GI GR HU IE IN IT JP LI LU MC MT MY MX NL NO NZ PA PE PL PT SE SG SI SM TR UM VA)
      self.supported_cardtypes = %i[visa master american_express discover jcb maestro elo naranja cabal]
      self.currencies_without_fractions = %w(HUF IDR ISK JPY KRW)
      self.currencies_with_three_decimal_places = %w(BHD KWD OMR RSD TND)
      self.homepage_url = 'http://www.worldpay.com/'
      self.display_name = 'Worldpay Global'

      CARD_CODES = {
        'visa'             => 'VISA-SSL',
        'master'           => 'ECMC-SSL',
        'discover'         => 'DISCOVER-SSL',
        'american_express' => 'AMEX-SSL',
        'jcb'              => 'JCB-SSL',
        'maestro'          => 'MAESTRO-SSL',
        'diners_club'      => 'DINERS-SSL',
        'elo'              => 'ELO-SSL',
        'naranja'          => 'NARANJA-SSL',
        'cabal'            => 'CABAL-SSL',
        'unknown'          => 'CARD-SSL'
      }

      AVS_CODE_MAP = {
        'A' => 'M', # Match
        'B' => 'P', # Postcode matches, address not verified
        'C' => 'Z', # Postcode matches, address does not match
        'D' => 'B', # Address matched; postcode not checked
        'E' => 'I', # Address and postal code not checked
        'F' => 'A', # Address matches, postcode does not match
        'G' => 'C', # Address does not match, postcode not checked
        'H' => 'I', # Address and postcode not provided
        'I' => 'C', # Address not checked postcode does not match
        'J' => 'C', # Address and postcode does not match
      }

      CVC_CODE_MAP = {
        'A' => 'M', # CVV matches
        'B' => 'P', # Not provided
        'C' => 'P', # Not checked
        'D' => 'N', # Does not match
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, payment_method, options = {})
        MultiResponse.run do |r|
          r.process { authorize(money, payment_method, options) }
          r.process { capture(money, r.authorization, options.merge(authorization_validated: true)) }
        end
      end

      def authorize(money, payment_method, options = {})
        requires!(options, :order_id)
        payment_details = payment_details_from(payment_method)
        authorize_request(money, payment_method, payment_details.merge(options))
      end

      def capture(money, authorization, options = {})
        authorization = order_id_from_authorization(authorization.to_s)
        MultiResponse.run do |r|
          r.process { inquire_request(authorization, options, 'AUTHORISED') } unless options[:authorization_validated]
          if r.params
            authorization_currency = r.params['amount_currency_code']
            options = options.merge(currency: authorization_currency) if authorization_currency.present?
          end
          r.process { capture_request(money, authorization, options) }
        end
      end

      def void(authorization, options = {})
        authorization = order_id_from_authorization(authorization.to_s)
        MultiResponse.run do |r|
          r.process { inquire_request(authorization, options, 'AUTHORISED') } unless options[:authorization_validated]
          r.process { cancel_request(authorization, options) }
        end
      end

      def refund(money, authorization, options = {})
        authorization = order_id_from_authorization(authorization.to_s)
        response = MultiResponse.run do |r|
          r.process { inquire_request(authorization, options, 'CAPTURED', 'SETTLED', 'SETTLED_BY_MERCHANT') } unless options[:authorization_validated]
          r.process { refund_request(money, authorization, options) }
        end

        if !response.success? && options[:force_full_refund_if_unsettled] &&
           response.params['last_event'] == 'AUTHORISED'
          void(authorization, options)
        else
          response
        end
      end

      # Credits only function on a Merchant ID/login/profile flagged for Payouts
      #   aka Credit Fund Transfers (CFT), whereas normal purchases, refunds,
      #   and other transactions should be performed on a normal eCom-flagged
      #   merchant ID.
      def credit(money, payment_method, options = {})
        payment_details = payment_details_from(payment_method)
        credit_request(money, payment_method, payment_details.merge(credit: true, **options))
      end

      def verify(payment_method, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, payment_method, options) }
          r.process(:ignore_result) { void(r.authorization, options.merge(authorization_validated: true)) }
        end
      end

      def store(credit_card, options={})
        requires!(options, :customer)
        store_request(credit_card, options)
      end

      def supports_scrubbing
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((<cardNumber>)\d+(</cardNumber>)), '\1[FILTERED]\2').
          gsub(%r((<cvc>)[^<]+(</cvc>)), '\1[FILTERED]\2')
      end

      private

      def authorize_request(money, payment_method, options)
        commit('authorize', build_authorization_request(money, payment_method, options), 'AUTHORISED', options)
      end

      def capture_request(money, authorization, options)
        commit('capture', build_capture_request(money, authorization, options), :ok, options)
      end

      def cancel_request(authorization, options)
        commit('cancel', build_void_request(authorization, options), :ok, options)
      end

      def inquire_request(authorization, options, *success_criteria)
        commit('inquiry', build_order_inquiry_request(authorization, options), *success_criteria, options)
      end

      def refund_request(money, authorization, options)
        commit('refund', build_refund_request(money, authorization, options), :ok, options)
      end

      def credit_request(money, payment_method, options)
        commit('credit', build_authorization_request(money, payment_method, options), :ok, 'SENT_FOR_REFUND', options)
      end

      def store_request(credit_card, options)
        commit('store', build_store_request(credit_card, options), options)
      end

      def build_request
        xml = Builder::XmlMarkup.new indent: 2
        xml.instruct! :xml, encoding: 'UTF-8'
        xml.declare! :DOCTYPE, :paymentService, :PUBLIC, '-//WorldPay//DTD WorldPay PaymentService v1//EN', 'http://dtd.worldpay.com/paymentService_v1.dtd'
        xml.paymentService 'version' => '1.4', 'merchantCode' => @options[:login] do
          yield xml
        end
        xml.target!
      end

      def build_order_modify_request(authorization)
        build_request do |xml|
          xml.modify do
            xml.orderModification 'orderCode' => authorization do
              yield xml
            end
          end
        end
      end

      def build_order_inquiry_request(authorization, options)
        build_request do |xml|
          xml.inquiry do
            xml.orderInquiry 'orderCode' => authorization
          end
        end
      end

      def build_authorization_request(money, payment_method, options)
        build_request do |xml|
          xml.submit do
            xml.order order_tag_attributes(options) do
              xml.description(options[:description].blank? ? 'Purchase' : options[:description])
              add_amount(xml, money, options)
              if options[:order_content]
                xml.orderContent do
                  xml.cdata! options[:order_content]
                end
              end
              add_payment_method(xml, money, payment_method, options)
              add_shopper(xml, options)
              add_risk_data(xml, options[:risk_data]) if options[:risk_data]
              add_hcg_additional_data(xml, options) if options[:hcg_additional_data]
              add_instalments_data(xml, options) if options[:instalments]
              add_moto_flag(xml, options) if options.dig(:metadata, :manual_entry)
              add_additional_3ds_data(xml, options) if options[:execute_threed] && options[:three_ds_version] && options[:three_ds_version] =~ /^2/
              add_3ds_exemption(xml, options) if options[:exemption_type]
            end
          end
        end
      end

      def order_tag_attributes(options)
        { 'orderCode' => options[:order_id], 'installationId' => options[:inst_id] || @options[:inst_id] }.reject { |_, v| !v.present? }
      end

      def build_capture_request(money, authorization, options)
        build_order_modify_request(authorization) do |xml|
          xml.capture do
            time = Time.now
            xml.date 'dayOfMonth' => time.day, 'month' => time.month, 'year' => time.year
            add_amount(xml, money, options)
          end
        end
      end

      def build_void_request(authorization, options)
        build_order_modify_request(authorization, &:cancel)
      end

      def build_refund_request(money, authorization, options)
        build_order_modify_request(authorization) do |xml|
          xml.refund do
            add_amount(xml, money, options.merge(debit_credit_indicator: 'credit'))
          end
        end
      end

      def build_store_request(credit_card, options)
        build_request do |xml|
          xml.submit do
            xml.paymentTokenCreate do
              add_authenticated_shopper_id(xml, options)
              xml.createToken
              xml.paymentInstrument do
                xml.cardDetails do
                  add_card(xml, credit_card, options)
                end
              end
            end
          end
        end
      end

      def add_additional_3ds_data(xml, options)
        xml.additional3DSData 'dfReferenceId' => options[:session_id]
      end

      def add_3ds_exemption(xml, options)
        xml.exemption 'type' => options[:exemption_type], 'placement' => options[:exemption_placement] || 'AUTHORISATION'
      end

      def add_risk_data(xml, risk_data)
        xml.riskData do
          add_authentication_risk_data(xml, risk_data[:authentication_risk_data])
          add_shopper_account_risk_data(xml, risk_data[:shopper_account_risk_data])
          add_transaction_risk_data(xml, risk_data[:transaction_risk_data])
        end
      end

      def add_authentication_risk_data(xml, authentication_risk_data)
        return unless authentication_risk_data

        timestamp = authentication_risk_data.fetch(:authentication_date, {})

        xml.authenticationRiskData('authenticationMethod' => authentication_risk_data[:authentication_method]) do
          xml.authenticationTimestamp do
            xml.date(
              'dayOfMonth' => timestamp[:day_of_month],
              'month' => timestamp[:month],
              'year' => timestamp[:year],
              'hour' => timestamp[:hour],
              'minute' => timestamp[:minute],
              'second' => timestamp[:second]
            )
          end
        end
      end

      def add_shopper_account_risk_data(xml, shopper_account_risk_data)
        return unless shopper_account_risk_data

        data = {
          'transactionsAttemptedLastDay' => shopper_account_risk_data[:transactions_attempted_last_day],
          'transactionsAttemptedLastYear' => shopper_account_risk_data[:transactions_attempted_last_year],
          'purchasesCompletedLastSixMonths' => shopper_account_risk_data[:purchases_completed_last_six_months],
          'addCardAttemptsLastDay' => shopper_account_risk_data[:add_card_attempts_last_day],
          'previousSuspiciousActivity' => shopper_account_risk_data[:previous_suspicious_activity],
          'shippingNameMatchesAccountName' => shopper_account_risk_data[:shipping_name_matches_account_name],
          'shopperAccountAgeIndicator' => shopper_account_risk_data[:shopper_account_age_indicator],
          'shopperAccountChangeIndicator' => shopper_account_risk_data[:shopper_account_change_indicator],
          'shopperAccountPasswordChangeIndicator' => shopper_account_risk_data[:shopper_account_password_change_indicator],
          'shopperAccountShippingAddressUsageIndicator' => shopper_account_risk_data[:shopper_account_shipping_address_usage_indicator],
          'shopperAccountPaymentAccountIndicator' => shopper_account_risk_data[:shopper_account_payment_account_indicator]
        }.reject { |_k, v| v.nil? }

        xml.shopperAccountRiskData(data) do
          add_date_element(xml, 'shopperAccountCreationDate', shopper_account_risk_data[:shopper_account_creation_date])
          add_date_element(xml, 'shopperAccountModificationDate', shopper_account_risk_data[:shopper_account_modification_date])
          add_date_element(xml, 'shopperAccountPasswordChangeDate', shopper_account_risk_data[:shopper_account_password_change_date])
          add_date_element(xml, 'shopperAccountShippingAddressFirstUseDate', shopper_account_risk_data[:shopper_account_shipping_address_first_use_date])
          add_date_element(xml, 'shopperAccountPaymentAccountFirstUseDate', shopper_account_risk_data[:shopper_account_payment_account_first_use_date])
        end
      end

      def add_transaction_risk_data(xml, transaction_risk_data)
        return unless transaction_risk_data

        data = {
          'shippingMethod' => transaction_risk_data[:shipping_method],
          'deliveryTimeframe' => transaction_risk_data[:delivery_timeframe],
          'deliveryEmailAddress' => transaction_risk_data[:delivery_email_address],
          'reorderingPreviousPurchases' => transaction_risk_data[:reordering_previous_purchases],
          'preOrderPurchase' => transaction_risk_data[:pre_order_purchase],
          'giftCardCount' => transaction_risk_data[:gift_card_count]
        }.reject { |_k, v| v.nil? }

        xml.transactionRiskData(data) do
          xml.transactionRiskDataGiftCardAmount do
            amount_hash = {
              'value' => transaction_risk_data.dig(:transaction_risk_data_gift_card_amount, :value),
              'currencyCode' => transaction_risk_data.dig(:transaction_risk_data_gift_card_amount, :currency),
              'exponent' => transaction_risk_data.dig(:transaction_risk_data_gift_card_amount, :exponent)
            }
            debit_credit_indicator = transaction_risk_data.dig(:transaction_risk_data_gift_card_amount, :debit_credit_indicator)
            amount_hash['debitCreditIndicator'] = debit_credit_indicator if debit_credit_indicator
            xml.amount(amount_hash)
          end
          add_date_element(xml, 'transactionRiskDataPreOrderDate', transaction_risk_data[:transaction_risk_data_pre_order_date])
        end
      end

      def add_date_element(xml, name, date)
        xml.tag! name do
          xml.date('dayOfMonth' => date[:day_of_month], 'month' => date[:month], 'year' => date[:year])
        end
      end

      def add_amount(xml, money, options)
        currency = options[:currency] || currency(money)

        amount_hash = {
          :value => localized_amount(money, currency),
          'currencyCode' => currency,
          'exponent' => currency_exponent(currency)
        }

        amount_hash['debitCreditIndicator'] = options[:debit_credit_indicator] if options[:debit_credit_indicator]

        xml.amount amount_hash
      end

      def add_payment_method(xml, amount, payment_method, options)
        if options[:payment_type] == :pay_as_order
          if options[:merchant_code]
            xml.payAsOrder 'orderCode' => payment_method, 'merchantCode' => options[:merchant_code] do
              add_amount(xml, amount, options)
            end
          else
            xml.payAsOrder 'orderCode' => payment_method do
              add_amount(xml, amount, options)
            end
          end
        else
          xml.paymentDetails credit_fund_transfer_attribute(options) do
            if options[:payment_type] == :token
              xml.tag! 'TOKEN-SSL', 'tokenScope' => options[:token_scope] do
                xml.paymentTokenID options[:token_id]
              end
            else
              xml.tag! card_code_for(payment_method) do
                add_card(xml, payment_method, options)
              end
            end
            add_stored_credential_options(xml, options)
            if options[:ip] && options[:session_id]
              xml.session 'shopperIPAddress' => options[:ip], 'id' => options[:session_id]
            else
              xml.session 'shopperIPAddress' => options[:ip] if options[:ip]
              xml.session 'id' => options[:session_id] if options[:session_id]
            end

            if three_d_secure = options[:three_d_secure]
              add_three_d_secure(three_d_secure, xml)
            end
          end
        end
      end

      def add_three_d_secure(three_d_secure, xml)
        xml.info3DSecure do
          xml.threeDSVersion three_d_secure[:version]
          if /^2/.match?(three_d_secure[:version])
            xml.dsTransactionId three_d_secure[:ds_transaction_id]
          else
            xml.xid three_d_secure[:xid]
          end
          xml.cavv three_d_secure[:cavv]
          xml.eci three_d_secure[:eci]
        end
      end

      def add_card(xml, payment_method, options)
        xml.cardNumber payment_method.number
        xml.expiryDate do
          xml.date(
            'month' => format(payment_method.month, :two_digits),
            'year' => format(payment_method.year, :four_digits)
          )
        end

        card_holder_name = options[:execute_threed] && !options[:three_ds_version]&.start_with?('2') ? '3D' : payment_method.name
        xml.cardHolderName card_holder_name
        xml.cvc payment_method.verification_value

        add_address(xml, (options[:billing_address] || options[:address]), options)
      end

      def add_stored_credential_options(xml, options={})
        if options[:stored_credential]
          add_stored_credential_using_normalized_fields(xml, options)
        else
          add_stored_credential_using_gateway_specific_fields(xml, options)
        end
      end

      def add_stored_credential_using_normalized_fields(xml, options)
        if options[:stored_credential][:initial_transaction]
          xml.storedCredentials 'usage' => 'FIRST'
        else
          reason = case options[:stored_credential][:reason_type]
                   when 'installment' then 'INSTALMENT'
                   when 'recurring' then 'RECURRING'
                   when 'unscheduled' then 'UNSCHEDULED'
                   end

          xml.storedCredentials 'usage' => 'USED', 'merchantInitiatedReason' => reason do
            xml.schemeTransactionIdentifier options[:stored_credential][:network_transaction_id] if options[:stored_credential][:network_transaction_id]
          end
        end
      end

      def add_stored_credential_using_gateway_specific_fields(xml, options)
        return unless options[:stored_credential_usage]

        if options[:stored_credential_initiated_reason]
          xml.storedCredentials 'usage' => options[:stored_credential_usage], 'merchantInitiatedReason' => options[:stored_credential_initiated_reason] do
            xml.schemeTransactionIdentifier options[:stored_credential_transaction_id] if options[:stored_credential_transaction_id]
          end
        else
          xml.storedCredentials 'usage' => options[:stored_credential_usage]
        end
      end

      def add_shopper(xml, options)
        return unless options[:execute_threed] || options[:email] || options[:customer]

        xml.shopper do
          xml.shopperEmailAddress options[:email] if options[:email]
          add_authenticated_shopper_id(xml, options)
          xml.browser do
            xml.acceptHeader options[:accept_header]
            xml.userAgentHeader options[:user_agent]
          end
        end
      end

      def add_authenticated_shopper_id(xml, options)
        xml.authenticatedShopperID options[:customer] if options[:customer]
      end

      def add_address(xml, address, options)
        return unless address

        address = address_with_defaults(address)

        xml.cardAddress do
          xml.address do
            if m = /^\s*([^\s]+)\s+(.+)$/.match(address[:name])
              xml.firstName m[1]
              xml.lastName m[2]
            end
            xml.address1 address[:address1]
            xml.address2 address[:address2] if address[:address2]
            xml.postalCode address[:zip]
            xml.city address[:city]
            xml.state address[:state] unless address[:country] != 'US' && options[:execute_threed]
            xml.countryCode address[:country]
            xml.telephoneNumber address[:phone] if address[:phone]
          end
        end
      end

      def add_hcg_additional_data(xml, options)
        xml.hcgAdditionalData do
          options[:hcg_additional_data].each do |k, v|
            xml.param({name: k.to_s}, v)
          end
        end
      end

      def add_instalments_data(xml, options)
        xml.thirdPartyData do
          xml.instalments options[:instalments]
          xml.cpf options[:cpf] if options[:cpf]
        end
      end

      def add_moto_flag(xml, options)
        xml.dynamicInteractionType 'type' => 'MOTO'
      end

      def address_with_defaults(address)
        address ||= {}
        address.delete_if { |_, v| v.blank? }
        address.reverse_merge!(default_address)
      end

      def default_address
        {
          address1: 'N/A',
          zip: '0000',
          city: 'N/A',
          state: 'N/A',
          country: 'US'
        }
      end

      def parse(action, xml)
        xml = xml.strip.gsub(/\&/, '&amp;')
        doc = Nokogiri::XML(xml, &:strict)
        doc.remove_namespaces!
        resp_params = {action: action}

        parse_elements(doc.root, resp_params)
        resp_params
      end

      def parse_elements(node, response)
        node_name = node.name.underscore
        node.attributes.each do |k, v|
          response["#{node_name}_#{k.underscore}".to_sym] = v.value
        end
        if node.elements.empty?
          response[node_name.to_sym] = node.text unless node.text.blank?
        else
          response[node_name.to_sym] = true unless node.name.blank?
          node.elements.each do |childnode|
            parse_elements(childnode, response)
          end
        end
      end

      def headers(options)
        headers = {
          'Content-Type' => 'text/xml',
          'Authorization' => encoded_credentials
        }
        if options[:cookie]
          headers['Cookie'] = options[:cookie] if options[:cookie]
        end
        headers
      end

      def commit(action, request, *success_criteria, options)
        xml = ssl_post(url, request, headers(options))
        raw = parse(action, xml)
        if options[:execute_threed]
          raw[:cookie] = @cookie if defined?(@cookie)
          raw[:session_id] = options[:session_id]
          raw[:is3DSOrder] = true
        end
        success = success_from(action, raw, success_criteria)
        message = message_from(success, raw, success_criteria)

        Response.new(
          success,
          message,
          raw,
          authorization: authorization_from(action, raw, options),
          error_code: error_code_from(success, raw),
          test: test?,
          avs_result: AVSResult.new(code: AVS_CODE_MAP[raw[:avs_result_code_description]]),
          cvv_result: CVVResult.new(CVC_CODE_MAP[raw[:cvc_result_code_description]])
        )
      rescue Nokogiri::SyntaxError
        unparsable_response(xml)
      rescue ActiveMerchant::ResponseError => e
        if e.response.code.to_s == '401'
          return Response.new(false, 'Invalid credentials', {}, test: test?)
        else
          raise e
        end
      end

      def url
        test? ? self.test_url : self.live_url
      end

      def unparsable_response(raw_response)
        message = 'Unparsable response received from Worldpay. Please contact Worldpay if you continue to receive this message.'
        message += " (The raw response returned by the API was: #{raw_response.inspect})"
        return Response.new(false, message)
      end

      # Override the regular handle response so we can access the headers
      # Set-Cookie value is needed for 3DS transactions
      def handle_response(response)
        case response.code.to_i
        when 200...300
          @cookie = response['Set-Cookie']
          response.body
        else
          raise ResponseError.new(response)
        end
      end

      def success_from(action, raw, success_criteria)
        success_criteria_success?(raw, success_criteria) || action_success?(action, raw)
      end

      def message_from(success, raw, success_criteria)
        return 'SUCCESS' if success

        raw[:iso8583_return_code_description] || raw[:error] || required_status_message(raw, success_criteria)
      end

      # success_criteria can be:
      #   - a string or an array of strings (if one of many responses)
      #   - An array of strings if one of many responses could be considered a
      #     success.
      def success_criteria_success?(raw, success_criteria)
        success_criteria.include?(raw[:last_event]) || raw[:ok].present?
      end

      def action_success?(action, raw)
        case action
        when 'store'
          raw[:token].present?
        else
          false
        end
      end

      def error_code_from(success, raw)
        raw[:iso8583_return_code_code] || raw[:error_code] || nil unless success == 'SUCCESS'
      end

      def required_status_message(raw, success_criteria)
        "A transaction status of #{success_criteria.collect { |c| "'#{c}'" }.join(' or ')} is required." if !success_criteria.include?(raw[:last_event])
      end

      def authorization_from(action, raw, options)
        order_id = order_id_from(raw)

        case action
        when 'store'
          authorization_from_token_details(
            order_id: order_id,
            token_id: raw[:payment_token_id],
            token_scope: 'shopper',
            customer: options[:customer]
          )
        else
          order_id
        end
      end

      def order_id_from(raw)
        pair = raw.detect { |k, v| k.to_s =~ /_order_code$/ }
        (pair ? pair.last : nil)
      end

      def authorization_from_token_details(options={})
        [options[:order_id], options[:token_id], options[:token_scope], options[:customer]].join('|')
      end

      def order_id_from_authorization(authorization)
        token_details_from_authorization(authorization)[:order_id]
      end

      def token_details_from_authorization(authorization)
        order_id, token_id, token_scope, customer = authorization.split('|')

        token_details = {}
        token_details[:order_id] = order_id if order_id.present?
        token_details[:token_id] = token_id if token_id.present?
        token_details[:token_scope] = token_scope if token_scope.present?
        token_details[:customer] = customer if customer.present?

        token_details
      end

      def payment_details_from(payment_method)
        payment_details = {}
        if payment_method.respond_to?(:number)
          payment_details[:payment_type] = :credit
        else
          token_details = token_details_from_authorization(payment_method)
          payment_details.merge!(token_details)
          if token_details.has_key?(:token_id)
            payment_details[:payment_type] = :token
          else
            payment_details[:payment_type] = :pay_as_order
          end
        end

        payment_details
      end

      def credit_fund_transfer_attribute(options)
        return unless options[:credit]

        {'action' => 'REFUND'}
      end

      def encoded_credentials
        credentials = "#{@options[:login]}:#{@options[:password]}"
        "Basic #{[credentials].pack('m').strip}"
      end

      def currency_exponent(currency)
        return 0 if non_fractional_currency?(currency)
        return 3 if three_decimal_currency?(currency)

        return 2
      end

      def card_code_for(payment_method)
        CARD_CODES[card_brand(payment_method)] || CARD_CODES['unknown']
      end
    end
  end
end
