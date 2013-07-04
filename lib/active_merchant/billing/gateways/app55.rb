module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # App55 payment gateway for active Merchant
    # See : www.app55.com
    # V0.8.0

    # Note there is no test account currently so to run the remote tests modify 
    #  the file test/fixtures.yml according to the comments for app55: 
     
    # Not Yet Implemented:
    #   void/refund/update

    class App55Gateway < Gateway

      # Gateway meta data
      self.test_url = 'http://dev.app55.com/v1'
      self.live_url = 'https://api.app55.com/v1'
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['AU', 'BR', 'CA', 'CH', 'CL', 'CN', 'CO', 'CZ', 'DK', 'EU', 'GB', 'HK', 'HU', 'ID', 'IS', 'JP', 'KE', 'KR', 'MX', 'MY', 'NO', 'NZ', 'PH', 'PL', 'TH', 'TW', 'US', 'VN', 'ZA']
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb, :maestro, :solo]
      self.default_currency = 'UKP'
      self.money_format = :dollars
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.app55.com/'
      # The name of the gateway
      self.display_name = 'App55'

      # Public Gateway API

      # Create gateway
      #
      # options:
      #       :ApiKey - merchants App55 API Key
      #       :ApiSecret - merchants App55 Secret Key
      def initialize(options = {})
        requires!(options, :ApiKey, :ApiSecret)
        @api_key = options[:ApiKey]
        @api_secret = options[:ApiSecret]
        super
      end

      # Make a purchase (authorize and commit)
      #
      # money          - The monetary amount of the transaction in cents.
      # payment_method - The CreditCard or the App55 card token.
      # options        - A standard ActiveMerchant options hash
      def purchase(money, creditcard, options = {})
        options[:commit] = true
        authorize(money, creditcard, options)
      end

      # Authorize a transaction.
      #
      # money          - The monetary amount of the transaction in cents.
      # payment_method - The CreditCard or the App55 card token.
      # options        - A standard ActiveMerchant options hash
      def authorize(money, creditcard, options = {})
        post = {}
        add_user(post, options)
        add_creditcard(post, creditcard, options)
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

      #Advanced payment card system methods

      # Refund transaction.
      #
      # money          - The monetary amount to refund in cents.
      # authorization  - The App55 transaction id string.
      # options        - A standard ActiveMerchant options hash
      def refund(money, authorization, options={})
        raise ArgumentError, "Void/refund unsupported in this version of App55 API."
      end

      # Void transaction.
      #
      # authorization  - The App55 transaction id string.
      # options        - A standard ActiveMerchant options hash
      def void(authorization, options={})
        raise ArgumentError, "Void/refund unsupported in this version of App55 API."
      end

      # Store a credit card in the App55 vault.
      #
      # credit_card    - The CreditCard to store
      # options        - A standard ActiveMerchant options hash
      def store(creditcard, options={})
        post = {}
        add_user(post, options)
        add_creditcard(post, creditcard, options)
        commit(:post, "card", post)
      end

      # Remove a credit card from the App55 vault.
      #
      # credit_card    - The CreditCard to store
      # options        - A standard ActiveMerchant options hash
      def unstore(authorization, options={})
        requires!(options, :customer)
        # ruby's Net::HTTP library doesn't support a HTTP request body for DELETE methods
        # as an alternative pass the method delete as a parameter
        post = {}
        add_user(post, options)
        commit(:post, "card/#{authorization}?method=delete", post)
      end

      #Supporting methods

      private

      def add_user(post, options)
        user = {}
        user[:id] = options[:customer] if options[:customer]
        post[:user] = user unless user.blank?
      end

      def add_customer_data(post, options)
        metadata_options = [:description,:browser_ip,:user_agent,:referrer]
        post.update(options.slice(*metadata_options))

      end

      def add_creditcard(post, creditcard, options)

        if creditcard.respond_to?(:number)
          card = {}
          card[:number] = creditcard.number
          card[:expiry] = ("%02d". % creditcard.month) +  '/' + creditcard.year.to_s
          card[:security_code] = creditcard.verification_value if creditcard.verification_value?
          card[:holder_name] = creditcard.name if creditcard.name
          add_address(card, options)
          post[:card] = card

        elsif creditcard.kind_of?(String)
          card = {}
          card[:token] = creditcard
          post[:card] = card
        end
      end

      def add_address(card, options)
        return unless card && card.kind_of?(Hash)
        reg_addr = {}
        if address = options[:billing_address] || options[:address]
          reg_addr[:street] = address[:address1] if address[:address1]
          reg_addr[:street2] = address[:address2] if address[:address2]
          reg_addr[:country] = address[:country] if address[:country]
          reg_addr[:postal_code] = address[:zip] if address[:zip]
          #card[:??] = address[:state] if address[:state]
          reg_addr[:city] = address[:city] if address[:city]
          card[:address] = reg_addr
        end
      end

      def add_transaction(post, money, options)
        transaction = {}
        add_amount(transaction, money, options)
        transaction[:description] = options[:description] || options[:email]
        transaction[:commit] = true if options[:commit]
        post[:transaction] = transaction
      end

      def add_amount(obj, money, options)
        obj[:amount] = amount(money)
        obj[:currency] = (options[:currency] || currency(money))
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(method, resource, parameters=nil, meta={})
        raw_response = response = nil
        success = false
        begin
          u = url(resource)
          p = post_data(parameters)
          h =  headers()
          raw_response = ssl_request(method, u,p,h)
          response = parse(raw_response)
          success = response.key?("sig")
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        #Process result
        Response.new(success,
                     success ? "OK" : response["error"]["message"],
                     response,
                     :test => test?,
                     :authorization => response.key?("transaction") ? response["transaction"]["id"] : false
        )
      end


      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
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
        (test? ? self.test_url : self.live_url) + '/' + resource
      end

      def message_from(response)
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

      def headers()
        @@ua ||= JSON.dump({
                               :bindings_version => ActiveMerchant::VERSION,
                               :lang => 'ruby',
                               :lang_version => "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})",
                               :platform => RUBY_PLATFORM,
                               :publisher => 'active_merchant',
                               :uname => (RUBY_PLATFORM =~ /linux|darwin/i ? `uname -a 2>/dev/null`.strip : nil)
                           })

        {
            "Authorization" => "Basic " + Base64.strict_encode64(@api_key.to_s + ":" + @api_secret.to_s),
            "User-Agent" => "ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
        }
      end

    end
  end
end

