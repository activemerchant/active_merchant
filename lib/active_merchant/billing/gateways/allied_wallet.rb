module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AlliedWalletGateway < Gateway
      self.display_name = "Allied Wallet"
      self.homepage_url = "https://www.alliedwallet.com"

      self.live_url = "https://api.alliedwallet.com/merchants/"

      self.supported_countries = ["US"]
      self.default_currency = "USD"
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :discover,
                                  :diners_club, :jcb, :maestro]

      def initialize(options={})
        requires!(options, :site_id, :merchant_id, :token)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit("purchase", post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit("authorize", post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization, :capture)
        add_customer_data(post, options)

        commit("capture", post)
      end

      def void(authorization, options={})
        post = {}
        add_reference(post, authorization, :void)

        commit("void", post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization, :refund)
        add_amount(post, amount)
        add_customer_data(post, options)

        commit("refund", post)
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
          gsub(%r((Authorization: Bearer )[a-zA-Z0-9._-]+)i, '\1[FILTERED]').
          gsub(%r(("cardNumber\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cVVCode\\?":\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      def add_amount(post, amount)
        post[:amount] = amount
      end

      def add_invoice(post, money, options)
        post[:siteId] = options[:site_id]
        post[:amount] = amount(money)
        post[:trackingId] = options[:order_id]
        post[:currency] = options[:currency] || currency(money)
      end

      def add_payment_method(post, payment_method)
        post[:nameOnCard] = payment_method.name
        post[:cardNumber] = payment_method.number
        post[:cVVCode] = payment_method.verification_value
        post[:expirationYear] = format(payment_method.year, :four_digits)
        post[:expirationMonth] = format(payment_method.month, :two_digits)
      end

      def add_customer_data(post, options)
        post[:email] = options[:email]
        post[:iPAddress] = options[:ip]
        if(billing_address = (options[:billing_address] || options[:address]))
          post[:firstName], post[:lastName] = billing_address[:name].split
          post[:addressLine1] = billing_address[:address1]
          post[:addressLine2] = billing_address[:address2]
          post[:city] = billing_address[:city]
          post[:state] = billing_address[:state]
          post[:countryId] = billing_address[:country]
          post[:postalCode]    = billing_address[:zip]
          post[:phone] = billing_address[:phone]
        end
      end

      def add_reference(post, authorization, action)
        transaction_id, transaction_amount = split_authorization(authorization)
        transactions = {
          capture: :authorizetransactionid,
          void: :authorizeTransactionid,
          refund: :referencetransactionid,
          recurring: :saleTransactionid
        }
        post[transactions[action]] = transaction_id
      end


      ACTIONS = {
        "purchase" => "SALE",
        "authorize" => "AUTHORIZE",
        "capture" => "CAPTURE",
        "void" => "VOID",
        "refund" => "REFUND",
        "store" => "STORE",
      }

      def commit(action, post)
        data = build_request(post)
        response = parse(ssl_post(url(action), data, headers))
        succeeded = success_from(response["status"])
        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(post, response),
          :avs_result => AVSResult.new(code: response["avs_response"]),
          :cvv_result => CVVResult.new(response["cvv2_response"]),
          test: test?
        )

        rescue ResponseError => e
          if e.response.code == '400'
            return Response.new(false, 'Bad Request', {}, :test => test?)
          end
          raise
      end

      def headers
        {
          "Content-type"  => "application/json",
          "Authorization" => "Bearer " + @options[:token]
        }
      end

      def build_request(post)
        post.to_json
      end

      def url(action)
        live_url + @options[:merchant_id].to_s + "/" + ACTIONS[action] + "transactions"
      end

      def parse(body)
        return {} unless body
        JSON.parse(body)
      rescue JSON::ParserError
        {
          "message" => "Invalid response received.",
          "raw_response" => scrub(body)
        }
      end

      def parse_element(response, node)
        if node.has_elements?
          node.elements.each{|element| parse_element(response, element) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def success_from(response)
        response == "Successful"
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          response["message"] || "Unable to read error message"
        end
      end

      def authorization_from(request, response)
        [ response["id"], request[:amount] ].join("|")
      end

      def split_authorization(authorization)
        transaction_id, transaction_amount = authorization.split("|")
        [transaction_id, transaction_amount]
      end

    end
  end
end
