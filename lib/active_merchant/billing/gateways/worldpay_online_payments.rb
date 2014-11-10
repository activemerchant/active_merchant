module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WorldpayOnlinePaymentsGateway < Gateway
      self.live_url = self.test_url = 'https://api.worldpay.com/'

      self.default_currency = 'GBP'
      self.money_format = :cents

      self.supported_countries = %w(HK US GB AU AD BE CH CY CZ DE DK ES FI FR GI GR HU IE IL IT LI LU MC MT NL NO NZ PL PT SE SG SI SM TR UM VA)
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :maestro, :laser, :switch]

      self.homepage_url = 'http://online.worldpay.com'
      self.display_name = 'Worldpay Online Payments'

      CARD_CODES = {
          'visa'             => 'VISA-SSL',
          'master'           => 'ECMC-SSL',
          'discover'         => 'DISCOVER-SSL',
          'american_express' => 'AMEX-SSL',
          'jcb'              => 'JCB-SSL',
          'maestro'          => 'MAESTRO-SSL',
          'laser'            => 'LASER-SSL',
          'diners_club'      => 'DINERS-SSL',
          'switch'           => 'MAESTRO-SSL'
      }

      def initialize(options={})
        requires!(options, :client_key)
        requires!(options, :service_key)
        @client_key = options[:client_key]
        @service_key = options[:service_key]
        super
      end

      def authorize(money, creditcard, options={})
        post = create_post_for_auth_or_purchase(money, creditcard, options)
        post[:capture] = "false"

        commit(:post, 'order', post, options)
      end

      def purchase(money, creditcard, options={})
        post = create_post_for_auth_or_purchase(money, creditcard, options)

        commit(:post, 'order', post, options)
      end

      def capture(money, authorization, options={})
        post = {}
        add_amount(post, money, options)
=begin
        add_application_fee(post, options)
=end

        commit(:post, "order/#{CGI.escape(authorization)}/capture", post, options)
      end

      def refund(money, identification, options={})
        post = {}
        add_amount(post, money, options)
        post[:refund_application_fee] = true if options[:refund_application_fee]

        MultiResponse.run(:first) do |r|
          r.process { commit(:post, "order/#{CGI.escape(identification)}/refund", post, options) }

          return r unless options[:refund_fee_amount]

          r.process { fetch_application_fees(identification, options) }
          r.process { refund_application_fee(options[:refund_fee_amount], application_fee_from_response(r.responses.last), options) }
        end
      end

      def void(identification, options={})
        commit(:post, "charges/#{CGI.escape(identification)}/refund", {}, options)
      end

      def verify(creditcard, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(50, creditcard, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private


      def create_post_for_auth_or_purchase(money, creditcard, options)
        post = {}
        add_amount(post, money, options, true)
        add_creditcard(post, creditcard, options)
=begin
        add_customer(post, creditcard, options)
        add_customer_data(post,options)
=end
        post[:description] = options[:description]
        post[:statement_description] = options[:statement_description]

        post[:metadata] = {}
        post[:metadata][:email] = options[:email] if options[:email]
        post[:metadata][:order_id] = options[:order_id] if options[:order_id]
        post.delete(:metadata) if post[:metadata].empty?

=begin
        add_flags(post, options)
=end
=begin
        add_application_fee(post, options)
=end
        post
      end


      def add_amount(post, money, options, include_currency = false)
        currency = options[:currency] || currency(money)
        post[:amount] = localized_amount(money, currency)
        post[:currency] = currency.downcase if include_currency
      end

      def add_customer_data(post, options)
      end

      def add_address(post, options)
        return unless post[:card] && post[:card].kind_of?(Hash)
        if address = options[:billing_address] || options[:address]
          post[:card][:address_line1] = address[:address1] if address[:address1]
          post[:card][:address_line2] = address[:address2] if address[:address2]
          post[:card][:address_country] = address[:country] if address[:country]
          post[:card][:address_zip] = address[:zip] if address[:zip]
          post[:card][:address_state] = address[:state] if address[:state]
          post[:card][:address_city] = address[:city] if address[:city]
        end
      end

      def add_creditcard(post, creditcard, options)
        card = {}
        if creditcard.respond_to?(:number)
          if creditcard.respond_to?(:track_data) && creditcard.track_data.present?
            card[:swipe_data] = creditcard.track_data
          else
            card[:number] = creditcard.number
            card[:exp_month] = creditcard.month
            card[:exp_year] = creditcard.year
            card[:cvc] = creditcard.verification_value if creditcard.verification_value?
            card[:name] = creditcard.name if creditcard.name
          end

          post[:card] = card
          add_address(post, options)
        elsif creditcard.kind_of?(String)
          if options[:track_data]
            card[:swipe_data] = options[:track_data]
          else
            card = creditcard
          end
          post[:card] = card
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
      end

      def parse(body)
        JSON.parse(body)
      end

      def headers(options = {})
        headers = {
            "Authorization" => @service_key.to_s,
            "User-Agent" => "Worldpay/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
            "X-Worldpay-Client-User-Agent" => user_agent,
            "X-Worldpay-Client-User-Metadata" => {:ip => options[:ip]}.to_json
        }
        headers
      end

      def commit(method, url, parameters=nil, options = {})
=begin
        add_expand_parameters(parameters, options) if parameters
=end

        raw_response = response = nil
        success = false
        begin

          p method.to_s
          p (self.live_url + url).to_s
          p post_data(parameters).to_s
          p headers(options).to_s

          raise ('').to_s
          raw_response = ssl_request(method, self.live_url + url, post_data(parameters), headers(options))
          response = parse(raw_response)
          success = !response.key?("error")
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        card = response["card"] || response["active_card"] || {}
        avs_code = AVS_CODE_TRANSLATOR["line1: #{card["address_line1_check"]}, zip: #{card["address_zip_check"]}"]
        cvc_code = CVC_CODE_TRANSLATOR[card["cvc_check"]]

        Response.new(success,
                     success ? "Transaction approved" : response["error"]["message"],
                     response,
                     :test => response.has_key?("livemode") ? !response["livemode"] : false,
                     :authorization => success ? response["id"] : response["error"]["charge"],
                     :avs_result => { :code => avs_code },
                     :cvv_result => cvc_code,
                     :error_code => success ? nil : STANDARD_ERROR_CODE_MAPPING[response["error"]["code"]]
        )
      end

      def tokenize(options)
        post = {}

        commit(:post, "tokens", post, options)
      end

      def success_from(response)
      end

      def message_from(response)
      end

      def authorization_from(response)
      end

      def post_data(action, parameters = {})
      end
    end
  end
end
