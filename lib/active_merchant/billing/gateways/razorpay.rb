module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class RazorpayGateway < Gateway
      self.test_url = 'https://api.razorpay.com/v1'
      self.live_url = 'https://api.razorpay.com/v1'
      self.supported_countries = ['IN']
      self.default_currency = 'INR'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://razorpay/'
      self.display_name = 'Razorpay'
      self.money_format = :cents

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :key_id, :key_secret)
        super
      end

      def purchase(money, payment_id, options={})
        capture(money, payment_id, options)
      end

      def authorize(money, payment_id, options={})
        commit(:get, "/payments/#{payment_id}", {})
      end

      def capture(money, payment_id, options={})
        post = {}
        add_amount(post, money)
        commit(:post, "/payments/#{payment_id}/capture", post)
      end

      def refund(money, payment_id, options={})
        commit(:post,"/payments/#{payment_id}/refund", {})
      end

      def void(authorization, options={})
        Response.new(true, 'Razorpay does not support void api')
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, money, options)
        post[:currency] = (options[:currency] || currency(money))
        post[:method] = 'card'
        post[:contact] = options[:phone]
        post[:email] = options[:email]
      end

      def add_amount(post, money)
        post[:amount] = amount(money)
      end


      def add_credit_card(post, payment)
        post[:card] = {
          number: payment.number,
          cvv: payment.verification_value,
          name: "#{payment.first_name} #{payment.last_name}",
          expiry_month: payment.month,
          expiry_year: payment.year,
        }
      end

      def add_payment(post, payment)
      end

      def parse(body)
        JSON.parse(body)
      end

      def api_request(method, endpoint, parameters = nil, body = nil)
        raw_response = ssl_request(method, "#{endpoint}?#{post_data(parameters)}", body, headers)
        parse(raw_response)
      end

      def headers
        {
          'Content-Type' => 'application/x-www-form-urlencoded; charset=utf-8',
          'Authorization' => 'Basic ' + Base64.strict_encode64("#{@options[:key_id]}:#{@options[:key_secret]}").strip
        }
      end

      def commit(method, path, parameters)

        url = (test? ? test_url : live_url)
        response = api_request(method, "#{url}#{path}", parameters)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: {conde: 'Y'},
          cvv_result: 'M',
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response['error_code'].nil?
      end

      def message_from(response)
        if success_from(response)
          'OK'
        end
      end

      def authorization_from(response)
        response['id']
      end

      def post_data(params)
        return nil unless params

        params.map do |key, value|
          next if value != false && value.blank?
          if value.is_a?(Hash)
            h = {}
            value.each do |k, v|
              h["#{key}[#{k}]"] = v unless v.blank?
            end
            post_data(h)
          elsif value.is_a?(Array)
            value.map { |v| "#{key}[]=#{CGI.escape(v.to_s)}" }.join("&")
          else
            "#{key}=#{CGI.escape(value.to_s)}"
          end
        end.compact.join("&")
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
          response['error_description']
        end
      end
    end
  end
end
