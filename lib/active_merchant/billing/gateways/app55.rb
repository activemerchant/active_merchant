module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class App55Gateway < Gateway
      self.test_url = 'https://sandbox.app55.com/v1/'
      self.live_url = 'https://api.app55.com/v1/'

      self.supported_countries = ['AU', 'BR', 'CA', 'CH', 'CL', 'CN', 'CO', 'CZ', 'DK', 'GB', 'HK', 'HU', 'ID', 'IS', 'JP', 'KE', 'KR', 'MX', 'MY', 'NO', 'NZ', 'PH', 'PL', 'TH', 'TW', 'US', 'VN', 'ZA']
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb, :maestro, :solo]
      self.default_currency = 'UKP'
      self.money_format = :dollars
      self.homepage_url = 'https://www.app55.com/'
      self.display_name = 'App55'

      # Create gateway
      #
      # options:
      #       :api_key - merchants App55 API Key
      #       :api_secret - merchants App55 Secret Key
      def initialize(options = {})
        requires!(options, :api_key, :api_secret)
        @api_key = options[:api_key]
        @api_secret = options[:api_secret]
        super
      end

      # Make a purchase (authorize and commit)
      #
      # money          - The monetary amount of the transaction in cents.
      # payment_method - The CreditCard or the App55 card token.
      # options        - A standard ActiveMerchant options hash
      def purchase(money, payment_method, options = {})
        authorize(money, payment_method, options.merge(commit: true))
      end

      # Authorize a transaction.
      #
      # money          - The monetary amount of the transaction in cents.
      # payment_method - The CreditCard or the App55 card token.
      # options        - A standard ActiveMerchant options hash
      def authorize(money, payment_method, options = {})
        post = {}
        add_creditcard(post, payment_method, options)
        add_transaction(post, money, options)

        commit(:post, 'transaction', post)
      end

      # Commit a pre-authorized transaction.
      #
      # money          - The monetary amount of the transaction in cents.
      # authorization  - The App55 transaction id string.
      # options        - A standard ActiveMerchant options hash
      def capture(money, authorization, options = {})
        commit(:post, "transaction/#{authorization}")
      end

      private

      def add_customer_data(post, options)
        metadata_options = [:description, :browser_ip, :user_agent, :referrer]
        post.update(options.slice(*metadata_options))
      end

      def add_creditcard(post, creditcard, options)
        card = {}
        card[:number] = creditcard.number
        card[:expiry] = ("%02d". % creditcard.month) +  '/' + creditcard.year.to_s
        card[:security_code] = creditcard.verification_value if creditcard.verification_value?
        card[:holder_name] = creditcard.name if creditcard.name
        add_address(card, options)
        post[:card] = card
      end

      def add_address(card, options)
        return unless card && card.kind_of?(Hash)
        address_hash = {}
        if address = (options[:billing_address] || options[:address])
          address_hash[:street] = address[:address1] if address[:address1]
          address_hash[:street2] = address[:address2] if address[:address2]
          address_hash[:country] = address[:country] if address[:country]
          address_hash[:postal_code] = address[:zip] if address[:zip]
          address_hash[:city] = address[:city] if address[:city]
          card[:address] = address_hash
        end
      end

      def add_transaction(post, money, options)
        transaction = {}
        add_amount(transaction, money, options)
        transaction[:description] = (options[:description] || options[:email])
        transaction[:commit] = options[:commit]
        post[:transaction] = transaction
      end

      def add_amount(obj, money, options)
        obj[:amount] = amount(money)
        obj[:currency] = (options[:currency] || currency(money))
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def commit(method, resource, parameters=nil, meta={})
        success = false
        begin
          raw_response = ssl_request(
            method,
            url(resource),
            post_data(parameters),
            headers
          )
          response = parse(raw_response)
          success = response.key?("sig")
        rescue ResponseError => e
          response = parse(e.response.body)
        end

        Response.new(
          success,
          (success ? "OK" : response["error"]["message"]),
          response,
          test: test?,
          authorization: authorization_from(response)
        )
      end

      def authorization_from(response)
        if response.key?("transaction")
          response["transaction"]["id"]
        elsif response.key?("card")
          response["card"]["token"]
        end
      end

      def json_error(raw_response)
        msg = "Invalid response from app55 server: Received: #{raw_response.inspect})"
        {
          "error" => {
            "message" => msg
          }
        }
      end

      def url(resource)
        (test? ? self.test_url : self.live_url) + resource
      end

      def post_data(params)
        return nil unless params

        params.map do |key, value|
          next if value.blank?
          if value.is_a?(Hash)
            h = {}
            value.each do |k, v|
              h["#{key}.#{k}"] = v unless v.blank?
            end
            post_data(h)
          else
            "#{key}=#{CGI.escape(value.to_s)}"
          end
        end.compact.join("&")
      end

      def headers
        {
          "Authorization" => "Basic " + Base64.strict_encode64(@options[:api_key].to_s + ":" + @options[:api_secret].to_s),
          "User-Agent" => user_agent,
        }
      end
    end
  end
end
