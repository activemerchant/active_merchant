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

      def purchase(money, credit_card_or_reference, options = {})
        MultiResponse.run(true) do |r|
          r.process { create_payment(money, options) }
          r.process {
            post = authorization_params(money, credit_card_or_reference, options)
            add_autocapture(post, false)
            commit(synchronized_path("/payments/#{r.authorization}/authorize"), post)
          }
          r.process {
            post = capture_params(money, credit_card_or_reference, options)
            commit(synchronized_path("/payments/#{r.authorization}/capture"), post)
          }
        end
      end

      def authorize(money, credit_card_or_reference, options = {})
        MultiResponse.run(true) do |r|
          r.process { create_payment(money, options) }
          r.process {
            post = authorization_params(money, credit_card_or_reference, options)
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
        post = capture_params(money, identification, options)
        commit(synchronized_path("/payments/#{identification}/capture"), post)
      end

      def refund(money, identification, options = {})
        post = {}
        add_amount(post, money, options)
        add_additional_params(:refund, post, options)
        commit(synchronized_path("/payments/#{identification}/refund"), post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(credit_card, options = {})
        MultiResponse.run do |r|
          r.process { create_store(options) }
          r.process { authorize_store(r.authorization, credit_card, options)}
          r.process { create_token(r.authorization, options.merge({id: r.authorization}))}
        end
      end

      def unstore(identification)
        identification = identification.split(";").last
        commit(synchronized_path "/cards/#{identification}/cancel")
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r(("card\\?":{\\?"number\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("cvd\\?":\\?")\d+), '\1[FILTERED]')
      end

      private

        def authorization_params(money, credit_card, options = {})
          post = {}

          add_amount(post, money, options)
          add_credit_card_or_reference(post, credit_card)
          add_additional_params(:authorize, post, options)

          post
        end

        def capture_params(money, credit_card, options = {})
          post = {}

          add_amount(post, money, options)
          add_additional_params(:capture, post, options)

          post
        end

        def create_store(options = {})
          post = {}
          commit('/cards', post)
        end

        def authorize_store(identification, credit_card, options = {})
          requires!(options, :amount)
          post = {}

          add_amount(post, nil, options)
          add_credit_card_or_reference(post, credit_card, options)
          commit(synchronized_path("/cards/#{identification}/authorize"), post)
        end

        def create_token(identification, options)
          post = {}
          post[:id] = options[:id]
          commit(synchronized_path("/cards/#{identification}/tokens"), post)
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
            :authorization => authorization_from(response, params[:id])
          )
        end

        def authorization_from(response, auth_id)
          if response["token"]
            "#{response["token"]};#{auth_id}"
          else
             response["id"]
          end
        end

        def add_currency(post, money, options)
          post[:currency] = options[:currency] || currency(money)
        end

        def add_amount(post, money, options)
          post[:amount] = options[:amount] || amount(money)
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

        def add_credit_card_or_reference(post, credit_card_or_reference, options = {})
          post[:card]             ||= {}
          if credit_card_or_reference.is_a?(String)
            reference = credit_card_or_reference.split(";").first
            post[:card][:token] = reference
          else
            post[:card][:number]     = credit_card_or_reference.number
            post[:card][:cvd]        = credit_card_or_reference.verification_value
            post[:card][:expiration] = expdate(credit_card_or_reference)
            post[:card][:issued_to]  = credit_card_or_reference.name
          end
        end

        def parse(body)
          JSON.parse(body)
        end

        def successful?(response)
          has_error    = response['errors']
          invalid_code = invalid_operation_code?(response)

          !(has_error || invalid_code)
        end

        def message_from(success, response)
          success ? 'OK' : (response['message'] || invalid_operation_message(response) || "Unknown error - please contact QuickPay")
        end

        def invalid_operation_code?(response)
          if response['operations']
            operation = response['operations'].last
            operation && operation['qp_status_code'] != "20000"
          end
        end

        def invalid_operation_message(response)
          response['operations'] && response['operations'].last['qp_status_msg']
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
          truncate(order_id.to_s.gsub(/#/, ''), 20)
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
