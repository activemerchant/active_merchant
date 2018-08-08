require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaymentwallGateway < Gateway
      self.test_url = 'https://api.paymentwall.com/api/brick/'
      self.live_url = 'https://pwgateway.com/api/'

      self.supported_countries = ["AT", "IT", "BE", "LV", "BG", "LT", "HR", "LU", "CY", "MT", "CZ", "NL", "DK", "PL", "EE", "PT", "FI", "RO", "FR", "SK", "DE", "SI", "GR", "ES", "HU", "SE", "IE", "GB", "US", "CA"]
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express]

      self.homepage_url = 'http://www.paymentwall.com/'
      self.display_name = 'Paymentwall'
      self.money_format = :dollars

      STANDARD_ERROR_CODE_MAPPING = {
        '3011' => STANDARD_ERROR_CODE[:card_declined],
        '3014' => STANDARD_ERROR_CODE[:invalid_cvc],
        '3010' => STANDARD_ERROR_CODE[:card_declined],
        '3112' => STANDARD_ERROR_CODE[:processing_error]
      }

      def initialize(options={})
        requires!(options, :public_key, :secret_key)
        super
      end

      def purchase(money, creditcard, options={})
        validate!(options)
        post = options.merge(add_invoice(money, options))
        add_payment(post, creditcard)
        add_customer_data(post, creditcard)

        commit('sale', 'charge', post)
      end

      def authorize(money, creditcard, options={})
        validate!(options)
        post = options.merge(add_invoice(money, options))
        add_payment(post, creditcard)
        add_customer_data(post, creditcard)

        commit('authonly', 'charge', post)
      end

      def capture(money, authorization, options={})
        commit('capture', "charge/#{authorization}/capture", {})
      end

      def refund(money, authorization, options={})
        commit('refund', "charge/#{authorization}/refund", {})
      end

      def void(authorization, options={})
        commit('void', "charge/#{authorization}/void", {})
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
        transcript.gsub(%r((X-Apikey: )\w+), '\1[FILTERED]').
          gsub(%r((&?card%5Bcvv%5D=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?card%5Bexp_month%5D=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?card%5Bexp_year%5D=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?card%5Bnumber%5D=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?public_key=)\w+), '\1[FILTERED]').
          gsub(%r((&?token=)\w+), '\1[FILTERED]')
      end

      private

      def add_customer_data(post, creditcard)
        post['customer'] = {
          firstname: creditcard.first_name,
          lastname: creditcard.last_name,
        }
      end

      def add_invoice(money, options)
        post = {}
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
        post
      end

      def add_payment(post, creditcard)
        cc_data = {
          card: {
            number: creditcard.number,        
            exp_month: creditcard.expiry_date.month,
            exp_year: creditcard.expiry_date.year,
            cvv: creditcard.verification_value
          }
        }
        post[:token] = parse(
          api_request(:post, 'token', cc_data)
        )['token'] rescue nil

      end

      def api_request(httpmethod, endpoint, data)
        url = (test? ? test_url : live_url)
        data = data.merge({
          public_key: @options[:public_key]
        })
        x = data.to_query
        if httpmethod == :post
          ssl_post(url+endpoint, x, {
            'X-ApiKey' => @options[:secret_key]
          })
        end
      end

      def parse(body)
        JSON.parse(body)
      end

      # commit('sale', 'charge', post)
      def commit(action, endpoint='', parameters)
        url = (test? ? test_url : live_url)
        begin
          response = parse(ssl_post(url+endpoint, post_data(action, parameters), {
            'X-ApiKey' => @options[:secret_key]
          }))
        rescue ResponseError => e
          response = { "error" => JSON.parse(e.response.body)["error"] }
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response["some_avs_response_key"]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def post_data(action, parameters = {})
        if action == 'authonly'
          parameters[:options] = {capture: 0}
        elsif action == 'sale' || action == 'capture'
          parameters[:options] = {capture: 1}
        end
        parameters[:browser_ip] = parameters[:ip]
        parameters.to_query
      end

      def success_from(response)
        response["refunded"] || response["amount"] == response["amount_paid"] && response["amount_paid"].to_i > 0
      end

      def message_from(response)
        return response["error"].upcase if response["error"]
        return "REFUNDED" if response["refunded"] 
        response["captured"] ? "CHARGED" : "AUTHORIZED"
      end

      def authorization_from(response)
        response["id"]
      end

      def error_code_from(response)
        unless success_from(response)
          STANDARD_ERROR_CODE_MAPPING[response['code'].to_s]
        end
      end

      def validate!(options)
        requires!(options, :ip, :browser_domain, :email, :description, :plan)
      end
    end
  end
end