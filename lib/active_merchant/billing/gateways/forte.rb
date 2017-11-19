require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ForteGateway < Gateway
      include Empty

      self.test_url = 'https://sandbox.forte.net/api/v2'
      self.live_url = 'https://api.forte.net/v2'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.forte.net'
      self.display_name = 'Forte'

      def initialize(options={})
        requires!(options, :api_key, :secret, :location_id, :account_id)
        super
      end

      def purchase(money, payment_method, options={})
        post = {}
        add_amount(post, money, options)
        add_invoice(post, options)
        add_payment_method(post, payment_method)
        add_billing_address(post, payment_method, options)
        add_shipping_address(post, options)
        post[:action] = "sale"

        commit(:post, post)
      end

      def authorize(money, payment_method, options={})
        post = {}
        add_amount(post, money, options)
        add_invoice(post, options)
        add_payment_method(post, payment_method)
        add_billing_address(post, payment_method, options)
        add_shipping_address(post, options)
        post[:action] = "authorize"

        commit(:post, post)
      end

      def capture(money, authorization, options={})
        post = {}
        post[:transaction_id] = transaction_id_from(authorization)
        post[:authorization_code] = authorization_code_from(authorization) || ""
        post[:action] = "capture"

        commit(:put, post)
      end

      def credit(money, payment_method, options={})
        post = {}
        add_amount(post, money, options)
        add_invoice(post, options)
        add_payment_method(post, payment_method)
        add_billing_address(post, payment_method, options)
        post[:action] = "disburse"

        commit(:post, post)
      end

      def void(authorization, options={})
        post = {}
        post[:transaction_id] = transaction_id_from(authorization)
        post[:authorization_code] = authorization_code_from(authorization)
        post[:action] = "void"

        commit(:put, post)
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
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((account_number)\W+\d+), '\1[FILTERED]').
          gsub(%r((card_verification_value)\W+\d+), '\1[FILTERED]')
      end

      private

      def add_auth(post)
        post[:account_id] = "act_#{@options[:account_id]}"
        post[:location_id] = "loc_#{@options[:location_id]}"
      end

      def add_invoice(post, options)
        post[:order_number] = options[:order_id]
      end

      def add_amount(post, money, options)
        post[:authorization_amount] = amount(money)
      end

      def add_billing_address(post, payment, options)
        post[:billing_address] = {}
        if address = options[:billing_address] || options[:address]
          first_name, last_name = split_names(address[:name])
          post[:billing_address][:first_name] = first_name if first_name
          post[:billing_address][:last_name] = last_name if last_name
          post[:billing_address][:physical_address] = {}
          post[:billing_address][:physical_address][:street_line1] = address[:address1] if address[:address1]
          post[:billing_address][:physical_address][:street_line2] = address[:address2] if address[:address2]
          post[:billing_address][:physical_address][:postal_code] = address[:zip] if address[:zip]
          post[:billing_address][:physical_address][:region] = address[:state] if address[:state]
          post[:billing_address][:physical_address][:locality] = address[:city] if address[:city]
        end

        if empty?(post[:billing_address][:first_name] && payment.first_name)
          post[:billing_address][:first_name] = payment.first_name
        end

        if empty?(post[:billing_address][:last_name] && payment.last_name)
          post[:billing_address][:last_name] = payment.last_name
        end
      end

      def add_shipping_address(post, options)
        return unless options[:shipping_address]
        address = options[:shipping_address]

        post[:shipping_address] = {}
        first_name, last_name = split_names(address[:name])
        post[:shipping_address][:first_name] = first_name if first_name
        post[:shipping_address][:last_name] = last_name if last_name
        post[:shipping_address][:physical_address][:street_line1] = address[:address1] if address[:address1]
        post[:shipping_address][:physical_address][:street_line2] = address[:address2] if address[:address2]
        post[:shipping_address][:physical_address][:postal_code] = address[:zip] if address[:zip]
        post[:shipping_address][:physical_address][:region] = address[:state] if address[:state]
        post[:shipping_address][:physical_address][:locality] = address[:city] if address[:city]
      end

      def add_payment_method(post, payment_method)
        if payment_method.respond_to?(:brand)
          add_credit_card(post, payment_method)
        else
          add_echeck(post, payment_method)
        end
      end

      def add_echeck(post, payment)
        post[:echeck] = {}
        post[:echeck][:account_holder] = payment.name
        post[:echeck][:account_number] = payment.account_number
        post[:echeck][:routing_number] = payment.routing_number
        post[:echeck][:account_type] = payment.account_type
        post[:echeck][:check_number] = payment.number
      end

      def add_credit_card(post, payment)
        post[:card] = {}
        post[:card][:card_type] = format_card_brand(payment.brand)
        post[:card][:name_on_card] = payment.name
        post[:card][:account_number] = payment.number
        post[:card][:expire_month] = payment.month
        post[:card][:expire_year] = payment.year
        post[:card][:card_verification_value] = payment.verification_value
      end

      def commit(type, parameters)
        add_auth(parameters)

        url = (test? ? test_url : live_url)
        response = parse(handle_resp(raw_ssl_request(type, url + endpoint, parameters.to_json, headers)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response["response"]["avs_result"]),
          cvv_result: CVVResult.new(response["response"]["cvv_code"]),
          test: test?
        )
      end

      def handle_resp(response)
        case response.code.to_i
        when 200..499
          response.body
        else
          raise ResponseError.new(response)
        end
      end

      def parse(response_body)
        JSON.parse(response_body)
      end

      def success_from(response)
        response["response"]["response_code"] == "A01"
      end

      def message_from(response)
        response["response"]["response_desc"]
      end

      def authorization_from(response)
        [response.try(:[], "transaction_id"), response.try(:[], "response").try(:[], "authorization_code")].join("#")
      end

      def endpoint
        "/accounts/act_#{@options[:account_id]}/locations/loc_#{@options[:location_id]}/transactions/"
      end

      def headers
        {
          'Authorization' => ("Basic " + Base64.strict_encode64("#{@options[:api_key]}:#{@options[:secret]}")),
          'X-Forte-Auth-Account-Id' => "act_#{@options[:account_id]}",
          'Content-Type' => 'application/json'
        }
      end

      def format_card_brand(card_brand)
        case card_brand
        when 'visa'
          return 'visa'
        when 'master'
          return 'mast'
        when 'american_express'
          return 'amex'
        when 'discover'
          return 'disc'
        end
      end

      def split_authorization(authorization)
        authorization.split("#")
      end

      def authorization_code_from(authorization)
        _, authorization_code = split_authorization(authorization)
        authorization_code
      end

      def transaction_id_from(authorization)
        transaction_id, _ = split_authorization(authorization)
        transaction_id
      end
    end
  end
end
