module ActiveMerchant
  module Billing
    class MultiPayGateway < Gateway
      self.test_url = 'https://ic2.multipay.mx:38263'
      self.live_url = 'https://ic2.multipay.mx:38263'

      self.supported_countries = ['CL']
      self.default_currency = 'CLP'
      self.supported_cardtypes = %i[visa master american_express]

      self.homepage_url = 'https://www.multipay.mx'
      self.display_name = 'MultiPay'

      CURRENCY_CODES = {
        'CLP' => '152',
        'USD' => '840'
      }

      self.money_format = :cents

      ERROR_MAPPING = {
        1 => 'Call Issuer',
        2  => 'Call Ref.',
        3  => 'Invalid business-03',
        4  => 'Hold Card',
        5  => 'Reject Card',
        6  => 'Error-Call',
        8  => 'Identify Client',
        9  => 'Request in progress',
        11  => 'VIP-11 approved ',
        12  => 'Invalid transaction',
        13  => 'Amount invalid',
        14  => 'invalid card',
        15  => 'No such issuer',
        19  => 'Repeat transaction',
        21  => 'No transactions-21',
        25  => 'Invalid ID-25',
        30  => 'Format Error',
        31  => 'Invalid bench',
        33  => 'Collect Expired Card',
        34  => 'Collect Expired Card',
        35  => 'Collect Card-35',
        36  => 'Collect Card-36',
        37  => 'Collect Card-37',
        38  => 'Allowable PIN tries exceeded',
        39  => 'No credit account',
        41  => 'Lost Card-41',
        43  => 'Stolen Card-43',
        51  => 'Insufficient Funds',
        52  => 'Without Check Account'
      }

      def initialize(options = {})
        requires!(options, :company, :branch, :pos)
        super

        @company = options[:company]
        @branch = options[:branch]
        @pos = options[:pos]
        @user = options[:user]
        @password = options[:password]
      end

      def authorize(money, payment, options = {})
        request_data = build_request_data(money, payment, options, 'AuthorizeSale')
        commit('AuthorizeSale', { AuthorizeSale: request_data })
      end

      def capture(money, authorization, options = {})
        post = {
          Settlement: {
            RequestType: 'Settlement',
            SystemIdentification: '1.0.0',
            CompanyIdentification: @company,
            BranchIdentification: @branch,
            POSIdentification: @pos,
            UserID: options[:user_id],
            Reference: options[:order_id],
            Amount: money,
            OrigReference: authorization
          }.compact
        }

        commit('Settlement', post)
      end

      def purchase(money, payment, options = {})
        request_data = build_request_data(money, payment, options, 'Sale')
        commit('Sale', { Sale: request_data })
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(Authorization: (Bearer|Basic) )\S+/, '\1[FILTERED]').
          gsub(/(\\?"CardNumber\\?":\\?")\d+/, '\1[FILTERED]').
          gsub(/(\\?"SecurityCode\\?":\\?")\d+/, '\1[FILTERED]')
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
          Amount: money,
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
        [{ Name: 'Branch', Value: @branch }]
      end

      def build_security_data(options)
        return unless options[:three_d_secure]

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
        "#{format(payment.year, :two_digits)}#{format(payment.month, :two_digits)}"
      end

      def parse(body)
        JSON.parse(body, symbolize_names: true)
      rescue JSON::ParserError
        {
          success: false,
          error: 'Invalid JSON response received from MultiPay'
        }
      end

      def url(action)
        "#{base_url}/token/Spreedly/Payments/Authorize/5.7.0/#{action}"
      end

      def access_token_valid?
        @options[:access_token].present? && @options.fetch(:token_expires, 0).to_i > DateTime.now.strftime('%Q').to_i
      end

      def commit(action, parameters)
        MultiResponse.run do |r|
          r.process { fetch_access_token } unless access_token_valid?
          r.process do
            api_request(action, parameters).tap do |response|
              response.params.merge!(@options.slice(:access_token, :token_expires)) if @options[:new_credentials]
            end
          end
        end
      end

      def api_request(action, parameters)
        response = parse(ssl_post(url(action), post_data(parameters), headers))
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
      rescue StandardError => e
        Response.new(false, "Error: #{e.message}", {}, test: test?)
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
        %w[00].include?(response[action][:AuthResultCode])
      end

      def message_from(response, action)
        response[action][:ResponseMessage] || 'Unknown error'
      end

      def authorization_from(response, action)
        response[action][:Reference]
      end

      def error_code_from(response, action)
        ERROR_MAPPING[response.dig(action, :AuthResultCode)]
      end

      def base_url
        test? ? test_url : live_url
      end

      def fetch_access_token
        url = "#{base_url}/token?grant_type=client_credentials"
        response = parse(ssl_post(url, nil, auth_headers))

        @options[:access_token] = response[:access_token]
        @options[:token_expires] = DateTime.now.strftime('%Q').to_i + (response[:expires_in].to_i * 1000)
        @options[:new_credentials] = true

        success = response[:access_token].present?
        Response.new(
          success,
          response[:token_type] || '',
          response,
          test: test?
        )
      rescue ResponseError => e
        raise OAuthResponseError.new(e)
      end

      def headers
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@options[:access_token]}"
        }
      end

      def auth_headers
        { 'Authorization' => "Basic #{Base64.strict_encode64("#{@user}:#{@password}")}" }
      end

      def post_data(parameters)
        parameters.to_json
      end
    end
  end
end
