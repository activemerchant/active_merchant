require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    # For more information on Balanced visit https://www.balancedpayments.com
    #
    # Instantiate a instance of BalancedGateway by passing through your
    # Balanced API key secret.
    #
    # ==== To obtain an API key of your own
    #
    # 1. Visit https://www.balancedpayments.com
    # 2. Click "Get started"
    # 3. The next screen will give you a test API key of your own
    # 4. When you're ready to generate a production API key click the "Go
    #    live" button on the Balanced dashboard and fill in your marketplace
    #    details.
    #
    module Balanced
      class BalancedError < StandardError
        attr_reader :response

        def initialize(response, msg=nil)
          @response = response
          super(msg || response['description'])
        end

      end
      class CardDeclined < BalancedError

      end
    end
    class BalancedGateway < Gateway
      TEST_URL = LIVE_URL = 'https://api.balancedpayments.com'

      AVS_CODE_TRANSLATOR = {
          # TODO
      }
      CVC_CODE_TRANSLATOR = {
          # TODO
      }

      # The countries the gateway supports merchants from as 2 digit ISO
      # country codes
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'https://www.balancedpayments.com/'
      self.display_name = 'Balanced'
      self.money_format = :cents

      # Creates a new BalancedGateway
      #
      # The gateway requires that a valid api_key be passed in the +options+
      # hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- The Balanced API Secret (REQUIRED)
      def initialize(options = {})
        requires!(options, :login)
        @api_key = options[:login]
        marketplace = options[:marketplace] || load_marketplace()
        set_from_marketplace(marketplace)
        super
      end

      # Performs an authorization (Hold in Balanced nonclementure), which
      # reserves the funds on the customer's credit card, but does not charge
      # the card. An authorization is valid for 7 days
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be authorized as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction
      # or card_uri of a card that was previously tokenized and associated
      # with a Balanced account.
      # * <tt>options</tt> -- A hash of optional parameters with one
      # mandatory parameter :email. You may also pass :account_uri which will
      # save one call to the Balanced API
      def authorize(money, creditcard, options = {})
        requires!(options[:email]) unless options[:account_uri]
        post = {}
        post[:amount] = money
        post[:description] = options[:description] if options[:description]

        create_or_find_account(post, options)
        add_creditcard(post, creditcard, options)
        add_address(creditcard, options)

        create_transaction(:post, @holds_uri, post)
      rescue Balanced::BalancedError => ex
        return failed_response(ex.response)
      end

      # Perform a purchase, which is an authorization and capture in a single
      # operation.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction
      # or card_uri of a card that was previously tokenized and associated
      # with a Balanced account.
      # * <tt>options</tt> -- A hash of optional parameters with one
      # mandatory parameter :email.
      def purchase(money, creditcard, options = {})

        # 1. an account may or may not exist, check if account_uri in the
        #    options. if account_uri not present then lookup or create
        #    account from email address.
        # 2. creditcard may be a card dict or a card_uri (card_uri if already
        #    tokenized). if card dict then we must tokenize before we pass it
        #    through to the debit
        post = {}
        post[:amount] = money
        post[:description] = options[:description] if options[:description]

        create_or_find_account(post, options)
        add_creditcard(post, creditcard, options)
        add_address(creditcard, options)

        create_transaction(:post, @debits_uri, post)
      rescue Balanced::BalancedError => ex
        return failed_response(ex.response)
      end

      # Captures the funds from an authorized transaction (Hold).
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured as an Integer value in cents.
      # * <tt>authorization</tt> -- The uri of an authorization returned from
      # an authorize request.
      def capture(money, authorization, options = {})
        post = {}
        post[:amount] = money if money
        post[:hold_uri] = authorization
        post[:description] = options[:description] if options[:description]
        create_transaction(:post, @debits_uri, post)
      rescue Balanced::BalancedError => ex
        return failed_response(ex.response)
      end

      # Void a previous authorization (Hold)
      #
      # ==== Parameters
      #
      # * <tt>authorization</tt> - The uri of the authorization returned from
      # an authorize request.
      def void(authorization)
        create_transaction(:put, authorization, {
            :is_void => true
        })
      rescue Balanced::BalancedError => ex
        return failed_response(ex.response)
      end


      # Refund a transaction.
      #
      # Returns the money debited from a card to the card from the
      # marketplace's escrow balance.
      #
      # ==== Parameters
      #
      # * <tt>debit_uri</tt> -- The uri of the original transaction against
      #   which the refund is being issued.
      # * <tt>options</tt> -- A hash of parameters. Includes `:amount` if you
      #   want to performa a partial refund. This value will default to the
      #   total amount of the debit that has not been refunded so far.
      def refund(debit_uri, options = {})
        requires!(debit_uri)
        post = {}
        post[:debit_uri] = debit_uri
        post[:amount] = options[:amount] if options[:amount]
        post[:description] = options[:description] if options[:description]
        create_transaction(:post, @refunds_uri, post)
      rescue Balanced::BalancedError => ex
        return failed_response(ex.response)
      end

      private

      # Load URIs for this marketplace by inspecting the marketplace object
      # returned from the uri. http://en.wikipedia.org/wiki/HATEOAS
      def load_marketplace()
        response = http_request(:get, '/v1/marketplaces')
        if is_error(response)
          raise Balanced::BalancedError.new(response,
                'Invalid login credentials supplied')
        end
        response['items'][0]
      end

      def set_from_marketplace(marketplace)

        @marketplace_uri = marketplace['uri']
        @holds_uri = marketplace['holds_uri']
        @debits_uri = marketplace['debits_uri']
        @cards_uri = marketplace['cards_uri']
        @accounts_uri = marketplace['accounts_uri']
        @refunds_uri = marketplace['refunds_uri']

      end

      def create_or_find_account(post, options)
        email_address = options[:email]
        account_uri = nil

        if options.has_key? :account_uri
          account_uri = options[:account_uri]
        end

        if account_uri == nil
          # create an account
          response = http_request(:post, @accounts_uri, {
              :email_address => email_address
          })
          if response.has_key? 'uri'
            account_uri = response['uri']
          else
            # lookup account from Balanced, account_uri should be in the
            # exception in a dictionary called additional
            account_uri = response['extras']['account_uri']
          end
        end

        post[:account_uri] = account_uri

      end

      def add_address(creditcard, options)
        return unless creditcard.kind_of?(Hash)
        if address = options[:billing_address] || options[:address]
          creditcard[:street_address] = address[:address1] if address[:address1]
          creditcard[:street_address] += ' ' + address[:address2] if address[:address2]
          creditcard[:country] = address[:country] if address[:country]
          creditcard[:postal_code] = address[:zip] if address[:zip]
          creditcard[:region] = address[:state] if address[:state]
        end
      end

      def add_creditcard(post, creditcard, options)
        if creditcard.respond_to?(:number)
          card = {}
          card[:card_number] = creditcard.number
          card[:expiration_month] = creditcard.month
          card[:expiration_year] = creditcard.year
          card[:security_code] = creditcard.verification_value if creditcard.verification_value?
          card[:name] = creditcard.name if creditcard.name

          add_address(card, options)

          response = http_request(:post, @cards_uri, card)
          if is_error(response)
            raise Balanced::CardDeclined, response
          end
          card_uri = response['uri']

          # associate this card with the account
          associate_card_to_account(post[:account_uri], card_uri)

          post[:card_uri] = card_uri
        elsif creditcard.kind_of?(String)
          post[:card_uri] = creditcard
        end
      end

      def associate_card_to_account(account_uri, card_uri)
        data = {
            :card_uri => card_uri
        }
        http_request(:put, account_uri, data)
      end

      def http_request(method, url, parameters={}, meta={})
        begin
          if method == :get
            raw_response = ssl_get(LIVE_URL + url, headers(meta))
          else
            raw_response = ssl_request(method,
                                       LIVE_URL + url,
                                       post_data(parameters),
                                       headers(meta))
          end
          parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response_error(raw_response)
        rescue JSON::ParserError => ex
          json_error(raw_response)
        end
      end

      def create_transaction(method, url, parameters, meta={})
        response = http_request(method, url, parameters, meta)
        success = !is_error(response)

        avs_code = AVS_CODE_TRANSLATOR[response['avs_result']]
        security_code = CVC_CODE_TRANSLATOR[response['avs_result']]

        Response.new(success,
                     success ? "Transaction approved" : response["description"],
                     response,
                     :test => @marketplace_uri.index("TEST") ? true : false,
                     :authorization => response["uri"],
                     :avs_result => {:code => avs_code},
                     :cvv_result => security_code,
        )
      end

      def failed_response(response)
        is_test = false
        if @marketplace_uri
          is_test = @marketplace_uri.index("TEST") ? true : false
        end
        Response.new(false,
                     response["description"],
                     response,
                     :test => is_test
        )
      end

      def parse(body)
        JSON.parse(body)
      end

      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Balanced API. Please
contact support@balancedpayments.com if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
            "error" => {
                "message" => msg
            }
        }
      end

      def is_error(response)
        return response.key?('status_code')
      end

      def post_data(params)
        return nil unless params

        params.map do |key, value|
          next if value.blank?
          if value.is_a?(Hash)
            h = {}
            value.each do |k, v|
              h["#{key}[#{k}]"] = v unless v.blank?
            end
            post_data(h)
          else
            "#{key}=#{CGI.escape(value.to_s)}"
          end
        end.compact.join("&")
      end

      def headers(meta={})
        @@ua ||= JSON.dump({
           :bindings_version => ActiveMerchant::VERSION,
           :lang => 'ruby',
           :lang_version => "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})",
           :platform => RUBY_PLATFORM,
           :publisher => 'active_merchant',
           :uname => (RUBY_PLATFORM =~ /linux|darwin/i ? `uname -a 2>/dev/null`.strip : nil)
        })

        {
            "Authorization" => "Basic " + Base64.encode64(@api_key.to_s + ":").strip,
            "User-Agent" => "Balanced/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
            "X-Balanced-User-Agent" => @@ua,
        }
      end
    end
  end
end