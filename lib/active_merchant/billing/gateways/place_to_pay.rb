module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PlaceToPayGateway < Gateway
      self.test_url = 'https://api-co-dev.placetopay.ws/'
      self.live_url = 'https://api-co.placetopay.ws/'

      self.default_currency = 'COP'

      self.supported_countries = ['COL']
      self.supported_cardtypes = %i[visa master american_express discover]
      self.homepage_url = 'https://www.placetopay.com/'
      self.display_name = 'PlaceToPay'

      STANDARD_ERROR_CODE_MAPPING = {}

      ISO_FORMAT_DATE = '%Y-%m-%dT%H:%M:%S%:z'

      def initialize(options = {})      
        requires!(options, :login, :secret_key)
        @login, @secret_key = options.values_at(:login, :secret_key)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_auth(post, options)
        add_payer(post, options)
        add_payment(post, options)
        add_instrument(post, payment, options)
        commit(:post, 'gateway/process', post)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_auth(post, options)
        post[:internalReference] = options[:internalReference]
        post[:authorization] = authorization                
        post[:action] = 'reverse' #Allowed values: reverse refund process void dispersion pre_authorization checkin checkout reauthorization 
        commit(:post, 'gateway/transaction', post)
      end


      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((tranKey)\w+), '\1[FILTERED]').
          gsub(/(number\\?":\\?")(\d*)/, '\1[FILTERED]').
          gsub(/(cvv\\?":\\?")(\d*)/, '\1[FILTERED]')
      end

      private

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def build_url(action, base)
        url = base
        url += action
        url
      end

      def commit(method, action, parameters)
        base_url = (test? ? test_url : live_url)
        url = build_url(action, base_url)

        begin
          url = (test? ? test_url : live_url) + action.to_s
          rel_path = "#{method}/v1/#{action}"
          response = api_request(method, url, rel_path, parameters)

        rescue ResponseError => e
          raw_response = e.response.body
          response = parse(raw_response)
        end

        Response.new(
          success_from(action, response, options),
          message_from(response),
          response,
          test: test?,
          error_code: error_code_from(action, response, options),
          authorization: authorization_from(response),
          network_transaction_id: response['internalReference'],
        )
      end


      def success_from(action, response, options)
        case action
        when :authonly.to_s, :lookup.to_s, :mpiQuery.to_s, :interests.to_s, :generate_otp.to_s,
          :validate_otp.to_s, :capture.to_s, :search.to_s
          return response['status'] && response['status']['status'] === RESPONSES_STATUS[:ok]
        when :sale.to_s, :query_transaction.to_s, :refund.to_s
          return response['status'] && response['status']['status'] === RESPONSES_STATUS[:approved]
        else
          return response['status']['status'];
        end
      end

      def message_from(response)
        response['status'] && response['status']['message'] ? response['status']['message'] :
          COMMON_MESSAGES[:missed]
      end

      def authorization_from(response); 
        return response['authorization']
      end

      def post_data(action, parameters = {})
        JSON.generate(parameters)
      end

      def error_code_from(action, response, options)
        unless success_from(action, response, options)
          # TODO: lookup error code for this response
          STANDARD_ERROR_CODE_MAPPING[response['reason']]
        end
      end

      def add_auth(post, options)
        original_nonce = generate_nonce()
        seed = get_date_in_iso_format()
        tranKey = generate_trans_key(original_nonce, seed)
        post[:auth] = {
          login: @login,
          tranKey: tranKey,
          seed: seed,
          nonce: convert_to_Base64(original_nonce)
        }
      end

      def add_payer(post, options)
        post[:payer] = options[:payer]
      end

      def add_payment(post, options)
        post[:payment] = options[:payment]     
      end

      def add_instrument(post, payment, options)
        post[:instrument] = options[:instrument]
        post[:instrument][:card][:number] = payment.number;
        post[:instrument][:card][:expiration] = (payment.month).to_s + "/" + (payment.month).to_s;
        post[:instrument][:card][:cvv] = payment.verification_value;        
      end

      def add_amount(post, payment, options)
        post[:amount] = {
          currency: options[:currency], #Allowed values: USD COP CRC EUR CAD AUD GBP MXN CLP
          total: options[:total]
        }
      end

      def generate_nonce
        Digest::MD5.hexdigest(rand(10).to_s)
      end

      def get_date_in_iso_format
        Time.now.strftime(ISO_FORMAT_DATE)
      end      

      def convert_to_Base64(value)
        Base64.strict_encode64(value).chomp
      end

      def generate_trans_key(original_nonce, seed)
        base_tran_key = "#{original_nonce}#{seed}#{@secret_key}"
        key_to_digest = Digest::SHA256.digest(base_tran_key)
        convert_to_Base64(key_to_digest)
      end

      def request_headers()
        headers = {'Content-Type' => 'application/json'}
        headers
      end

      def api_request(method, url, rel_path, params)
        params == {} ? body = '' : body = params.to_json
        raw_response = ssl_request(method, url, body, request_headers())
        response = parse(raw_response)
        
        return response
      end

      def parse(body)
        return {} if body.empty? || body.nil?

        JSON.parse(body)
      end      

    end
  end
end