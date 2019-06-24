# PayDock API - https://docs.paydock.com/
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaydockGateway < Gateway
      self.test_url = 'https://api-sandbox.paydock.com/v1/'
      self.live_url = 'https://api.paydock.com/v1/'

      self.default_currency = 'AUD'
      self.money_format = :dollars
      self.supported_countries = ['AU', 'NZ', 'GB', 'US', 'CA']
      self.supported_cardtypes = [:visa, :master, :american_express]

      self.homepage_url = 'https://paydock.com/'
      self.display_name = 'PayDock'

      AUTHORIZATION_MAP = {
        charge_id: 'h',
        customer_id: 'u',
        gateway_id: 'g',
        payment_source_id: 's',
        vault_token: 'v',
        first_name: 'f',
        last_name: 'l',
        email: 'e',
        customer_reference: 'r',
        charge_reference: 't',
        external_id: 'x'
      }

      # Merge with custom error code for this gateway
      STANDARD_ERROR_CODE_MAPPING = Gateway::STANDARD_ERROR_CODE.merge({})

      def initialize(options = {})
        super
        requires!(options, :login)
        requires!(options, :password)
        @gateway_id = options[:login]
        @secret_key = options[:password]
      end

      # Create a vault_token or payment_source
      def store(credit_card, options = {})
        options.deep_symbolize_keys!
        post = {}
        auth = { credit_card: credit_card }

        if options[:customer] || options[:customer_id] || options[:customer_from]
          add_customer(post, auth, options)
          add_gateway(post, options)
          add_credit_card(post[:customer][:payment_source], credit_card)

          endpoint = post[:customer_id] ? 'customers/' + post[:customer_id] : 'customers'
          post = post[:customer] # pull customer object up to root and drop everything else
        else
          endpoint = 'vault/payment_sources'
          options[:credit_card] = credit_card
          add_credit_card(post, credit_card)
        end

        commit(:post, endpoint, post, options)
      end

      # delete a vault_token or payment_source or customer
      def unstore(authorization, options = {})
        options.deep_symbolize_keys!
        auth = authorization_parse(authorization)

        if (auth[:vault_token])
          commit(:delete, 'vault-tokens/' + auth[:vault_token], nil, options)
        end
      end

      # Authorize an amount on a credit card or vault token.
      # Once authorized, you can later capture this charge using the charge_id
      # returned.
      #
      def authorize(money, authorization, options = {})
        purchase(money, authorization, options.merge({ capture: false }))
      end

      # Create a charge using a credit card, card token or customer token
      #
      # To charge a credit card: purchase([money], [creditcard hash], ...)
      # To charge a customer, payment_source or vault_token: purchase([money], [authorization], ...)
      #
      def purchase(money, authorization, options = {})
        options.deep_symbolize_keys!
        auth = authorization_parse(authorization)

        post = {}
        post[:capture] = options[:capture] if options.has_key?(:capture)

        add_amount(post, money, options)
        add_reference(post, options)
        add_customer(post, auth, options)
        add_payment_source(post, auth, options)
        if auth[:credit_card]
          add_credit_card(post[:customer][:payment_source], auth[:credit_card])
        end

        if post[:payment_source_id]
          post.except![:customer]
          post.except![:customer_id]
        end

        if post[:customer_id]
          post.except![:customer]
        end

        if !post[:customer_id] && !post[:payment_source_id]
          if auth.has_key?(:vault_token)
            add_vault_token(post, auth)
          end
          add_gateway(post, options)
        end

        commit(:post, 'charges', post, options)
      end

      def capture(amount, authorization, options = {})
        options.deep_symbolize_keys!
        auth = authorization_parse(authorization)
        post = {}
        add_amount(post, amount, options)
        if (auth[:charge_id])
          commit(:post, 'charges/' + auth[:charge_id] + '/capture', post, options)
        else
          Response.new(false, "Invalid charge_id in authorization for capture")
        end
      end

      def refund(amount, authorization, options = {})
        options.deep_symbolize_keys!
        auth = authorization_parse(authorization)
        post = {}
        add_amount(post, amount, options)
        charge_id = auth[:charge_id] || ''
        commit(:post, 'charges/' + charge_id + '/refunds', post, options)
      end

      # create an authorization token using given parameters
      def authorization_create(params)
        auth = {}
        params.each_key { |key| auth[AUTHORIZATION_MAP[key]] = params[key] if AUTHORIZATION_MAP[key] }
        auth.to_param
      end

      # parse an authorization token and get parameters
      def authorization_parse(authorization)
        if authorization.is_a? String
          Hash[CGI::parse(authorization).map { |k, v| [AUTHORIZATION_MAP.invert[k], v.first] }]
        elsif authorization.instance_of? CreditCard
          { credit_card: authorization }
        else
          {}
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((X-User-Secret-Key: )\w+), '\1[FILTERED]').
          gsub(/(card_number\\?":\\?")\d*/, '\1[FILTERED]').
          gsub(/(card_ccv\\?":\\?")\d*/, '\1[FILTERED]').
          gsub(/(gateway_id\\?":\\?")\w*/, '\1[FILTERED]')
      end

      private

      def add_amount(post, money, options)
        post[:amount] = amount(money).to_s
        post[:currency] = (options[:currency] || currency(money)).try(:upcase)
      end

      def add_gateway(post, options)
        post[:customer] ||= {}
        post[:customer][:payment_source] ||= {}
        post[:customer][:payment_source][:gateway_id] = options[:gateway_id] || @gateway_id
      end

      def add_customer(post, auth, options = {})
        customer = options[:customer] ? options[:customer].clone : {}

        # get customer_id provided
        customer_id = nil
        if options[:customer]
          customer_id = options[:customer][:id] || options[:customer][:_id]
        end
        customer_id = post[:customer_id] if post[:customer_id]

        # get name from credit card
        if auth.has_key?(:credit_card)
          customer[:first_name] = auth[:credit_card].first_name
          customer[:last_name] = auth[:credit_card].last_name
        end

        # change authentication object if customer_from option set
        auth = authorization_parse(options[:customer_from]) if options[:customer_from]

        # get customer from authentication token
        customer_id = auth[:customer_id] if auth[:customer_id]
        customer[:first_name] = auth[:first_name] if auth[:first_name]
        customer[:last_name] = auth[:last_name] if auth[:last_name]
        customer[:email] = auth[:email] if auth[:email]
        customer[:reference] = auth[:customer_reference] if auth[:customer_reference]

        # overwrite with original options
        if (options[:customer])
          opt = options[:customer].except(:_id)
          customer = customer.merge(opt)
        end

        # add customer to post
        post[:customer] = customer
        post[:customer_id] = post[:customer][:_id] = customer_id if customer_id
      end

      def add_payment_source(post, auth, options = {}, payment_source = {})
        if auth[:payment_source_id]
          post[:payment_source_id] = auth[:payment_source_id]
        else
          post[:customer] ||= {}
          post[:customer][:payment_source] ||= {}
          post[:customer][:payment_source].merge(payment_source)
        end
      end

      def add_reference(post, options)
        post[:reference] = options[:reference] if options[:reference]
        post[:description] = options[:description] if options[:description]
      end

      def add_vault_token(post, auth)
        if auth[:vault_token]
          post[:customer] ||= {}
          post[:customer][:payment_source] ||= {}
          post[:customer][:payment_source][:vault_token] = auth[:vault_token]
        end
      end

      def add_credit_card(post, credit_card)
        if credit_card && credit_card.instance_of?(CreditCard)
          post[:card_name] = credit_card.name if credit_card.name
          post[:card_number] = credit_card.number if credit_card.number
          post[:card_ccv] = credit_card.verification_value if credit_card.verification_value
          post[:expire_month] = credit_card.month if credit_card.month
          post[:expire_year] = credit_card.year if credit_card.year
        end
      end

      def authorization_from(verb, method, response, options = {})
        if success_from(response)
          type = response['resource']['type']
          data = response['resource']['data']
          param = {}

          charge = type == 'charge' ? data : nil
          customer = type == 'customer' ? data : nil
          source = type == 'payment_source' ? data : nil

          # get customer from response
          if charge && charge['customer']
            customer = charge['customer']
          end

          # get payment source from response
          if customer && customer['payment_source']
            source = customer['payment_source']
          elsif  customer && customer['payment_sources']
            source = customer['payment_sources'].pop
          end

          # get first name and last from credit card
          if options[:credit_card]
            card = options[:credit_card]
            param[:first_name] = card.first_name if card.first_name
            param[:last_name] = card.last_name if card.last_name
          end

          # get info from charge object
          if charge
            param[:charge_id] = charge['_id'] if charge['_id']
            param[:external_id] = charge['external_id'] if charge['external_id']
            param[:charge_reference] = charge['reference'] if charge['reference']
            param[:customer_id] = charge['customer_id'] if charge['customer_id']
          end

          # get info form customer object
          if customer
            param[:customer_id] = customer['customer_id'] if customer['customer_id']
            param[:customer_id] = customer['_id'] if customer['_id']
            param[:customer_reference] = customer['reference'] if customer['reference']
            param[:first_name] = customer['first_name'] if customer['first_name']
            param[:last_name] = customer['last_name'] if customer['last_name']
            param[:email] = customer['email'] if customer['email']
          end

          # get info from payment_source object
          if source
            param[:vault_token] = source['vault_token'] if source['vault_token']
            param[:payment_source_id] = source['_id'] if source['_id']
            param[:gateway_id] = source['gateway_id'] if source['gateway_id']
          end

          authorization_create(param)
        end
      end

      def headers(options = {})
        {
          'X-Accepts' => 'application/json',
          'Content-Type' => 'application/json',
          'User-Agent' => "ActiveMerchant/#{ActiveMerchant::VERSION}",
          'X-Client-IP' => options[:ip] || '',
          'X-User-Secret-Key' => options[:secret_key] || @secret_key
        }
      end

      def commit(verb, endpoint, data = nil, options = {})
        begin
          raw = ssl_request(verb, url + endpoint, json_data(data), headers(options))
          response = JSON.parse(raw)
        rescue ResponseError => e
          response = JSON.parse(e.response.body)
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          :test => test?,
          :authorization => authorization_from(endpoint, verb, response, options),
          :error_code => error_code_from(response))
      end

      def error_code_from(response)
        unless success_from(response)
          return STANDARD_ERROR_CODE_MAPPING[:processing_error] unless response['error']

          code = response.dig('error', 'code') || response.dig('error', 'details', 0, 'gateway_specific_code')
          decline_code = response.dig('error', 'decline_code').try(:to_sym) if code == 'card_declined'

          STANDARD_ERROR_CODE_MAPPING[decline_code] || STANDARD_ERROR_CODE_MAPPING[code.to_sym] || code
        end
      end

      def json_data(data)
        data.is_a?(String) ? data : data.to_json
      end

      def message_from(response)
        success = success_from(response)

        success ? 'Succeeded' : response.dig('error', 'message') || 'No error details'
      end

      def success_from(response)
        (response && response['error'].blank?) && (200..300).cover?(response['status'])
      end

      def url
        test? ? test_url : live_url
      end
    end
  end
end
