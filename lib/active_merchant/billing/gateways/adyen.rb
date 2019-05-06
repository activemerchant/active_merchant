module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AdyenGateway < Gateway

      # we recommend setting up merchant-specific endpoints.
      # https://docs.adyen.com/developers/api-manual#apiendpoints
      self.test_url = 'https://pal-test.adyen.com/pal/servlet/Payment/v40'
      self.live_url = 'https://pal-live.adyen.com/pal/servlet/Payment/v40'

      self.supported_countries = ['AT', 'AU', 'BE', 'BG', 'BR', 'CH', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GB', 'GI', 'GR', 'HK', 'HU', 'IE', 'IS', 'IT', 'LI', 'LT', 'LU', 'LV', 'MC', 'MT', 'MX', 'NL', 'NO', 'PL', 'PT', 'RO', 'SE', 'SG', 'SK', 'SI', 'US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb, :dankort, :maestro,  :discover, :elo]

      self.money_format = :cents

      self.homepage_url = 'https://www.adyen.com/'
      self.display_name = 'Adyen'

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
        requires!(options, :username, :password, :merchant_account)
        @username, @password, @merchant_account = options.values_at(:username, :password, :merchant_account)
        super
      end

      def purchase(money, payment, options={})
        if options[:execute_threed] || options[:threed_dynamic]
          authorize(money, payment, options)
        else
          MultiResponse.run do |r|
            r.process { authorize(money, payment, options) }
            r.process { capture(money, r.authorization, capture_options(options)) }
          end
        end
      end

      def authorize(money, payment, options={})
        requires!(options, :order_id)
        post = init_post(options)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_extra_data(post, payment, options)
        add_stored_credentials(post, payment, options)
        add_address(post, options)
        add_installments(post, options) if options[:installments]
        add_3ds(post, options)
        commit('authorise', post, options)
      end

      def capture(money, authorization, options={})
        post = init_post(options)
        add_invoice_for_modification(post, money, options)
        add_reference(post, authorization, options)
        commit('capture', post, options)
      end

      def refund(money, authorization, options={})
        post = init_post(options)
        add_invoice_for_modification(post, money, options)
        add_original_reference(post, authorization, options)
        commit('refund', post, options)
      end

      def void(authorization, options={})
        post = init_post(options)
        add_reference(post, authorization, options)
        commit('cancel', post, options)
      end

      def adjust(money, authorization, options={})
        post = init_post(options)
        add_invoice_for_modification(post, money, options)
        add_reference(post, authorization, options)
        commit('adjustAuthorisation', post, options)
      end

      def store(credit_card, options={})
        requires!(options, :order_id)
        post = init_post(options)
        add_invoice(post, 0, options)
        add_payment(post, credit_card)
        add_extra_data(post, credit_card, options)
        add_stored_credentials(post, credit_card, options)
        add_recurring_contract(post, options)
        add_address(post, options)
        commit('authorise', post, options)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(0, credit_card, options) }
          options[:idempotency_key] = nil
          r.process(:ignore_result) { void(r.authorization, options) }
        end
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
        '20' => 'V',  # Name, address and postal code matches.
        '23' => 'F',  # Postal code matches, name doesn't match.
        '24' => 'H',  # Both postal code and address matches, name doesn't match.
        '25' => 'T'  # Address matches, name doesn't match.
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

      NETWORK_TOKENIZATION_CARD_SOURCE = {
        'apple_pay' => 'applepay',
        'android_pay' => 'androidpay',
        'google_pay' => 'paywithgoogle'
      }

      def add_extra_data(post, payment, options)
        post[:telephoneNumber] = options[:billing_address][:phone] if options.dig(:billing_address, :phone)
        post[:shopperEmail] = options[:shopper_email] if options[:shopper_email]
        post[:shopperIP] = options[:shopper_ip] if options[:shopper_ip]
        post[:shopperReference] = options[:shopper_reference] if options[:shopper_reference]
        post[:shopperStatement] = options[:shopper_statement] if options[:shopper_statement]
        post[:fraudOffset] = options[:fraud_offset] if options[:fraud_offset]
        post[:selectedBrand] = options[:selected_brand] if options[:selected_brand]
        post[:selectedBrand] ||= NETWORK_TOKENIZATION_CARD_SOURCE[payment.source.to_s] if payment.is_a?(NetworkTokenizationCreditCard)
        post[:deliveryDate] = options[:delivery_date] if options[:delivery_date]
        post[:merchantOrderReference] = options[:merchant_order_reference] if options[:merchant_order_reference]
        post[:additionalData] ||= {}
        post[:additionalData][:overwriteBrand] = normalize(options[:overwrite_brand]) if options[:overwrite_brand]
        post[:additionalData][:customRoutingFlag] = options[:custom_routing_flag] if options[:custom_routing_flag]
        post[:additionalData]['paymentdatasource.type'] = NETWORK_TOKENIZATION_CARD_SOURCE[payment.source.to_s] if payment.is_a?(NetworkTokenizationCreditCard)
        post[:deviceFingerprint] = options[:device_fingerprint] if options[:device_fingerprint]
        add_risk_data(post, options)
      end

      def add_risk_data(post, options)
        if (risk_data = options[:risk_data])
          risk_data = Hash[risk_data.map { |k, v| ["riskdata.#{k}", v] }]
          post[:additionalData].merge!(risk_data)
        end
      end

      def add_stored_credentials(post, payment, options)
        add_shopper_interaction(post, payment, options)
        add_recurring_processing_model(post, options)
      end

      def add_shopper_interaction(post, payment, options={})
        if options.dig(:stored_credential, :initial_transaction) || (payment.respond_to?(:verification_value) && payment.verification_value) || payment.is_a?(NetworkTokenizationCreditCard)
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
        return unless post[:card]&.kind_of?(Hash)
        if (address = options[:billing_address] || options[:address]) && address[:country]
          post[:billingAddress] = {}
          post[:billingAddress][:street] = address[:address1] || 'N/A'
          post[:billingAddress][:houseNumberOrName] = address[:address2] || 'N/A'
          post[:billingAddress][:postalCode] = address[:zip] if address[:zip]
          post[:billingAddress][:city] = address[:city] || 'N/A'
          post[:billingAddress][:stateOrProvince] = address[:state] || 'N/A'
          post[:billingAddress][:country] = address[:country] if address[:country]
        end
      end

      def add_invoice(post, money, options)
        amount = {
          value: amount(money),
          currency: options[:currency] || currency(money)
        }
        post[:amount] = amount
      end

      def add_invoice_for_modification(post, money, options)
        amount = {
          value: amount(money),
          currency: options[:currency] || currency(money)
        }
        post[:modificationAmount] = amount
      end

      def add_payment(post, payment)
        if payment.is_a?(String)
          _, _, recurring_detail_reference = payment.split('#')
          post[:selectedRecurringDetailReference] = recurring_detail_reference
          add_recurring_contract(post, options)
        else
          add_mpi_data_for_network_tokenization_card(post, payment) if payment.is_a?(NetworkTokenizationCreditCard)
          add_card(post, payment)
        end
      end

      def add_card(post, credit_card)
        card = {
          expiryMonth: credit_card.month,
          expiryYear: credit_card.year,
          holderName: credit_card.name,
          number: credit_card.number,
          cvc: credit_card.verification_value
        }

        card.delete_if { |k, v| v.blank? }
        card[:holderName] ||= 'Not Provided' if credit_card.is_a?(NetworkTokenizationCreditCard)
        requires!(card, :expiryMonth, :expiryYear, :holderName, :number)
        post[:card] = card
      end

      def capture_options(options)
        return options.merge(idempotency_key: "#{options[:idempotency_key]}-cap") if options[:idempotency_key]
        options
      end

      def add_reference(post, authorization, options = {})
        _, psp_reference, _ = authorization.split('#')
        post[:originalReference] = single_reference(authorization) || psp_reference
      end

      def add_original_reference(post, authorization, options = {})
        original_psp_reference, _, _ = authorization.split('#')
        post[:originalReference] = single_reference(authorization) || original_psp_reference
      end

      def add_mpi_data_for_network_tokenization_card(post, payment)
        post[:mpiData] = {}
        post[:mpiData][:authenticationResponse] = 'Y'
        post[:mpiData][:cavv] = payment.payment_cryptogram
        post[:mpiData][:directoryResponse] = 'Y'
        post[:mpiData][:eci] = payment.eci || '07'
      end

      def single_reference(authorization)
        authorization if !authorization.include?('#')
      end

      def add_recurring_contract(post, options = {})
        recurring = {
          contract: 'RECURRING'
        }

        post[:recurring] = recurring
      end

      def add_installments(post, options)
        post[:installments] = {
          value: options[:installments]
        }
      end

      def add_3ds(post, options)
        if three_ds_2_options = options[:three_ds_2]
          if browser_info = three_ds_2_options[:browser_info]
            post[:browserInfo] = {
              acceptHeader: browser_info[:accept_header],
              colorDepth: browser_info[:depth],
              javaEnabled: browser_info[:java],
              language: browser_info[:language],
              screenHeight: browser_info[:height],
              screenWidth: browser_info[:width],
              timeZoneOffset: browser_info[:timezone],
              userAgent: browser_info[:user_agent]
            }

            if device_channel = three_ds_2_options[:channel]
              post[:threeDS2RequestData] = {
                deviceChannel: device_channel,
                notificationURL: three_ds_2_options[:notification_url] || 'https://example.com/notification'
              }
            end
          end
        else
          return unless options[:execute_threed] || options[:threed_dynamic]
          post[:browserInfo] = { userAgent: options[:user_agent], acceptHeader: options[:accept_header] }
          post[:additionalData] = { executeThreeD: 'true' } if options[:execute_threed]
        end
      end

      def parse(body)
        return {} if body.blank?
        JSON.parse(body)
      end

      def commit(action, parameters, options)
        begin
          raw_response = ssl_post("#{url}/#{action}", post_data(action, parameters), request_headers(options))
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
          authorization: authorization_from(action, parameters, response),
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

      def url
        if test?
          test_url
        elsif @options[:subdomain]
          "https://#{@options[:subdomain]}-pal-live.adyenpayments.com/pal/servlet/Payment/v18"
        else
          live_url
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
        when 'authorise', 'authorise3d'
          ['Authorised', 'Received', 'RedirectShopper'].include?(response['resultCode'])
        when 'capture', 'refund', 'cancel', 'adjustAuthorisation'
          response['response'] == "[#{action}-received]"
        else
          false
        end
      end

      def message_from(action, response)
        return authorize_message_from(response) if action.to_s == 'authorise'
        response['response'] || response['message']
      end

      def authorize_message_from(response)
        if response['refusalReason'] && response['additionalData'] && response['additionalData']['refusalReasonRaw']
          "#{response['refusalReason']} | #{response['additionalData']['refusalReasonRaw']}"
        else
          response['refusalReason'] || response['resultCode'] || response['message']
        end
      end

      def authorization_from(action, parameters, response)
        return nil if response['pspReference'].nil?
        recurring = response['additionalData']['recurring.recurringDetailReference'] if response['additionalData']
        "#{parameters[:originalReference]}##{response['pspReference']}##{recurring}"
      end

      def init_post(options = {})
        post = {}
        post[:merchantAccount] = options[:merchant_account] || @merchant_account
        post[:reference] = options[:order_id] if options[:order_id]
        post
      end

      def post_data(action, parameters = {})
        JSON.generate(parameters)
      end

      def error_code_from(response)
        STANDARD_ERROR_CODE_MAPPING[response['errorCode']]
      end
    end
  end
end
