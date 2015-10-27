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

        commit(:purchase, post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit(:authorize, post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization, :capture)
        add_customer_data(post, options)

        commit(:capture, post)
      end

      def void(authorization, options={})
        post = {}
        add_reference(post, authorization, :void)

        commit(:void, post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization, :refund)
        add_amount(post, amount)
        add_customer_data(post, options)

        commit(:refund, post)
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
          gsub(%r(("cVVCode\\?":\\?")\d+[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cVVCode\\?":)null), '\1[BLANK]').
          gsub(%r(("cVVCode\\?":\\?")\\?"), '\1[BLANK]"').
          gsub(%r(("cVVCode\\?":\\?")\s+), '\1[BLANK]"')
      end

      private

      def add_amount(post, amount)
        post[:amount] = amount
      end

      def add_invoice(post, money, options)
        post[:siteId] = @options[:site_id]
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
        post[:email] = options[:email] || "unspecified@example.com"
        post[:iPAddress] = options[:ip]
        if (billing_address = options[:billing_address])
          post[:firstName], post[:lastName] = split_names(billing_address[:name])
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
        transactions = {
          capture: :authorizetransactionid,
          void: :authorizeTransactionid,
          refund: :referencetransactionid,
          recurring: :saleTransactionid
        }
        post[transactions[action]] = authorization
      end


      ACTIONS = {
        purchase: "SALE",
        authorize: "AUTHORIZE",
        capture: "CAPTURE",
        void: "VOID",
        refund: "REFUND"
      }

      def commit(action, post)
        begin
          raw_response = ssl_post(url(action), post.to_json, headers)
          response = parse(raw_response)
        rescue ResponseError => e
          raise unless(e.response.code.to_s =~ /4\d\d/)
          response = parse(e.response.body)
        end

        succeeded = success_from(response["status"])
        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: response["id"],
          :avs_result => AVSResult.new(code: response["avs_response"]),
          :cvv_result => CVVResult.new(response["cvv2_response"]),
          test: test?
        )
      rescue JSON::ParserError
        unparsable_response(raw_response)
      end

      def unparsable_response(raw_response)
        message = "Unparsable response received from Allied Wallet. Please contact Allied Wallet if you continue to receive this message."
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end

      def headers
        {
          "Content-type"  => "application/json",
          "Authorization" => "Bearer " + @options[:token]
        }
      end

      def url(action)
        live_url + CGI.escape(@options[:merchant_id]) + "/" + ACTIONS[action] + "transactions"
      end

      def parse(body)
        JSON.parse(body)
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

    end
  end
end
