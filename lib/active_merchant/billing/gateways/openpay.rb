module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class OpenpayGateway < Gateway
      self.live_url = 'https://api.openpay.mx/v1/'
      self.test_url = 'https://sandbox-api.openpay.mx/v1/'

      self.supported_countries = ['MX']
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.homepage_url = 'http://www.openpay.mx/'
      self.display_name = 'Openpay'
      self.default_currency = 'MXN'

      # Instantiate a instance of OpenpayGateway by passing through your
      # merchant id and private api key.
      #
      # === To obtain your own credentials
      # 1. Visit http://openpay.mx
      # 2. Sign up
      # 3. Activate your account clicking on the email confirmation
      def initialize(options = {})
        requires!(options, :key, :merchant_id)
        @api_key = options[:key]
        @merchant_id = options[:merchant_id]
        super
      end

      def purchase(money, creditcard, options = {})
        post = create_post_for_auth_or_purchase(money, creditcard, options)
        commit(:post, get_path('charges', options), post, options)
      end

      def authorize(money, creditcard, options = {})
        post = create_post_for_auth_or_purchase(money, creditcard, options)
        post[:capture] = false
        commit(:post, get_path('charges', options), post, options)
      end

      def capture(money, authorization, options = {})
        post = {}
        post[:amount] = amount(money) if money
        resource = get_path("charges/#{CGI.escape(authorization)}/capture", options)
        commit(:post, resource, post, options)
      end

      def void(identification, options = {})
        resource = get_path("charges/#{CGI.escape(identification)}/refund", options)
        commit(:post, resource, nil, options)
      end

      def refund(money, identification, options = {})
        post = {}
        post[:description] = options[:description]
        post[:amount] = amount(money)
        resource = get_path("charges/#{CGI.escape(identification)}/refund", options)
        commit(:post, resource, post, options)
      end

      def store(creditcard, options = {})
        card_params = {}
        add_creditcard(card_params, creditcard, options)
        card = card_params[:card]

        if options[:customer].present?
          commit(:post, "customers/#{CGI.escape(options[:customer])}/cards", card, options)
        else
          requires!(options, :email, :name)
          post = {}
          post[:name] = options[:name]
          post[:email] = options[:email]
          post[:requires_account] = false
          MultiResponse.run(:first) do |r|
            r.process { commit(:post, 'customers', post, options) }

            if(r.success? && !r.params['id'].blank?)
              customer_id = r.params['id']
              r.process { commit(:post, "customers/#{customer_id}/cards", card, options) }
            end
          end
        end
      end

      def unstore(customer_id, card_id = nil, options = {})
        if card_id.nil?
          commit(:delete, "customers/#{CGI.escape(customer_id)}", nil, options)
        else
          commit(:delete, "customers/#{CGI.escape(customer_id)}/cards/#{CGI.escape(card_id)}", nil, options)
        end
      end

      def supports_scrubbing
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((card_number\\?":\\?")[^"\\]*)i, '\1[FILTERED]').
          gsub(%r((cvv2\\?":\\?")[^"\\]*)i, '\1[FILTERED]')
      end
      
      private

      def create_post_for_auth_or_purchase(money, creditcard, options)
        post = {}
        post[:amount] = amount(money)
        post[:method] = 'card'
        post[:description] = options[:description]
        post[:currency] = options[:currency] ? options[:currency] : "MXN"
        post[:order_id] = options[:order_id]
        post[:device_session_id] = options[:device_session_id]
        if options[:fraud_safe].present? 
          metadata = {}
          metadata[:fraud_safe] = options[:fraud_safe];
          post[:metadata] = metadata
        end
        add_creditcard(post, creditcard, options)
        add_customer_info(post, options)
        post
      end

      def add_creditcard(post, creditcard, options)
        if creditcard.kind_of?(String)
          post[:source_id] = creditcard
        elsif creditcard.respond_to?(:number)
          card = {
            card_number: creditcard.number,
            expiration_month: "#{sprintf("%02d", creditcard.month)}",
            expiration_year: "#{"#{creditcard.year}"[-2, 2]}",
            cvv2: creditcard.verification_value,
            holder_name: creditcard.name
          }
          add_billing_address(card, options)
          post[:card] = card
        end
      end
      
      def add_customer_info(post, options) 
        if((options[:name] && options[:email]) && !options[:customer])
          customer = {}
          customer[:name] = options[:name] if options[:name]
          customer[:email] = options[:email] if options[:email]
          customer[:phone_number] = options[:phone] if options[:phone]
          customer[:external_id] = options[:external_id] if options[:external_id]
          add_shipment_address(customer, options)
  
          post[:customer] = customer
        end
      end
      
      def add_shipment_address(post, options)
        if(address = options[:shipping_address])
          post[:address] = {}
          post[:address][:line1] = address[:address1] if address[:address1]
          post[:address][:line2] = address[:address2] if address[:address2]
          post[:address][:line3] = address[:name] if address[:name]
          post[:address][:postal_code] = address[:zip] if address[:zip]
          post[:address][:state] = address[:state] if address[:state]
          post[:address][:city] = address[:city] if address[:city]
          post[:address][:country_code] = address[:country] if address[:country]
          
        end
      end

      def add_billing_address(card, options)
        return unless card.kind_of?(Hash)
        if address = (options[:billing_address] || options[:address])
          card[:address] = {
            line1: address[:address1],
            line2: address[:address2],
            line3: address[:company],
            city: address[:city],
            postal_code: address[:zip],
            state: address[:state],
            country_code: address[:country]
          }
        end
      end
      
      def get_path(resource, options) 
        if options[:customer].present?
          "customers/#{CGI.escape(options[:customer])}/" + resource
        else
          resource
        end
      end

      def headers(options = {})
        {
          "Content-Type" => "application/json",
          "Authorization" => "Basic " + Base64.encode64(@api_key.to_s + ":").strip,
          "User-Agent" => "Openpay/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          "X-Openpay-Client-User-Agent" => user_agent
        }
      end

      def parse(body)
        return {} unless body
        JSON.parse(body)
      end

      def commit(method, resource, parameters, options = {})
        response = http_request(method, resource, parameters, options)
        success = !error?(response)

        Response.new(success,
          (success ? response['error_code'] : response['description']),
          response,
          :test => test?,
          :authorization => response['id']
        )
      end

      def http_request(method, resource, parameters={}, options={})
        url = (test? ? self.test_url : self.live_url) + @merchant_id + '/' + resource
        raw_response = nil
        begin
          raw_response = ssl_request(method, url, (parameters ? parameters.to_json : nil), headers(options))
          parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response_error(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def error?(response)
        response.key?('error_code')
      end

      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Openpay API.  Please contact soporte@openpay.mx if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
            'category' => 'request',
            'error_code' => '9999',
            'description' => msg
        }
      end
    end
  end
end
