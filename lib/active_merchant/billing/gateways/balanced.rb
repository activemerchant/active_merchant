require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    # For more information on Balanced visit https://www.balancedpayments.com
    # or visit #balanced on irc.freenode.net
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
    # ==== Overview
    #
    # Balanced provides a RESTful API, all entities within Balanced are
    # represented by their respective URIs, these are returned in the
    # `authorization` parameter of the Active Merchant Response object.
    #
    # All Response objects will contain a hash property called `params` which
    # holds the raw JSON dictionary returned by Balanced. You can find
    # properties about the operation performed and the object that represents
    # it within this hash.
    #
    # All operations within Balanced are tied to an account, as such, when you
    # perform an `authorization` or a `capture` with a new credit card you
    # must ensure you also pass the `:email` property within the `options`
    # parameter.
    #
    # For more details about Balanced's API visit:
    # https://www.balancedpayments.com/docs
    #
    # ==== Terminology & Transaction Flow
    #
    # * An `authorization` operation will return a Hold URI. An `authorization`
    #   within Balanced is valid until the `expires_at` property. You can see the
    #   exact date of the expiry on the Response object by inspecting the
    #   property `response.params['expires_at']`. The resulting Hold may be
    #   `capture`d or `void`ed at any time before the `expires_at` date for
    #   any amount up to the full amount of the original `authorization`.
    # * A `capture` operation will return a Debit URI. You must pass the URI of
    #   the previously performed `authorization`
    # * A `purchase` will create a Hold and Debit in a single operation and
    #   return the URI of the resulting Debit.
    # * A `void` operation must be performed on an existing `authorization`
    #   and will result in releasing the funds reserved by the
    #   `authorization`.
    # * The `refund` operation must be performed on a previously captured
    #   Debit URI. You may refund any fraction of the original amount of the
    #   debit up to the original total.
    #
    class BalancedGateway < Gateway
      VERSION = '1.0.0'

      TEST_URL = LIVE_URL = 'https://api.balancedpayments.com'

      # The countries the gateway supports merchants from as 2 digit ISO
      # country codes
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'https://www.balancedpayments.com/'
      self.display_name = 'Balanced'
      self.money_format = :cents

      class Error < ActiveMerchant::ActiveMerchantError
        attr_reader :response

        def initialize(response, msg=nil)
          @response = response
          super(msg || response['description'])
        end
      end

      class CardDeclined < Error
      end

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
        super
        initialize_marketplace(options[:marketplace] || load_marketplace)
      end

      # Performs an authorization (Hold in Balanced nonclementure), which
      # reserves the funds on the customer's credit card, but does not charge
      # the card. An authorization is valid until the `expires_at` field in
      # the params Hash passes. See `response.params['expires_at']`. The exact
      # amount of time until an authorization expires depends on the card
      # issuer.
      #
      # If you pass a previously tokenized `credit_card` URI the only other
      # parameter required is `money`. If you pass `credit_card` as a hash of
      # credit card information you must also pass `options` with a `:email`
      # entry.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be authorized as an Integer value in cents.
      # * <tt>credit_card</tt> -- A hash of credit card details for this
      #   transaction or the URI of a card previously stored in Balanced.
      # * <tt>options</tt> -- A hash of optional parameters.
      #
      # ==== Options
      #
      # If you are passing a new credit card you must pass one of these two
      # parameters
      #
      # * <tt>email</tt> -- the email address of user associated with this
      #   purchase.
      # * <tt>account_uri</tt> -- `account_uri` is the URI of an existing
      #   Balanced account.
      def authorize(money, credit_card, options = {})
        if credit_card.respond_to?(:number)
          requires!(options, :email) unless options[:account_uri]
        end

        post = {}
        post[:amount] = money
        post[:description] = options[:description]
        add_common_params(post, options)

        create_or_find_account(post, options)
        add_credit_card(post, credit_card, options)
        add_address(credit_card, options)

        create_transaction(:post, @holds_uri, post)
      rescue Error => ex
        failed_response(ex.response)
      end

      # Perform a purchase, which is an authorization and capture in a single
      # operation.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>credit_card</tt> -- A hash of credit card details for this
      #   transaction or the URI of a card previously stored in Balanced.
      # * <tt>options</tt> -- A hash of optional parameters.
      #
      # ==== Options
      #
      # If you are passing a new credit card you must pass one of these two
      # parameters
      #
      # * <tt>email</tt> -- the email address of user associated with this
      #   purchase.
      # * <tt>account_uri</tt> -- `account_uri` is the URI of an existing
      #   Balanced account.
      #
      # If you are passing a new card URI from balanced.js, you should pass
      # the customer's name
      #
      # * <tt>name</tt> -- the customer's name, to appear on the Account
      #   on Balanced.
      def purchase(money, credit_card, options = {})
        if credit_card.respond_to?('number')
          requires!(options, :email) unless options[:account_uri]
        end

        post = {}
        post[:amount] = money
        post[:description] = options[:description]
        add_common_params(post, options)

        create_or_find_account(post, options)
        add_credit_card(post, credit_card, options)
        add_address(credit_card, options)

        create_transaction(:post, @debits_uri, post)
      rescue Error => ex
        failed_response(ex.response)
      end

      # Captures the funds from an authorized transaction (Hold).
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured as an Integer value in
      #   cents. If omitted the full amount of the original authorization
      #   transaction will be captured.
      # * <tt>authorization</tt> -- The uri of an authorization returned from
      #   an authorize request.
      #
      # ==== Options
      #
      # * <tt>description</tt> -- A string that will be displayed on the
      #   Balanced dashboard
      def capture(money, authorization, options = {})
        post = {}
        post[:hold_uri] = authorization
        post[:amount] = money if money
        post[:description] = options[:description] if options[:description]
        add_common_params(post, options)

        create_transaction(:post, @debits_uri, post)
      rescue Error => ex
        failed_response(ex.response)
      end

      # Void a previous authorization (Hold)
      #
      # ==== Parameters
      #
      # * <tt>authorization</tt> -- The uri of the authorization returned from
      #   an `authorize` request.
      def void(authorization, options = {})
        post = {}
        post[:is_void] = true
        add_common_params(post, options)

        create_transaction(:put, authorization, post)
      rescue Error => ex
        failed_response(ex.response)
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
      # * <tt>options</tt> -- A hash of parameters.
      #
      # ==== Options
      #
      # * <tt>`:amount`<tt> -- specify an amount if you want to perform a
      #   partial refund. This value will default to the total amount of the
      #   debit that has not been refunded so far.
      def refund(amount, debit_uri = "deprecated", options = {})
        if(debit_uri == "deprecated" || debit_uri.kind_of?(Hash))
          deprecated "Calling the refund method without an amount parameter is deprecated and will be removed in a future version."
          return refund(options[:amount], amount, options)
        end

        requires!(debit_uri)
        post = {}
        post[:debit_uri] = debit_uri
        post[:amount] = amount
        post[:description] = options[:description]
        add_common_params(post, options)
        create_transaction(:post, @refunds_uri, post)
      rescue Error => ex
        failed_response(ex.response)
      end

      # Stores a card and email address
      #
      # ==== Parameters
      #
      # * <tt>credit_card</tt> --
      def store(credit_card, options = {})
        requires!(options, :email)
        post = {}
        account_uri = create_or_find_account(post, options)
        if credit_card.respond_to? :number
          card_uri = add_credit_card(post, credit_card, options)
        else
          card_uri = associate_card_to_account(account_uri, credit_card)
        end

        is_test = false
        if @marketplace_uri
          is_test = (@marketplace_uri.index("TEST") ? true : false)
        end

        Response.new(true, "Card stored", {}, :test => is_test, :authorization => [card_uri, account_uri].compact.join(';'))
      rescue Error => ex
        failed_response(ex.response)
      end

      private

      # Load URIs for this marketplace by inspecting the marketplace object
      # returned from the uri. http://en.wikipedia.org/wiki/HATEOAS
      def load_marketplace
        response = http_request(:get, '/v1/marketplaces')
        if error?(response)
          raise Error.new(response, 'Invalid login credentials supplied')
        end
        response['items'][0]
      end

      def initialize_marketplace(marketplace)
        @marketplace_uri = marketplace['uri']
        @holds_uri = marketplace['holds_uri']
        @debits_uri = marketplace['debits_uri']
        @cards_uri = marketplace['cards_uri']
        @accounts_uri = marketplace['accounts_uri']
        @refunds_uri = marketplace['refunds_uri']
      end

      def create_or_find_account(post, options)
        account_uri = nil

        if options.has_key? :account_uri
          account_uri = options[:account_uri]
        end

        if account_uri == nil
          post[:name] = options[:name] if options[:name]
          post[:email_address] = options[:email]
          post[:meta] = options[:meta] if options[:meta]

          # create an account
          response = http_request(:post, @accounts_uri, post)

          if response.has_key? 'uri'
            account_uri = response['uri']
          elsif error?(response)
            # lookup account from Balanced, account_uri should be in the
            # exception in a dictionary called extras
            account_uri = response['extras']['account_uri']
            raise Error.new(response) unless account_uri
          end
        end

        post[:account_uri] = account_uri

        account_uri
      end

      def add_address(credit_card, options)
        return unless credit_card.kind_of?(Hash)
        if address = options[:billing_address] || options[:address]
          credit_card[:street_address] = address[:address1] if address[:address1]
          credit_card[:street_address] += ' ' + address[:address2] if address[:address2]
          credit_card[:postal_code] = address[:zip] if address[:zip]
          credit_card[:country] = address[:country] if address[:country]
        end
      end

      def add_common_params(post, options)
        common_params = [
          :appears_on_statement_as,
          :on_behalf_of_uri,
          :meta
        ]
        post.update(options.select{|key, _| common_params.include?(key)})
      end

      def add_credit_card(post, credit_card, options)
        if credit_card.respond_to? :number
          card = {}
          card[:card_number] = credit_card.number
          card[:expiration_month] = credit_card.month
          card[:expiration_year] = credit_card.year
          card[:security_code] = credit_card.verification_value if credit_card.verification_value?
          card[:name] = credit_card.name if credit_card.name

          add_address(card, options)

          response = http_request(:post, @cards_uri, card)
          if error?(response)
            raise CardDeclined, response
          end
          card_uri = response['uri']

          associate_card_to_account(post[:account_uri], card_uri)

          post[:card_uri] = card_uri
        elsif credit_card.kind_of?(String)
          associate_card_to_account(post[:account_uri], credit_card) unless options[:account_uri]
          post[:card_uri] = credit_card
        end

        post[:card_uri]
      end

      def associate_card_to_account(account_uri, card_uri)
        http_request(:put, account_uri, :card_uri => card_uri)
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
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def create_transaction(method, url, parameters, meta={})
        response = http_request(method, url, parameters, meta)
        success = !error?(response)

        Response.new(success,
                     (success ? "Transaction approved" : response["description"]),
                     response,
                     :test => (@marketplace_uri.index("TEST") ? true : false),
                     :authorization => response["uri"]
        )
      end

      def failed_response(response)
        is_test = false
        if @marketplace_uri
          is_test = (@marketplace_uri.index("TEST") ? true : false)
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
        msg = 'Invalid response received from the Balanced API. Please contact support@balancedpayments.com if you continue to receive this message.'
        msg += " (The raw response returned by the API was #{raw_response.inspect})"
        {
          "error" => {
            "message" => msg
          }
        }
      end

      def error?(response)
        response.key?('status_code')
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
           :lib_version => BalancedGateway::VERSION,
           :platform => RUBY_PLATFORM,
           :publisher => 'active_merchant'
        })

        {
            "Authorization" => "Basic " + Base64.encode64(@options[:login].to_s + ":").strip,
            "User-Agent" => "Balanced/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
            "X-Balanced-User-Agent" => @@ua,
        }
      end
    end
  end
end
