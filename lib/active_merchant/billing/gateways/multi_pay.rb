module ActiveMerchant
  module Billing
    class MultiPayGateway < Gateway
      # Sandbox test environment
      self.test_url = 'https://ic2.multipay.mx:38263'

      # Production environment
      self.live_url = 'https://ic2.multipay.mx:38263'

      self.supported_countries = ['CL']
      self.default_currency = 'CLP'
      self.supported_cardtypes = %i[visa master american_express]

      self.homepage_url = 'https://www.multipay.mx'
      self.display_name = 'MultiPay'

      CURRENCY_CODES = {
        'CLP' => 152,
        'USD' => 840
      }

      self.money_format = :cents

      STANDARD_ERROR_MAPPING = {
        '001' => STANDARD_ERROR_CODE[:card_declined],
        '002' => STANDARD_ERROR_CODE[:invalid_number],
        '003' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '004' => STANDARD_ERROR_CODE[:invalid_cvc],
        '005' => STANDARD_ERROR_CODE[:expired_card],
        '006' => STANDARD_ERROR_CODE[:processing_error],
        '007' => STANDARD_ERROR_CODE[:config_error]
      }

      def initialize(options = {})
        requires!(options, :company, :branch, :pos)
        super

        @company = options[:company]
        @branch = options[:branch]
        @pos = options[:pos]
        @user = options[:user]
        @password = options[:password]
        @access_token = nil
        @token_expires_at = nil
      end

      def authorize(money, payment, options = {})
        post = {
          AuthorizeSale: build_request_data(money, payment, options, 'AuthorizeSale')
        }

        commit('AuthorizeSale', post)
      end

      def capture(money, authorization, options = {})
        post = {
          Capture: {
            RequestType: 'Settlement',
            OrigReference: authorization.split('#').first,
            Amount: amount(money),
            RequiredInformation: build_required_information, # double check
            Security: build_security_data(options),
            SystemIdentification: '1.0.0',
            Reference: options[:order_id],
            BranchIdentification: @branch,
            CompanyIdentification: @company,
            UserID: options[:user_id]
          }.compact
        }

        commit('Settlement', post)
      end

      def purchase(money, payment, options = {})
        post = {
          Sale: build_request_data(money, payment, options, 'Sale')
        }

        commit('Sale', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: (Bearer|Basic) )[a-zA-Z0-9._=\-]+)i, '\1[FILTERED]').
          gsub(%r((CardNumber: )[0-9]+)i, '\1[FILTERED]').
          gsub(%r((SecurityCode: )[0-9]+)i, '\1[FILTERED]')
      end

      private

      def build_request_data(money, payment, options, request_type)
        {
          RequestType: request_type,
          SystemIdentification: '1.0.0', # optional
          CompanyIdentification: @company,
          BranchIdentification: @branch,
          POSIdentification: @pos,
          CardNumber: payment.number,
          CardExp: expdate(payment),
          SecurityCode: payment.verification_value,
          Security: build_security_data(options),
          Amount: amount(money),
          Reference: options[:order_id],
          CurrencyCode: CURRENCY_CODES[options[:currency] || currency(money)],
          CardReadMode: 'E',
          FacilityPayments: options[:facility_payments] || 1,
          ReadingDeviceType: 'Default',
          MerchantNotifyURL: options[:notify_url],
          UserID: options[:user_id]
        }.compact
      end

      def build_required_information
        [
          {
            Name: 'Branch',
            Value: @branch
          }
        ]
      end

      def build_security_data(options)
        [{
          Type: '3DSecure',
          Values: [
            {
              Name: 'Method',
              Value: options.dig(:three_d_secure, :method) || '3DS-SNAP'
            },
            {
              Name: 'Data',
              Value: {
                AuthenticationECI: options.dig(:three_d_secure, :eci) || '07'
              }.compact
            }
          ]
        }]
      end

      def expdate(payment)
        "#{format(payment.month, :two_digits)}#{format(payment.year, :two_digits)}"
      end

      def parse(body)
        JSON.parse(body, symbolize_names: true)
      rescue JSON::ParserError
        {
          success: false,
          error: 'Invalid JSON response received from MultiPay'
        }
      end

      def commit(action, parameters)
        url = "#{base_url}/QAtoken/CL/Payments/Authorize/5.6.4/#{action}"

        begin
          ensure_access_token
          response = parse(ssl_post(url, post_data(parameters), headers))

          action_response = "#{action}Response".to_sym

          Response.new(
            success_from(response, action_response),
            message_from(response, action_response),
            response,
            authorization: authorization_from(response, action_response),
            avs_result: AVSResult.new(code: response[:avs_result_code]),
            cvv_result: CVVResult.new(response[:cvv_result_code]),
            test: test?,
            error_code: error_code_from(response, action_response)
          )
        rescue ResponseError => e
          raw = e.response.body
          parse(raw)
        rescue StandardError => e
          Response.new(false, "Error: #{e.message}", {}, test: test?)
        end
      end

      def handle_response_error(error)
        response = parse(error.response.body)
        Response.new(
          false,
          response[:Message] || response[:ErrorDescription] || 'Unknown error',
          response,
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response, action)
        response[action][:AuthResultCode] == '00'
      end

      def message_from(response, action)
        response[action][:ResponseMessage] || 'Unknown error'
      end

      def authorization_from(response, action)
        response[action][:Reference]
      end

      def error_code_from(response, action)
        # TODO: check if this is correct
        return unless error_code = response[action][:AuthResultCode]

        STANDARD_ERROR_MAPPING[error_code] || STANDARD_ERROR_CODE[:processing_error]
      end

      def base_url
        test? ? test_url : live_url
      end

      def ensure_access_token
        token_url = "#{base_url}/token?grant_type=client_credentials"
        response = parse(ssl_post(token_url, nil, auth_headers))

        raise StandardError, response[:error_description] if response[:error]

        @access_token = response[:access_token]
        @token_expires_at = Time.now + response[:expires_in].to_i
      end

      def headers
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@access_token}"
        }
      end

      def auth_headers
        {
          'Authorization' => "Basic #{Base64.strict_encode64("#{@user}:#{@password}")}"
        }
      end

      def post_data(parameters)
        parameters.to_json
      end
    end
  end
end
