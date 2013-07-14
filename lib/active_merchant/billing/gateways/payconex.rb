module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayconexGateway < Gateway

      self.test_url = 'https://cert.payconex.net/api/qsapi/3.7/'
      self.live_url = 'https://secure.payconex.net/api/qsapi/3.7/'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.payconex.com/'
      self.display_name = 'PayConex Gateway'
      self.default_currency = 'USD'

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def authorize(money, payment_object, options = {})
        post = {}
        add_payment_method(post, payment_object, options)
        add_address(post, options)
        add_extra_data(post, options)
        add_customer_data(post, options)

        commit('AUTHORIZATION', money, post)
      end

      def force(money, authorization_code, payment_object, options = {})
        post = {}
        add_payment_method(post, payment_object, options)
        add_address(post, options)
        add_extra_data(post, options)
        add_customer_data(post, options)
        post[:authorization_code] = authorization_code

        commit('FORCE', money, post)
      end

      def store(payment_object, options = {})
        post = {}
        add_payment_method(post, payment_object, options)
        add_address(post, options)
        add_extra_data(post, options)
        add_customer_data(post, options)

        commit('STORE', 0, post)
      end

      def purchase(money, payment_object, options = {})
        post = {}
        add_payment_method(post, payment_object, options)
        add_address(post, options)
        add_extra_data(post, options)
        add_customer_data(post, options)

        commit('SALE', money, post)
      end

      def capture(money, token, options = {})
        post = {}
        add_customer_data(post, options)
        add_token(post, token)

        commit('CAPTURE', money, post)
      end

      def refund(money, token, options = {})
        post = {}
        add_token(post, token)
        add_address(post, options)
        add_extra_data(post, options)
        add_customer_data(post, options)

        commit('REFUND', money, post)
      end

      def credit(money, payment_object, options = {})
        post = {}
        add_payment_method(post, payment_object, options)
        add_address(post, options)
        add_extra_data(post, options)
        add_customer_data(post, options)

        commit('CREDIT', money, post)
      end

      ACH_ACCOUNT_TYPES = {
        'checking' => 'CHECKING',
        'savings' => 'SAVINGS'
      }

      private

      def add_customer_data(post, options)
        post[:account_id] = @options[:login]
        post[:api_accesskey] = @options[:password]
        post[:response_format] = 'JSON'
      end

      def add_token(post, token)
        post[:token_id] = token
      end

      def add_address(post, options)
        post[:street_address1] = options[:billing_address][:address1]
        post[:street_address2] = options[:billing_address][:address2]
        post[:city] = options[:billing_address][:city]
        post[:state] = options[:billing_address][:state]
        post[:zip] = options[:billing_address][:zip]
        post[:country] = options[:billing_address][:country]
        post[:phone] = options[:billing_address][:phone]
        post[:email] = options[:email]
      end

      def add_extra_data(post, options)
        post[:transaction_description] = options[:description]
        post[:custom_id] = options[:custom_id]
        post[:custom_data] = options[:custom_data]
        post[:group] = options[:group]
        post[:cashier] = options[:cashier]

        post[:disable_avs] = options[:disable_avs] if options.include?(:disable_avs)
        post[:disable_cvv] = options[:disable_cvv] if options.include?(:disable_cvv)
        post[:disable_fraudfirewall] = options[:disable_fraudfirewall] if options.include?(:disable_fraudfirewall)
        post[:ach_sec_code] = options[:ach_sec_code]
        post[:ach_opcode] = options[:ach_opcode]
        post[:ip_address] = options[:ip_address]
        post[:send_customer_receipt] = options[:send_customer_receipt] if options.include?(:send_customer_receipt)
        post[:send_merchant_receipt] = options[:send_merchant_receipt] if options.include?(:send_merchant_receipt)
      end

      def add_creditcard(post, creditcard)
        post[:tender_type] = 'CARD'
        if creditcard.respond_to?(:track_data) && creditcard.track_data.present?
          post[:card_tracks] = creditcard.track_data
        else
          post[:card_number] = creditcard.number
          post[:first_name] = creditcard.first_name
          post[:last_name] = creditcard.last_name
          post[:card_expiration] = "#{sprintf('%02d', creditcard.month)}#{"#{creditcard.year}"[-2, 2]}"
          post[:card_verification] = creditcard.verification_value
        end
      end

      def add_bank_account(post, bank_account)
        post[:tender_type] = 'ACH'
        post[:bank_account_number] = bank_account.account_number
        post[:bank_routing_number] = bank_account.routing_number
        post[:first_name] = bank_account.first_name
        post[:last_name] = bank_account.last_name
        post[:ach_account_type] = ACH_ACCOUNT_TYPES[bank_account.account_type]
      end

      def add_check_number(post, check_number)
        post[:check_number] = check_number
      end

      def add_payment_method(post, payment_object, options)
        case payment_object
        when String
          add_token(post, payment_object)
          post[:reissue] = true
        when Check
          add_bank_account(post, payment_object)
          add_check_number(post, options[:check_number])
        else
          add_creditcard(post, payment_object)
        end
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, money, parameters)
        parameters[:transaction_type] = action

        # Convert cents to dollars
        parameters[:transaction_amount] = amount(money)

        post_parameters = {}
        post_parameters[:request_format] = 'JSON'
        post_parameters[:params] = JSON.generate(parameters)

        raw_response = ssl_post(test? ? self.test_url : self.live_url, post_data(post_parameters))
        begin
          response = parse(raw_response)
        rescue JSON::ParserError
          # response = json_error(raw_response)
          response = raw_response
        end

        Response.new(success?(response),
                     response['error'] ? response['error_message'] : response['authorization_message'],
                     response,
                     :test => test?,
                     :authorization => response['authorization_code'])
      end

      def success?(response)
        (!response['error'])
      end

      def post_data(parameters = {})
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
      end
    end
  end
end

