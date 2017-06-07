module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MxMerchantGateway < Gateway
      self.test_url = 'https://example.com/test'
      self.live_url = 'https://example.com/live'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.mxmerchant.com/'
      self.display_name = 'MX Merchant'

      MERCHANT_ID = "-205988"

      STANDARD_ERROR_CODE_MAPPING = {}

      self.test_url = 'https://sandbox.api.mxmerchant.com/checkout/v3/payment'
#      self.test_url = 'https://sandbox.api.mxmerchant.com/checkout/v3/payment?echo=true'
      self.live_url = 'https://example.com/live'

      def initialize(options={})
        requires!(options, :username, :password)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('purchase', post)
      end

# Not implemented, yet. -mab 2015-11-01
#       def authorize(money, payment, options={})
#         post = {}
#         add_invoice(post, money, options)
#         add_payment(post, payment)
#         add_address(post, payment, options)
#         add_customer_data(post, options)
# 
#         commit('authonly', post)
#       end
# 
# Not implemented, yet. -mab 2015-11-01
#       def capture(money, authorization, options={})
#         commit('capture', post)
#       end

      def refund(money, payment, options={})
        post = {}
        add_invoice(post, 0-money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('purchase', post)
      end

# Not implemented, yet. -mab 2015-11-01
#       def void(authorization, options={})
#         commit('void', post)
#       end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        false
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
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
        post["tenderType"] = "Card" # ZZZ: Hard-code??? Really???? -mab 2015-10-28
        card_account = {
          "number" => payment.number,
          "expiryMonth" => payment.month,
          "expiryYear" => payment.year,
          "cvv" => payment.verification_value,
        }
        post["cardAccount"] = card_account
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        parameters["merchantId"] = MERCHANT_ID  # ZZZ: This should be easily placed in a more proper place, somewhere. -mab 2015-11-01

        if action == "void"
          response = parse(joe)
        else
          # original...
          # response = parse(ssl_post(url, post_data(action, parameters)))
          # add headers to arguments
          response = parse(ssl_post(url, post_data(action, parameters), headers))
        end

        Response.new(
          success_from(response),
          message_from(response),
          body_from(response),
          authorization: authorization_from(response),
#           avs_result: AVSResult.new(code: response["risk"]["cvvResponseCode"]), # ZZZ: No AVS response is coming across. -mab 2015-10-29
#           cvv_result: CVVResult.new(response["risk"]["cvvResponse"]),
#          test: test?,
          error_code: error_code_from(response)
        )
      end

      def body_from(response)
        response.body.blank? ? {} : JSON.parse(response.body)
      end

      def success_from(response)
        (200...300).include? response.code.to_i
      end

      def message_from(response)
        unless success_from(response)
          JSON.parse(response.body)["message"]
        end
      end

      def authorization_from(response)
        response["authCode"]
      end

      def post_data(action, parameters = {})
        parameters.to_json
      end

      def headers
        {
          "Authorization" => "Basic " + Base64.strict_encode64(@options[:username].to_s + ":" + @options[:password].to_s),
          "Content-Type" => "application/json"
        }
      end

      def error_code_from(response)
        unless success_from(response)
          JSON.parse(response.body)["errorCode"]
        end
      end

      def parse(response)
        response
      end

      def handle_response(response)
        case response.code.to_i
        when 200...300
          response
        when 400...500
          response
        else
          raise ResponseError.new(response)
        end
      end
    end
  end
end
