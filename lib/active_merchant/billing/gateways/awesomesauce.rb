module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AwesomesauceGateway < Gateway
      self.test_url = 'https://awesomesauce-staging.herokuapp.com'
      self.live_url = 'https://awesomesauce-prod.herokuapp.com'

      self.supported_countries = ['US', 'GB']
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express]

      self.homepage_url = 'https://awesomesauce-prod.herokuapp.com/'
      self.display_name = 'Awesomesauce'

      STANDARD_ERROR_CODE_MAPPING = {
        '01' => STANDARD_ERROR_CODE[:card_declined],
        '02' => STANDARD_ERROR_CODE[:invalid_number],
        '03' => STANDARD_ERROR_CODE[:expired_card],
        '10' => STANDARD_ERROR_CODE[:processing_error]
      }

      def initialize(options={})
        requires!(options, :merchant, :secret)
        super
      end

      def purchase(amount, payment, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment(post, payment)

        commit('purchase', post, options)
      end

      def authorize(amount, payment, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment(post, payment)

        commit('auth', post, options)
      end

      def capture(_amount, authorization, options={})
        post = {}
        add_auth_id(post, authorization)

        commit('capture', post, options)
      end

      def refund(_amount, authorization, options={})
        post = {}
        add_auth_id(post, authorization)

        commit('cancel', post, options)
      end

      def void(authorization, options={})
        post = {}
        add_auth_id(post, authorization)

        commit('cancel', post, options)
      end

      def verify(amount, credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(amount, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((number\D+)\d*), '\1[FILTERED]').
          gsub(%r((cv2\D+)\d*), '\1[FILTERED]').
          gsub(%r((secret\\?":\\?")\w*), '\1[FILTERED]')
      end

      private

      def add_invoice(post, amount, options)
        post[:amount] = amount(amount)
        post[:currency] = (options[:currency] || currency(amount))
      end

      def add_payment(post, payment)
        post[:number] = payment.number
        post[:cv2] = payment.verification_value
        post[:exp] = expdate(payment)
      end

      def parse(body)
        JSON.parse(body)
      end

      def add_creds(post)
        post[:merchant] = options[:merchant]
        post[:secret] = options[:secret]
      end

      def add_auth_id(post, authorization)
        post[:ref] = authorization
      end

      def commit(action, post, _options)
        add_creds(post)
        url = "#{(test? ? test_url : live_url)}/api/#{action}.json"
        response = parse(ssl_post(url, post_data(post)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response['succeeded']
      end

      def message_from(response); end

      def authorization_from(response)
        response['id']
      end

      def post_data(post)
        post.to_json
      end

      def error_code_from(response)
        response['error'] unless success_from(response)
      end
    end
  end
end
