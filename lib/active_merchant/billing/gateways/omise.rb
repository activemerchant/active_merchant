require 'active_merchant/billing/rails'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class OmiseGateway < Gateway
      API_URL     = 'https://api.omise.co/'
      VAULT_URL   = 'https://vault.omise.co/'

      STANDARD_ERROR_CODE_MAPPING = {
        'invalid_security_code' => STANDARD_ERROR_CODE[:invalid_cvc],
        'failed_capture'        => STANDARD_ERROR_CODE[:card_declined]
      }

      self.live_url = self.test_url = API_URL

      # Currency supported by Omise
      # * Thai Baht with Satang, i.e. 9000 => 90 THB
      self.default_currency = 'THB'
      self.money_format     = :cents

      #Country supported by Omise
      # * Thailand
      self.supported_countries = %w( TH )

      # Credit cards supported by Omise
      # * VISA
      # * MasterCard
      self.supported_cardtypes = [:visa, :master]

      # Omise main page
      self.homepage_url = 'https://www.omise.co/'
      self.display_name = 'Omise'

      # Creates a new OmiseGateway.
      #
      # Omise requires public_key for token creation.
      # And it requires secret_key for other transactions.
      # These keys can be found in https://dashboard.omise.co/test/api-keys
      #
      # ==== Options
      #
      # * <tt>:public_key</tt> -- Omise's public key (REQUIRED).
      # * <tt>:secret_key</tt> -- Omise's secret key (REQUIRED).

      def initialize(options={})
        requires!(options, :public_key, :secret_key)
        @public_key  = options[:public_key]
        @secret_key  = options[:secret_key]
        @api_version = options[:api_version]
        super
      end

      # Perform a purchase (with auto capture)
      #
      # ==== Parameters
      #
      # * <tt>money</tt>          -- The purchasing amount in Thai Baht Satang
      # * <tt>payment_method</tt> -- The CreditCard object
      # * <tt>options</tt>        -- An optional parameters, such as token from Omise.js
      #
      # ==== Options
      # * <tt>token_id</tt> -- token id, use Omise.js library to retrieve a token id
      # if this is passed as an option, it will ignore tokenizing via Omisevaultgateway object
      #
      # === Example
      #  To create a charge on a card
      #
      #   purchase(money, Creditcard_object)
      #
      #  To create a charge on a token
      #
      #   purchase(money, nil, { :token_id => token_id, ... })
      #
      #  To create a charge on a customer
      #
      #   purchase(money, nil, { :customer_id => customer_id })

      def purchase(money, payment_method, options={})
        create_charge(money, payment_method, options)
      end

      # Authorize a charge.
      #
      # ==== Parameters
      #
      # * <tt>money</tt>          -- The purchasing amount in Thai Baht Satang
      # * <tt>payment_method</tt> -- The CreditCard object
      # * <tt>options</tt>        -- An optional parameters, such as token or capture

      def authorize(money, payment_method, options={})
        options[:capture] = 'false'
        create_charge(money, payment_method, options)
      end

      # Capture an authorized charge.
      #
      # ==== Parameters
      #
      # * <tt>money</tt>     -- An amount in Thai Baht Satang
      # * <tt>charge_id</tt> -- The CreditCard object
      # * <tt>options</tt>   -- An optional parameters, such as token or capture

      def capture(money, charge_id, options={})
        post = {}
        add_amount(post, money, options)
        commit(:post, "charges/#{CGI.escape(charge_id)}/capture", post, options)
      end

      # Refund a charge.
      #
      # ==== Parameters
      #
      # * <tt>money</tt>     -- An amount of money to charge in Satang.
      # * <tt>charge_id</tt> -- The CreditCard object
      # * <tt>options</tt>   -- An optional parameters, such as token or capture

      def refund(money, charge_id, options={})
        options[:amount] = money if money
        commit(:post, "charges/#{CGI.escape(charge_id)}/refunds", options)
      end

      # Store a card details as customer
      #
      # ==== Parameters
      #
      # * <tt>payment_method</tt> -- The CreditCard.
      # * <tt>options</tt>        -- Optional Customer information:
      #     'email'       (A customer email)
      #     'description' (A customer description)

      def store(payment_method, options={})
        post, card_params = {}, {}
        add_customer_data(post, options)
        add_token(card_params, payment_method, options)
        commit(:post, 'customers', post.merge(card_params), options)
      end

      # Delete a customer and all associated credit cards.
      #
      # ==== Parameters
      #
      # * <tt>customer_id</tt> -- The Customer identifier (REQUIRED).

      def unstore(customer_id, options={})
        commit(:delete, "customers/#{CGI.escape(customer_id)}")
      end

      # Enable scrubbing sensitive information
      def supports_scrubbing?
        true
      end

      # Scrub sensitive information out of HTTP transcripts
      #
      # ==== Parameters
      #
      # * <tt>transcript</tt> -- The HTTP transcripts

      def scrub(transcript)
        transcript.
          gsub(/(Authorization: Basic )\w+/i, '\1[FILTERED]').
          gsub(/(\\"number\\":)\\"\d+\\"/, '\1[FILTERED]').
          gsub(/(\\"security_code\\":)\\"\d+\\"/,'\1[FILTERED]')
      end

      private

      def create_charge(money, payment_method, options)
        post = {}
        add_token(post, payment_method, options)
        add_amount(post, money, options)
        add_customer(post, options)
        post[:capture] = options[:capture] if options[:capture]
        commit(:post, 'charges', post, options)
      end

      def headers(options={})
        key = options[:key] || @secret_key
        {
          'Content-Type'    => 'application/json;utf-8',
          'Omise-Version'   => @api_version || "2014-07-27",
          'User-Agent'      => "ActiveMerchantBindings/#{ActiveMerchant::VERSION} Ruby/#{RUBY_VERSION}",
          'Authorization'   => 'Basic ' + Base64.encode64(key.to_s + ':').strip,
          'Accept-Encoding' => 'utf-8'
        }
      end

      def url_for(endpoint)
        (endpoint == 'tokens' ? VAULT_URL : API_URL) + endpoint
      end

      def post_data(parameters)
        parameters.present? ? parameters.to_json : nil
      end

      def https_request(method, endpoint, parameters=nil, options={})
        raw_response = response = nil
        begin
          raw_response = ssl_request(method, url_for(endpoint), post_data(parameters), headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = parse(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      def parse(body)
        JSON.parse(body)
      end

      def json_error(raw_response)
        msg  = "Invalid response received from Omise API. Please contact support@omise.co if you continue to receive this message."
        msg += "The raw response returned by the API was #{raw_response.inspect})"
        { message: msg }
      end

      def commit(method, endpoint, params=nil, options={})
        response = https_request(method, endpoint, params, options)
        Response.new(
          successful?(response),
          message_from(response),
          response,
          {
            authorization: authorization_from(response),
            test: test?,
            error_code: successful?(response) ? nil : standard_error_code_mapping(response)
          }
        )
      end

      def standard_error_code_mapping(response)
        STANDARD_ERROR_CODE_MAPPING[error_code_from(response)] || message_to_standard_error_code_from(response)
      end

      def error_code_from(response)
        error?(response) ? response['code'] : response['failure_code']
      end

      def message_to_standard_error_code_from(response)
        message = response['message'] if response['code'] == 'invalid_card'
        case message
          when /brand not supported/
            STANDARD_ERROR_CODE[:invalid_number]
          when /number is invalid/
            STANDARD_ERROR_CODE[:incorrect_number]
          when /expiration date cannot be in the past/
            STANDARD_ERROR_CODE[:expired_card]
          when /expiration \w+ is invalid/
            STANDARD_ERROR_CODE[:invalid_expiry_date]
          else
            STANDARD_ERROR_CODE[:processing_error]
        end
      end

      def message_from(response)
        if successful?(response)
          'Success'
        else
          (response['message'] ? response['message'] : response['failure_message'])
        end
      end

      def authorization_from(response)
        response['id'] if successful?(response)
      end

      def successful?(response)
        !error?(response) && response['failure_code'].nil?
      end

      def error?(response)
        response.key?('object') && (response['object'] == 'error')
      end

      def get_token(post, credit_card)
        add_creditcard(post, credit_card) if credit_card
        commit(:post, 'tokens', post, { key: @public_key })
      end

      def add_token(post, credit_card, options={})
        if options[:token_id].present?
          post[:card] = options[:token_id]
        else
          response = get_token(post, credit_card)
          response.authorization ? (post[:card] = response.authorization) : response
        end
      end

      def add_creditcard(post, payment_method)
        card = {
          number:           payment_method.number,
          name:             payment_method.name,
          security_code:    payment_method.verification_value,
          expiration_month: payment_method.month,
          expiration_year:  payment_method.year
        }
        post[:card] = card
      end

      def add_customer(post, options={})
        post[:customer] = options[:customer_id] if options[:customer_id]
      end

      def add_customer_data(post, options={})
        post[:description] = options[:description] if options[:description]
        post[:email]       = options[:email] if options[:email]
      end

      def add_amount(post, money, options)
        post[:amount]      = amount(money)
        post[:currency]    = (options[:currency] || currency(money))
        post[:description] = options[:description] if options.key?(:description)
      end

    end
  end
end
