module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AdyenCheckoutGateway < Gateway
      self.test_url = 'https://checkout-test.adyen.com/'

      self.supported_countries = %w(AT AU BE BG BR CH CY CZ DE DK EE ES FI FR GB GI GR HK HU IE IS IT LI LT LU LV MC MT MX NL NO PL PT RO SE SG SK SI US)
      self.default_currency = 'USD'
      self.currencies_without_fractions = %w(CVE DJF GNF IDR JPY KMF KRW PYG RWF UGX VND VUV XAF XOF XPF)
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb, :dankort, :maestro, :discover, :elo, :naranja, :cabal, :unionpay]

      self.money_format = :cents

      self.homepage_url = 'https://www.adyen.com/'
      self.display_name = 'Adyen'

      PAYMENTS_API_VERSION = 'v51'
      PAL_API_VERSION = 'v49'
      PAL_TEST_URL = 'https://pal-test.adyen.com/pal/servlet/'

      STANDARD_ERROR_CODE_MAPPING = {
          '101' => STANDARD_ERROR_CODE[:incorrect_number],
          '103' => STANDARD_ERROR_CODE[:invalid_cvc],
          '131' => STANDARD_ERROR_CODE[:incorrect_address],
          '132' => STANDARD_ERROR_CODE[:incorrect_address],
          '133' => STANDARD_ERROR_CODE[:incorrect_address],
          '134' => STANDARD_ERROR_CODE[:incorrect_address],
          '135' => STANDARD_ERROR_CODE[:incorrect_address],
      }

      def initialize(options={})
        requires!(options, :username, :password, :merchant_account, :url_prefix)
        @username, @password, @merchant_account, @url_prefix = options.values_at(:username, :password, :merchant_account, :url_prefix)
        super
      end

      def purchase(money, payment, options={})
        post = init_post(options)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_extra_data(post, options)
        add_stored_credentials(post, payment, options)
        add_shopper_reference(post, options)
        commit('payments', post, options)
      end

      def refund(money, authorization, options={})
        post = init_post(options)
        add_invoice_for_modification(post, money, options)
        add_original_reference(post, authorization)
        commit('refund', post, options)
      end

      def store(credit_card, options={})
        return details(options) if options[:three_ds_data]

        requires!(options, :order_id)
        post = init_post(options)
        add_invoice(post, 0, options)
        add_payment(post, credit_card)
        add_extra_data(post, options)
        add_stored_credentials(post, credit_card, options)
        add_address(post, options)
        add_three_ds_data(post, options) if options[:allow3DS2]

        initial_response = commit('payments', post, options)

        if initial_response.success? && card_not_stored?(initial_response)
          unsupported_failure_response(initial_response)
        else
          initial_response
        end
      end

      def update(credit_card, options = {})
        post = init_post(options)
        add_invoice(post, 0, options)
        add_update_card_details(post, credit_card, options[:stored_payment_method_id])
        add_extra_data(post, options)
        add_stored_credentials(post, credit_card, options)
        add_address(post, options)

        commit('payments', post, options)
      end

      def unstore(identification, options = {})
        post = init_post(identification)
        post[:shopperReference] = identification[:customer_profile_token]
        post[:recurringDetailReference] = identification[:payment_profile_token]
        commit('disable', post, options)
      end

      def details(options)
        post = {}
        add_three_ds_details(post, options)
        commit('payments/details', post, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
            gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
            gsub(%r(("number\\?":\\?")[^"]*)i, '\1[FILTERED]').
            gsub(%r(("cvc\\?":\\?")[^"]*)i, '\1[FILTERED]').
            gsub(%r(("cavv\\?":\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      AVS_MAPPING = {
          '0'  => 'R',  # Unknown
          '1'  => 'A',  # Address matches, postal code doesn't
          '2'  => 'N',  # Neither postal code nor address match
          '3'  => 'R',  # AVS unavailable
          '4'  => 'E',  # AVS not supported for this card type
          '5'  => 'U',  # No AVS data provided
          '6'  => 'Z',  # Postal code matches, address doesn't match
          '7'  => 'D',  # Both postal code and address match
          '8'  => 'U',  # Address not checked, postal code unknown
          '9'  => 'B',  # Address matches, postal code unknown
          '10' => 'N',  # Address doesn't match, postal code unknown
          '11' => 'U',  # Postal code not checked, address unknown
          '12' => 'B',  # Address matches, postal code not checked
          '13' => 'U',  # Address doesn't match, postal code not checked
          '14' => 'P',  # Postal code matches, address unknown
          '15' => 'P',  # Postal code matches, address not checked
          '16' => 'N',  # Postal code doesn't match, address unknown
          '17' => 'U',  # Postal code doesn't match, address not checked
          '18' => 'I',  # Neither postal code nor address were checked
          '19' => 'L',  # Name and postal code matches.
          '20' => 'V',  # Name, address and postal code matches.
          '21' => 'O',  # Name and address matches.
          '22' => 'K',  # Name matches.
          '23' => 'F',  # Postal code matches, name doesn't match.
          '24' => 'H',  # Both postal code and address matches, name doesn't match.
          '25' => 'T',  # Address matches, name doesn't match.
          '26' => 'N'   # Neither postal code, address nor name matches.
      }

      CVC_MAPPING = {
          '0' => 'P', # Unknown
          '1' => 'M', # Matches
          '2' => 'N', # Does not match
          '3' => 'P', # Not checked
          '4' => 'S', # No CVC/CVV provided, but was required
          '5' => 'U', # Issuer not certifed by CVC/CVV
          '6' => 'P'  # No CVC/CVV provided
      }

      def add_extra_data(post, options)
        post[:telephoneNumber] = options[:billing_address][:phone] if options.dig(:billing_address, :phone)
        post[:shopperEmail] = options[:shopper_email] if options[:shopper_email]
        post[:shopperIP] = options[:shopper_ip] if options[:shopper_ip]
        post[:shopperStatement] = options[:shopper_statement] if options[:shopper_statement]
        post[:fraudOffset] = options[:fraud_offset] if options[:fraud_offset]
        post[:selectedBrand] = options[:selected_brand] if options[:selected_brand]
        post[:deliveryDate] = options[:delivery_date] if options[:delivery_date]
        post[:merchantOrderReference] = options[:merchant_order_reference] if options[:merchant_order_reference]
        post[:captureDelayHours] = options[:capture_delay_hours] if options[:capture_delay_hours]
        post[:additionalData] ||= {}
        post[:additionalData][:overwriteBrand] = normalize(options[:overwrite_brand]) if options[:overwrite_brand]
        post[:additionalData][:customRoutingFlag] = options[:custom_routing_flag] if options[:custom_routing_flag]
        post[:additionalData][:authorisationType] = options[:authorisation_type] if options[:authorisation_type]
        post[:additionalData][:adjustAuthorisationData] = options[:adjust_authorisation_data] if options[:adjust_authorisation_data]
        post[:additionalData][:industryUsage] = options[:industry_usage] if options[:industry_usage]
        post[:additionalData][:updateShopperStatement] = options[:update_shopper_statement] if options[:update_shopper_statement]
        post[:additionalData][:RequestedTestAcquirerResponseCode] = options[:requested_test_acquirer_response_code] if options[:requested_test_acquirer_response_code] && test?
        post[:deviceFingerprint] = options[:device_fingerprint] if options[:device_fingerprint]
        post[:storePaymentMethod] = true
        add_risk_data(post, options)
        add_shopper_reference(post, options)
      end

      def add_risk_data(post, options)
        if (risk_data = options[:risk_data])
          risk_data = Hash[risk_data.map { |k, v| ["riskdata.#{k}", v] }]
          post[:additionalData].merge!(risk_data)
        end
      end

      def add_three_ds_data(post, options)
        post[:additionalData] ||= {}
        post[:additionalData][:allow3DS2] = options[:allow3DS2] if options[:allow3DS2]
        post[:channel] = options[:channel] if options[:channel]
        post[:origin] = options[:origin] if options[:origin]
        post[:browserInfo] = options[:browser_info] if options[:browser_info] # Autopopulated with `populateBrowserInfoFor3ds` service enabled
      end

      def add_three_ds_details(post, options)
        post[:paymentData] = options[:three_ds_data]['paymentData']
        post[:details] = options[:three_ds_data]['details']
      end

      def add_splits(post, options)
        return unless split_data = options[:splits]

        splits = []
        split_data.each do |split|
          amount = {
              value: split['amount']['value'],
          }
          amount[:currency] = split['amount']['currency'] if split['amount']['currency']

          split_hash = {
              amount: amount,
              type: split['type'],
              reference: split['reference']
          }
          split_hash['account'] = split['account'] if split['account']
          splits.push(split_hash)
        end
        post[:splits] = splits
      end

      def add_stored_credentials(post, payment, options)
        add_shopper_interaction(post, payment, options)
        add_recurring_processing_model(post, options)
      end

      def add_merchant_account(post, options)
        post[:merchantAccount] = options[:merchant_account] || @merchant_account
      end

      def add_shopper_reference(post, options)
        post[:shopperReference] = options[:shopper_reference] if options[:shopper_reference]
      end

      def add_shopper_interaction(post, payment, options={})
        if options.dig(:stored_credential, :initial_transaction) || (payment.respond_to?(:verification_value) && payment.verification_value)
          shopper_interaction = 'Ecommerce'
        else
          shopper_interaction = 'ContAuth'
        end

        post[:shopperInteraction] = options[:shopper_interaction] || shopper_interaction
      end

      def add_recurring_processing_model(post, options)
        return unless options.dig(:stored_credential, :reason_type) || options[:recurring_processing_model]

        if options.dig(:stored_credential, :reason_type) && options[:stored_credential][:reason_type] == 'unscheduled'
          recurring_processing_model = 'CardOnFile'
        else
          recurring_processing_model = 'Subscription'
        end

        post[:recurringProcessingModel] = options[:recurring_processing_model] || recurring_processing_model
      end

      def add_address(post, options)
        if address = options[:shipping_address]
          post[:deliveryAddress] = {}
          post[:deliveryAddress][:street] = address[:address1] || 'NA'
          post[:deliveryAddress][:houseNumberOrName] = address[:address2] || 'NA'
          post[:deliveryAddress][:postalCode] = address[:zip] if address[:zip]
          post[:deliveryAddress][:city] = address[:city] || 'NA'
          post[:deliveryAddress][:stateOrProvince] = get_state(address)
          post[:deliveryAddress][:country] = address[:country] if address[:country]
        end
        return unless post[:paymentMethod]&.kind_of?(Hash)

        if (address = options[:billing_address] || options[:address]) && address[:country]
          post[:billingAddress] = {}
          post[:billingAddress][:street] = address[:address1] || 'NA'
          post[:billingAddress][:houseNumberOrName] = address[:address2] || 'NA'
          post[:billingAddress][:postalCode] = address[:zip] if address[:zip]
          post[:billingAddress][:city] = address[:city] || 'NA'
          post[:billingAddress][:stateOrProvince] = get_state(address)
          post[:billingAddress][:country] = address[:country] if address[:country]
        end
      end

      def get_state(address)
        address[:state] && !address[:state].blank? ? address[:state] : 'NA'
      end

      def add_invoice(post, money, options)
        currency = options[:currency] || currency(money)
        amount = {
            value: localized_amount(money, currency),
            currency: currency
        }
        post[:amount] = amount
      end

      def add_invoice_for_modification(post, money, options)
        currency = options[:currency] || currency(money)
        amount = {
            value: localized_amount(money, currency),
            currency: currency
        }
        post[:modificationAmount] = amount
      end

      def add_payment(post, payment)
        if payment.is_a?(String)
          payment_method = {
              type: "scheme",
              storedPaymentMethodId: payment
          }
          post[:paymentMethod] = payment_method
        else
          add_card(post, payment)
        end
      end

      def add_update_card_details(post, credit_card, stored_payment_method_id)
        card = {
          expiryMonth: credit_card.month,
          expiryYear: credit_card.year,
          holderName: credit_card.name,
          storedPaymentMethodId: stored_payment_method_id
        }
        post[:paymentMethod] = card
      end

      def add_card(post, credit_card)
        card = {
            expiryMonth: credit_card.month,
            expiryYear: credit_card.year,
            holderName: credit_card.name,
            number: credit_card.number,
            cvc: credit_card.verification_value,
            type: "scheme"
        }

        card.delete_if { |_k, v| v.blank? }
        requires!(card, :expiryMonth, :expiryYear, :holderName, :number)
        post[:paymentMethod] = card
      end

      def add_original_reference(post, authorization)
        _, original_psp_reference, _ = authorization.split('#')
        post[:originalReference] = single_reference(authorization) || original_psp_reference
      end

      def single_reference(authorization)
        authorization unless authorization.include?('#')
      end

      def parse(body)
        return {} if body.blank?

        JSON.parse(body)
      end

      def commit(action, parameters, options)
        begin
          raw_response = ssl_post(url(action), post_data(action, parameters), request_headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = parse(raw_response)
        end
        success = success_from(action, response)
        Response.new(
            success,
            message_from(action, response),
            response,
            authorization: authorization_from(parameters, response),
            test: test?,
            error_code: success ? nil : error_code_from(response),
            avs_result: AVSResult.new(:code => avs_code_from(response)),
            cvv_result: CVVResult.new(cvv_result_from(response))
        )
      end

      def avs_code_from(response)
        AVS_MAPPING[response['additionalData']['avsResult'][0..1].strip] if response.dig('additionalData', 'avsResult')
      end

      def cvv_result_from(response)
        CVC_MAPPING[response['additionalData']['cvcResult'][0]] if response.dig('additionalData', 'cvcResult')
      end

      def use_pal_endpoint?(action)
        action == "refund" || action == "disable"
      end

      def endpoint(action)
        return "Payment/#{PAL_API_VERSION}/#{action}" if action == "refund"
        return "Recurring/#{PAL_API_VERSION}/#{action}" if action == "disable"

        "#{PAYMENTS_API_VERSION}/#{action}"
      end

      def checkout_live_url
        "https://#{@url_prefix}-checkout-live.adyenpayments.com/checkout/"
      end

      def pal_live_url
        "https://#{@url_prefix}-pal-live.adyenpayments.com/pal/servlet/"
      end

      def url(action)
        if test?
          use_pal_endpoint?(action) ? "#{PAL_TEST_URL}#{endpoint(action)}" : "#{test_url}#{endpoint(action)}"
        elsif @options[:subdomain]
          "https://#{@options[:subdomain]}-pal-live.adyenpayments.com/pal/servlet/#{endpoint(action)}"
        else
          use_pal_endpoint?(action) ? "#{pal_live_url}#{endpoint(action)}" : "#{checkout_live_url}#{endpoint(action)}"
        end
      end

      def basic_auth
        Base64.strict_encode64("#{@username}:#{@password}")
      end

      def request_headers(options)
        headers = {
            'Content-Type' => 'application/json',
            'Authorization' => "Basic #{basic_auth}"
        }
        headers['Idempotency-Key'] = options[:idempotency_key] if options[:idempotency_key]
        headers
      end

      def success_from(action, response)
        case action.to_s
        when 'payments/details'
          response['resultCode'] == 'Authorised'
        when 'payments'
          ['Authorised', 'Received', 'RedirectShopper'].include?(response['resultCode'])
        when 'refund'
          response['response'] == "[#{action}-received]"
        when 'disable'
          response['response'] == "[detail-successfully-disabled]"
        else
          false
        end
      end

      def message_from(action, response)
        return authorize_message_from(response) if action.to_s == 'authorise' || action.to_s == 'authorise3d'

        response['response'] || response['message'] || refusal_code_and_reason(response)
      end

      def authorize_message_from(response)
        if response['refusalReason'] && response['additionalData'] && response['additionalData']['refusalReasonRaw']
          "#{response['refusalReason']} | #{response['additionalData']['refusalReasonRaw']}"
        else
          response['refusalReason'] || response['resultCode'] || response['message'] || response['result']
        end
      end

      def refusal_code_and_reason(response)
        if response['refusalReason'].present?
          "#{response['resultCode']} | #{response['refusalReason']}"
        else
          response['resultCode']
        end
      end

      def authorization_from(parameters, response)
        return nil if response['pspReference'].nil?

        recurring = response['additionalData']['recurring.recurringDetailReference'] if response['additionalData']

        "#{parameters[:originalReference]}##{response['pspReference']}##{recurring}"
      end

      def init_post(options = {})
        post = {}
        add_merchant_account(post, options)
        post[:reference] = options[:order_id] if options[:order_id]
        post
      end

      def post_data(_action, parameters = {})
        JSON.generate(parameters)
      end

      def error_code_from(response)
        STANDARD_ERROR_CODE_MAPPING[response['errorCode']]
      end

      def unsupported_failure_response(initial_response)
        Response.new(
            false,
            unsupported_failure_message(initial_response),
            initial_response.params,
            authorization: initial_response.authorization,
            test: initial_response.test,
            error_code: initial_response.error_code,
            avs_result: initial_response.avs_result,
            cvv_result: initial_response.cvv_result[:code]
        )
      end

      def unsupported_failure_message(initial_response)
        return "This card requires 3DSecure verification." if initial_response.params['resultCode'] == 'RedirectShopper'

        'Recurring transactions are not supported for this card type.'
      end

      def card_not_stored?(response)
        response.authorization ? response.authorization.split('#')[2].nil? : true
      end
    end
  end
end
