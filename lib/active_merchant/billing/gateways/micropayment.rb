module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MicropaymentGateway < Gateway
      self.display_name = 'micropayment'
      self.homepage_url = 'https://www.micropayment.de/'

      self.test_url = self.live_url = 'https://sipg.micropayment.de/public/creditcardpsp/v1/nvp/'

      self.supported_countries = %w(DE)
      self.default_currency = 'EUR'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master american_express]

      def initialize(options={})
        requires!(options, :access_key)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_address(post, options)
        commit('purchase', post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_address(post, options)
        commit('authorize', post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_reference(post, authorization)
        add_invoice(post, amount, options)
        commit('capture', post)
      end

      def void(authorization, options={})
        post = {}
        add_reference(post, authorization)
        commit('void', post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_reference(post, authorization)
        add_invoice(post, amount, options)
        commit('refund', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(250, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((accessKey=)\w+), '\1[FILTERED]').
          gsub(%r((number=)\d+), '\1[FILTERED]').
          gsub(%r((cvc2=)\d+), '\1[FILTERED]')
      end

      private

      def add_invoice(post, money, options)
        if money
          post[:amount] = amount(money)
          post[:currency] = options[:currency] || currency(money)
        end
        post[:project] = options[:project] if options[:project]
        post['params[title]'] = options[:description] if options[:description]
      end

      def add_payment_method(post, payment_method, options={})
        post[:number] = payment_method.number
        post[:recurring] = 1 if options[:recurring] == true
        post[:cvc2] = payment_method.verification_value
        post[:expiryYear] = format(payment_method.year, :four_digits)
        post[:expiryMonth] = format(payment_method.month, :two_digits)

        post['params[firstname]'] = payment_method.first_name
        post['params[surname]'] = payment_method.last_name
      end

      def add_customer_data(post, options)
        post['params[email]'] = options[:email] if options[:email]
        post['params[ip]'] = options[:ip] || '1.1.1.1'
        post['params[sendMail]'] = options[:send_mail] || 'false'
      end

      def add_address(post, options)
        address = options[:billing_address]
        return unless address

        post['params[address]'] = address[:address1] if address[:address1]
        post['params[zipcode]'] = address[:zip] if address[:zip]
        post['params[town]'] = address[:city] if address[:city]
        post['params[country]'] = address[:country] if address[:country]
      end

      def add_reference(post, authorization)
        session_id, transaction_id = split_authorization(authorization)
        post[:sessionId] = session_id
        post[:transactionId] = transaction_id
      end

      def commit(action, params)
        params[:testMode] = 1 if test?
        params[:accessKey] = @options[:access_key]
        params[:apiKey] = @options[:api_key] || 'af1fd841af792f4c50131414ff76e004'

        response = parse(ssl_post(url(action), post_data(action, params), headers))

        Response.new(
          succeeded = success_from(response),
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response, params),
          avs_result: AVSResult.new(code: response['some_avs_result_key']),
          cvv_result: CVVResult.new(response['some_cvv_result_key']),
          test: test?
        )
      end

      def headers
        { 'Content-Type' => 'application/x-www-form-urlencoded;charset=UTF-8' }
      end

      def post_data(action, params)
        params.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def url(action)
        action_url = test? ? test_url : live_url
        "#{action_url}?action=#{action}"
      end

      def parse(body)
        body.split(/\r?\n/).inject({}) do |acc, pair|
          key, value = pair.split('=')
          acc[key] = CGI.unescape(value)
          acc
        end
      end

      def success_from(response)
        response['error'] == '0' &&
          response['transactionResultCode'] == '00' &&
          response['transactionStatus'] == 'SUCCESS'
      end

      def message_from(succeeded, response)
        if succeeded
          'Succeeded'
        else
          response['errorMessage'] || response['transactionResultMessage']
        end
      end

      def split_authorization(authorization)
        authorization.split('|')
      end

      def authorization_from(response, request_params)
        session_id = response['sessionId'] || request_params[:sessionId]
        "#{session_id}|#{response['transactionId']}"
      end
    end
  end
end
