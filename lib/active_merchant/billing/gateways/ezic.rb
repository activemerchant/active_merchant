module ActiveMerchant
  module Billing
    class EzicGateway < Gateway
      self.live_url = 'https://secure-dm3.ezic.com/gw/sas/direct3.2'

      self.supported_countries = %w(AU CA CN FR DE GI IL MT MU MX NL NZ PA PH RU SG KR ES KN GB US)
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]

      self.homepage_url = 'http://www.ezic.com/'
      self.display_name = 'Ezic'

      def initialize(options={})
        requires!(options, :account_id)
        super
      end

      def purchase(money, payment, options={})
        post = {}

        add_account_id(post)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, options)

        commit("S", post)
      end

      def authorize(money, payment, options={})
        post = {}

        add_account_id(post)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, options)

        commit("A", post)
      end

      def capture(money, authorization, options={})
        post = {}

        add_account_id(post)
        add_invoice(post, money, options)
        add_authorization(post, authorization)
        add_pay_type(post)

        commit("D", post)
      end

      def refund(money, authorization, options={})
        post = {}

        add_account_id(post)
        add_invoice(post, money, options)
        add_authorization(post, authorization)
        add_pay_type(post)

        commit("R", post)
      end

      def void(authorization, options={})
        post = {}

        add_account_id(post)
        add_authorization(post, authorization)
        add_pay_type(post)

        commit("U", post)
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
          gsub(%r((card_number=)\w+), '\1[FILTERED]').
          gsub(%r((card_cvv2=)\w+), '\1[FILTERED]')
      end

      private

      def add_account_id(post)
        post[:account_id] = @options[:account_id]
      end

      def add_addresses(post, options)
        add_billing_address(post, options)
        add_shipping_address(post, options)
      end

      def add_billing_address(post, options)
        address = options[:billing_address] || {}

        post[:bill_name1], post[:bill_name2] = split_names(address[:name])
        post[:bill_street] = address[:address1] if address[:address1]
        post[:bill_city] = address[:city] if address[:city]
        post[:bill_state] = address[:state] if address[:state]
        post[:bill_zip] = address[:zip] if address[:zip]
        post[:bill_country] = address[:country] if address[:country]
        post[:cust_phone] = address[:phone] if address[:phone]
      end

      def add_shipping_address(post, options)
        address = options[:shipping_address] || {}

        post[:ship_name1], post[:ship_name2] = split_names(address[:name])
        post[:ship_street] = address[:address1] if address[:address1]
        post[:ship_city] = address[:city] if address[:city]
        post[:ship_state] = address[:state] if address[:state]
        post[:ship_zip] = address[:zip] if address[:zip]
        post[:ship_country] = address[:country] if address[:country]
      end

      def add_customer_data(post, options)
        post[:cust_ip] = options[:ip] if options[:ip]
        post[:cust_email] = options[:email] if options[:email]
        add_addresses(post, options)
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:description] = options[:description] if options[:description]
      end

      def add_payment(post, payment)
        add_pay_type(post)
        post[:card_number] = payment.number
        post[:card_cvv2] = payment.verification_value
        post[:card_expire] = expdate(payment)
      end

      def add_authorization(post, authorization)
        post[:orig_id] = authorization
      end

      def add_pay_type(post)
        post[:pay_type] = "C"
      end

      def parse(body)
        CGI::parse(body).inject({}) { |hash, (key, value)| hash[key] = value.first; hash }
      end

      def commit(transaction_type, parameters)
        parameters[:tran_type] = transaction_type

        begin
          response = parse(ssl_post(live_url, post_data(parameters), headers))
          Response.new(
            success_from(response),
            message_from(response),
            response,
            authorization: authorization_from(response),
            avs_result: AVSResult.new(code: response["avs_code"]),
            cvv_result: CVVResult.new(response["cvv2_code"]),
            test: test?
          )
        rescue ResponseError => e
          Response.new(false, e.response.message)
        end
      end

      def success_from(response)
        response["status_code"] == "1" || response["status_code"] == "T"
      end

      def message_from(response)
        response["auth_msg"]
      end

      def authorization_from(response)
        response["trans_id"]
      end

      def post_data(parameters = {})
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def headers
        {
          "User-Agent" => "ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
        }
      end
    end

  end
end
