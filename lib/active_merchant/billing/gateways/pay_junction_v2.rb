module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayJunctionV2Gateway < Gateway
      self.display_name = 'PayJunction'
      self.homepage_url = 'https://www.payjunction.com/'

      self.test_url = 'https://api.payjunctionlabs.com/transactions'
      self.live_url = 'https://api.payjunction.com/transactions'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      def initialize(options={})
        requires!(options, :api_login, :api_password, :api_key)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_address(post, options)

        commit('purchase', post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        post[:status] = 'HOLD'
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_address(post, options)

        commit('authorize', post)
      end

      def capture(amount, authorization, options={})
        post = {}
        post[:status] = 'CAPTURE'
        post[:transactionId] = authorization
        add_invoice(post, amount, options)

        commit('capture', post)
      end

      def void(authorization, options={})
        post = {}
        post[:status] = 'VOID'
        post[:transactionId] = authorization

        commit('void', post)
      end

      def refund(amount, authorization, options={})
        post = {}
        post[:action] = 'REFUND'
        post[:transactionId] = authorization
        add_invoice(post, amount, options)

        commit('refund', post)
      end

      def credit(amount, payment_method, options={})
        post = {}
        post[:action] = 'REFUND'
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)

        commit('credit', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(payment_method, options = {})
        verify(payment_method, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((X-Pj-Application-Key: )[\w-]+), '\1[FILTERED]').
          gsub(%r((cardNumber=)\d+), '\1[FILTERED]').
          gsub(%r((cardCvv=)\d+), '\1[FILTERED]')
      end

      private

      def add_invoice(post, money, options)
        post[:amountBase] = amount(money) if money
        post[:invoiceNumber] = options[:order_id] if options[:order_id]
      end

      def add_payment_method(post, payment_method)
        if payment_method.is_a? Integer
          post[:transactionId] = payment_method
        else
          post[:cardNumber] = payment_method.number
          post[:cardExpMonth] = format(payment_method.month, :two_digits)
          post[:cardExpYear] = format(payment_method.year, :four_digits)
          post[:cardCvv] = payment_method.verification_value
        end
      end

      def add_address(post, options)
        if address = options[:billing_address]
          post[:billingFirstName] = address[:first_name] if address[:first_name]
          post[:billingLastName] = address[:last_name] if address[:last_name]
          post[:billingCompanyName] = address[:company] if address[:company]
          post[:billingPhone] = address[:phone_number] if address[:phone_number]
          post[:billingAddress] = address[:address1] if address[:address1]
          post[:billingCity] = address[:city] if address[:city]
          post[:billingState] = address[:state] if address[:state]
          post[:billingCountry] = address[:country] if address[:country]
          post[:billingZip] = address[:zip] if address[:zip]
        end
      end

      def commit(action, params)
        response =
          begin
            parse(ssl_invoke(action, params))
          rescue ResponseError => e
            parse(e.response.body)
          end

        success = success_from(response)
        Response.new(
          success,
          message_from(response),
          response,
          authorization: success ? authorization_from(response) : nil,
          error_code: success ? nil : error_from(response),
          test: test?
        )
      end

      def ssl_invoke(action, params)
        if ['purchase', 'authorize', 'refund', 'credit'].include?(action)
          ssl_post(url(), post_data(params), headers)
        else
          ssl_request(:put, url(params), post_data(params), headers)
        end
      end

      def headers
        {
          'Authorization' => 'Basic ' + Base64.encode64("#{@options[:api_login]}:#{@options[:api_password]}").strip,
          'Content-Type'  => 'application/x-www-form-urlencoded;charset=UTF-8',
          'Accept' => 'application/json',
          'X-PJ-Application-Key' => @options[:api_key].to_s
        }
      end

      def post_data(params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def url(params={})
        test? ? "#{test_url}/#{params[:transactionId]}" : "#{live_url}/#{params[:transactionId]}"
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        message = 'Invalid JSON response received from PayJunctionV2Gateway. Please contact PayJunctionV2Gateway if you continue to receive this message.'
        message += " (The raw response returned by the API was #{body.inspect})"
        {
          'errors' => [{
            'message' => message
          }]
        }
      end

      def success_from(response)
        return response['response']['approved'] if response['response']

        false
      end

      def message_from(response)
        return response['response']['message'] if response['response']

        response['errors']&.inject('') { |message, error| error['message'] + '|' + message }
      end

      def authorization_from(response)
        response['transactionId']
      end

      def error_from(response)
        response['response']['code'] if response['response']
      end
    end
  end
end
