require 'json'
require 'active_merchant/billing/gateways/quickpay/quickpay_common'

module ActiveMerchant
  module Billing
    class QuickpayV10Gateway < Gateway
      include QuickpayCommon
      API_VERSION = 10

      self.live_url = self.test_url = 'https://api.quickpay.net'

      def initialize(options = {})
        requires!(options, :api_key)
        super
      end

      def purchase(money, credit_card, options = {})
        MultiResponse.run(true) do |r|
          r.process { create_payment(money, options) }
          r.process {
            post = authorization_params(money, credit_card, options)
            add_autocapture(post, true)
            commit(synchronized_path("/payments/#{r.authorization}/authorize"), post)
          }
        end
      end

      def authorize(money, credit_card, options = {})
        MultiResponse.run(true) do |r|
          r.process { create_payment(money, options) }
          r.process {
            post = authorization_params(money, credit_card, options)
            commit(synchronized_path("/payments/#{r.authorization}/authorize"), post)
          }
        end
      end

      def void(identification, _options = {})
        commit(synchronized_path "/payments/#{identification}/cancel")
      end

      def credit(money, identification, options = {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end

      def capture(money, identification, options = {})
        post = {}
        add_amount(post, money, options)
        add_additional_params(:capture, post, options)
        commit(synchronized_path("/payments/#{identification}/capture"), post)
      end

      def refund(money, identification, options = {})
        post = {}
        add_amount(post, money, options)
        add_additional_params(:refund, post, options)
        commit(synchronized_path("/payments/#{identification}/refund"), post)
      end

      def store(credit_card, options = {})
        MultiResponse.run(true) do |r|
          r.process { create_subscription(options) }
          r.process {
            authorize_subscription(r.authorization, credit_card, options)
          }
        end
      end

      def unstore(identification)
        commit(synchronized_path "/subscriptions/#{identification}/cancel")
      end

      private

        def authorization_params(money, credit_card, options = {})
          post = {}

          add_amount(post, money, options)
          add_credit_card(post, credit_card)
          add_additional_params(:authorize, post, options)

          post
        end

        def create_subscription(options = {})
          post = {}

          add_subscription_invoice(post, options)
          commit('/subscriptions', post)
        end

        def authorize_subscription(identification, credit_card, options = {})
          post = {}

          add_credit_card(post, credit_card, options)
          add_additional_params(:authorize_subscription, post, options)
          commit(synchronized_path("/subscriptions/#{identification}/authorize"), post)
        end

        def create_payment(money, options = {})
          post = {}
          add_currency(post, money, options)
          add_invoice(post, options)
          commit('/payments', post)
        end

        def commit(action, params = {})
          success = false
          begin
            response = parse(ssl_post(self.live_url + action, params.to_json, headers))
            success = successful?(response)
          rescue ResponseError => e
            response = response_error(e.response.body)
          rescue JSON::ParserError
            response = json_error(response)
          end

          Response.new(success, message_from(success, response), response,
            :test => test?,
            :authorization => response['id']
          )
        end

        def add_subscription_invoice(post, options = {})
          requires!(options, :order_id, :description)
          post[:order_id]    = options[:order_id]
          post[:description] = options[:description]
        end

        def add_currency(post, money, options)
          post[:currency] = options[:currency] || currency(money)
        end

        def add_amount(post, money, options)
          post[:amount] = amount(money)
        end

        def add_autocapture(post, value)
          post[:auto_capture] = value
        end

        def add_order_id(post, options)
          requires!(options, :order_id)
          post[:order_id] = format_order_id(options[:order_id])
        end

        def add_invoice(post, options)
          add_order_id(post, options)

          if options[:billing_address]
            post[:invoice_address]  = map_address(options[:billing_address])
          end

          if options[:shipping_address]
            post[:shipping_address] = map_address(options[:shipping_address])
          end

          [:metadata, :brading_id, :variables].each do |field|
            post[field] = options[field] if options[field]
          end
        end

        def add_additional_params(action, post, options = {})
          MD5_CHECK_FIELDS[API_VERSION][action].each do |key|
            key       = key.to_sym
            post[key] = options[key] if options[key]
          end
        end

        def add_credit_card(post, credit_card, options = {})
          post[:card]             ||= {}
          post[:card][:number]     = credit_card.number
          post[:card][:cvd]        = credit_card.verification_value
          post[:card][:expiration] = expdate(credit_card)
          post[:card][:issued_to]  = credit_card.name
        end

        def parse(body)
          JSON.parse(body)
        end

        def successful?(response)
          has_error    = response['errors']
          invalid_code = (response.key?('qp_status_code') and response['qp_status_code'] != "20000")

          !(has_error || invalid_code)
        end

        def message_from(success, response)
          success ? 'OK' : (response['message'] || response['qp_status_msg'])
        end

        def map_address(address)
          return {} if address.nil?
          requires!(address, :name, :address1, :city, :zip, :country)
          country = Country.find(address[:country])
          mapped = {
            :name         => address[:name],
            :street       => address[:address1],
            :city         => address[:city],
            :region       => address[:address2],
            :zip_code     => address[:zip],
            :country_code => country.code(:alpha3).value
          }
          mapped
        end

        def format_order_id(order_id)
          order_id.to_s.gsub(/#/, '')
        end

        def headers
          auth = Base64.strict_encode64(":#{@options[:api_key]}")
          {
            "Authorization"  => "Basic " + auth,
            "User-Agent"     => "Quickpay-v#{API_VERSION} ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
            "Accept"         => "application/json",
            "Accept-Version" => "v#{API_VERSION}",
            "Content-Type"   => "application/json"
          }
        end

        def response_error(raw_response)
          begin
            parse(raw_response)
          rescue JSON::ParserError
            json_error(raw_response)
          end
        end

        def json_error(raw_response)
          msg = 'Invalid response received from the Quickpay API.'
          msg += "  (The raw response returned by the API was #{raw_response.inspect})"
          { "message" => msg }
        end

        def synchronized_path(path)
          "#{path}?synchronized"
        end

    end

  end
end
