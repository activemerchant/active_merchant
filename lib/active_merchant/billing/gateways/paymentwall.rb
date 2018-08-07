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

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :project_key, :secret_key)
        super
      end

      def purchase(money, payment, options={})
        validate!
        post = options.merge(add_invoice(post, money, options))
        add_payment(post, creditcard)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize(money, creditcard, options={})
        validate!
        post = options.merge(add_invoice(post, money, options))
        add_payment(post, creditcard)
        add_customer_data(post, options)

        commit('authonly', 'charge', post)
      end

      def capture(money, authorization, options={})
        validate!
        post = options.merge(add_invoice(post, money, options))
        add_payment(post, creditcard)
        add_customer_data(post, options)

        commit('capture', 'charge', post)
      end

      def refund(authorization, options={})
        commit('refund', "charge/#{authorization}/refund", {chargeid: authorization})
      end

      def void(authorization, options={})
        commit('void', "charge/#{authorization}/void", {chargeid: authorization})
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      def api_request(httpmethod, endpoint, data)
        data = data.merge({
          public_key: @options[:project_key]
        })
        if httpmethod == :post
          ssl_post(endpoint, data)
        end
      end

      def add_customer_data(post, creditcard)
        post['customer'] = {
          firstname: creditcard.first_name,
          lastname: creditcard.last_name,
        }
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
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
        post[:token] = parse(api_request(:post, '/token', cc_data))['token']
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, endpoint='', parameters)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url+endpoint, post_data(action, parameters, {
          'X-ApiKey' => @options[:secret_key]
        })))

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

      def success_from(response)
      end

      def message_from(response)
      end

      def authorization_from(response)
      end

      def post_data(action, parameters = {})
        if action == 'authonly'
          parameters[:options][:capture] = 0
        else
          parameters[:options][:capture] = 1
        end
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end

      def validate!
        requires!(options, :browser_ip, :browser_domain, :email, :description, :plan, :history)
      end
    end
  end
end