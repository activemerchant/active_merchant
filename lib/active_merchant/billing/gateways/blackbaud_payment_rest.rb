module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BlackbaudPaymentRestGateway < Gateway
      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.live_url = 'https://api.sky.blackbaud.com/payments/v1'
      self.homepage_url = 'http://www.blackbaud.com/'
      self.display_name = 'Blackbaud BBPS'

      def initialize(options = {})
        super
        requires!(options, :api_key)
        requires!(options, :api_token)
        requires!(options, :merchant_id)
        @api_key = options[:api_key]
        @api_token = options[:api_token]
        @merchant_id = options[:merchant_id]
      end

      def headers(options = {})
        {
          'X-Accepts' => 'application/json',
          'Content-Type' => 'application/json',
          'User-Agent' => "ActiveMerchant/#{ActiveMerchant::VERSION}",
          'X-Client-IP' => options[:ip] || '',
          'Bb-Api-Subscription-Key' => @api_key || options[:api_key],
          'Authorization' => "Bearer #{@api_token || options[:api_token]}",
        }
      end

      def store(payment_method, options={})
        post = {}

        if payment_method.is_a?(Check)
          add_debit(post, payment_method)
          endpoint = '/directdebitaccounttokens'
          
        elsif payment_method.is_a?(CreditCard)
          add_credit(post, payment_method)
          endpoint = '/cardtokens'
        end

        commit(:post, endpoint, post, options)
      end

      # Create a charge using a credit card, card token or customer token
      #
      # To charge a credit card: purchase([money], [creditcard hash], ...)
      # To charge a customer, payment_source or vault_token: purchase([money], [authorization], ...)
      #
      def purchase(money, payment, options = {})
        post = {}

        post[:payment_configuration_id] = @merchant_id
        post[:amount] = amount(money).to_s

        post[:transaction_id] = options[:transaction_id]        
        post[:email] = options[:email]
        post[:phone] = options[:phone]
        post[:comment] = options[:comment]

        add_payment(post, payment, options)
        add_billing_contact(post, options)

        commit(:post, '/transactions', post, options)
      end

      def commit(verb, endpoint, data = nil, options = {})
        begin
          raw_response = ssl_request(verb, live_url + endpoint, data.to_json, headers(options))
          response = raw_response.is_a?(Hash) ? raw_response : JSON.parse(raw_response)
        rescue ActiveMerchant::ResponseError => e
          response = JSON.parse(e.response.body)
          response = response.first if response.is_a?(Array)
        end
        response.deep_symbolize_keys! if response.is_a?(Hash)
        succeeded = success_from(endpoint, response)

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(succeeded, endpoint, response),
          error_code: error_code_from(succeeded, response),
          test: test?
        )
      end

      def success_from(action, response)
        case action
        when '/cardtokens'
          response.key?(:card_token)
        when '/directdebitaccounttokens'
          response.key?(:direct_debit_account_token)
        when '/transactions'
          response.key?(:id)
        else
          response.key?(:id)
        end
      end

      def authorization_from(succeeded, action, response)
        if succeeded
          case action
          when '/cardtokens'
            response[:card_token]
          when '/directdebitaccounttokens'
            response[:direct_debit_account_token]
          when '/transactions'
            response[:id]
          else
            response[:id]
          end
        end
      end

      def message_from(succeeded, response)
        if succeeded
          response[:id]
        else
          error_code_from(succeeded, response)
        end
      end

      def error_code_from(succeeded, response)
        unless succeeded
          response[:message] || response[:statusCode]
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(Authorization: Bearer )([A-Za-z0-9\-\._~\+\/]+=*)/, '\1[FILTERED]').
          gsub(/(payment_configuration_id\\?\\?\\?":\\?\\?\\?")(\b[0-9a-f]{8}\b-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-\b[0-9a-f]{12}\b)/, '\1[FILTERED]').
          gsub(/(Bb-Api-Subscription-Key:\s)(\b[0-9a-f]+)/, '\1[FILTERED]').
          gsub(/(credit_card\\?\\?\\?":{.+\\?\\?\\?"number\\?\\?\\?":\\?\\?\\?")\d+/, '\1[FILTERED]').
          gsub(/(\\?\\?\\?"csc\\?\\?\\?":\\?\\?\\?")\d+/, '\1[FILTERED]')
      end

      def add_billing_contact(post, options)
        billing_contact = {
          first_name: options[:first_name],
          last_name: options[:last_name],
          address: options[:address][:address1],
          city: options[:address][:city],
          state: options[:address][:state],
          country: options[:address][:country],
          post_code: options[:address][:zip],
        }

        post[:billing_contact] = billing_contact
      end

      def add_credit(post, credit_card)
        post[:exp_month] = credit_card.month
        post[:exp_year] = credit_card.year
        post[:name] = credit_card.name
        post[:number] = credit_card.number
      end

      def add_debit(post, check)
        post[:direct_debit_account_info] = {
          account_number: check.account_number.gsub(/\D/, ''),
          routing_number: check.routing_number.gsub(/\D/, ''),
          account_holder: "#{check.first_name} #{check.last_name}",
          check_number: check.number,
          account_type: check.account_type
        }
      end

      def add_payment(post, payment, options)
        if payment.is_a?(CreditCard)
          credit_card = {}
          add_credit(credit_card, payment)
          post[:credit_card] = credit_card
          post[:csc] = options[:csc] || payment.verification_value

        elsif payment.is_a?(Check)
          add_debit(post, payment)

        else
          if options.key?(:card_token)
            post[:card_token] = options[:card_token]
            post[:csc] = options[:csc]
          elsif options.key?(:direct_debit_account_token)
            post[:direct_debit_account_token] = options[:direct_debit_account_token]
          else
            post[:card_present] = { swipe_data: options[:swipe_data] }
          end
        end
      end
    end
  end
end
