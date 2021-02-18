module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayTraceGateway < Gateway
      self.live_url = 'https://api.paytrace.com'
      self.money_format = :dollars
      self.default_currency = 'USD'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :discover, :american_express, :diners_club, :jcb]
      self.homepage_url = 'https://www.paytrace.net/'
      self.display_name = 'PayTrace'


      def initialize(options={})
        requires!(options, :username, :password)
        super
      end

      # purchase
      #
      # This option is probably not supported by other gateways. See the PayTrace API reference for more details.
      # https://developers.paytrace.com (SALE TRANSACTIONS)
      #
      # * <tt>options[:card_verification_value]</tt>
      # data-type: string
      #
      # Pass the verification value through options ONLY if needed when submitting transaction_id
      # instead of ActiveMerchant credit card.
      #
      def purchase(money, card_or_transaction, options={})
        MultiResponse.run do |r|
          r.process { access_token_request }
          r.process do
            post = {}
            access_token_from(r, options)

            add_amount(post, money)
            add_invoice(post, options)
            add_payment(post, card_or_transaction, options)
            add_address(post, options)
            add_extra_data(post, options)

            if card_or_transaction.kind_of?(Integer)
              commit('/v1/transactions/sale/by_transaction', post, options)
            else
              commit('/v1/transactions/sale/keyed', post, options)
            end
          end
        end
      end

      def authorize(money, card_or_transaction, options={})
        MultiResponse.run do |r|
          r.process { access_token_request }
          r.process do
            post = {}
            access_token_from(r, options)

            add_amount(post, money)
            add_invoice(post, options)
            add_payment(post, card_or_transaction, options)
            add_address(post, options)
            add_extra_data(post, options)

            if card_or_transaction.kind_of?(Integer)
              commit('/v1/transactions/authorization/by_transaction', post, options)
            else
              commit('/v1/transactions/authorization/keyed', post, options)
            end
          end
        end
      end

      def capture(money, authorization, options={})
        MultiResponse.run do |r|
          r.process { access_token_request }
          r.process do
            post = {}
            access_token_from(r, options)

            add_amount(post, money)
            add_invoice(post, options)
            add_transaction_id(post, authorization)

            commit('/v1/transactions/authorization/capture', post, options)
          end
        end
      end

      def refund(money, card_or_transaction, options={})
        MultiResponse.run do |r|
          r.process { access_token_request }
          r.process do
            post = {}
            access_token_from(r, options)

            add_amount(post, money)
            add_invoice(post, options)
            add_payment(post, card_or_transaction, options)
            add_address(post, options)
            add_extra_data(post, options)

            if card_or_transaction.kind_of?(Integer)
              commit('/v1/transactions/refund/for_transaction', post, options)
            else
              commit('/v1/transactions/refund/keyed', post, options)
            end
          end
        end
      end

      def void(authorization, options={})
        MultiResponse.run do |r|
          r.process { access_token_request }
          r.process do
            post = {}
            access_token_from(r, options)
            add_transaction_id(post, authorization)
            commit('/v1/transactions/void', post, options)
          end
        end
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      # add_level_3_data
      #
      # This option is probably not supported by other gateways. See the PayTrace API reference for more details.
      # https://developers.paytrace.com/support/home#14000046485 (LEVEL 3 DATA)
      #
      # * <tt>options[:brand]</tt>
      # data-type: string
      # possible values: 'visa' or 'master'
      #
      # Defaults to 'visa' if no brand is specified.
      #
      def add_level_3_data(transaction, options={})
        options[:brand] = 'visa' unless options[:brand]

        MultiResponse.run do |r|
          r.process { access_token_request }
          r.process do
            post = {}
            access_token_from(r, options)

            add_transaction_id(post, transaction)
            add_invoice(post, options)
            add_address(post, options)
            add_level_data(post, options)

            action = if options[:brand] == 'master'
              '/v1/level_three/mastercard'
            else
              '/v1/level_three/visa'
            end

            commit(action, post, options)
          end
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Bearer )\w+\:\w+\:\w+), '\1[FILTERED]').
          gsub(%r((username\\\":\\\").+?(?=\\\")), '\1[FILTERED]').
          gsub(%r((password\\\":\\\").+?(?=\\\")), '\1[FILTERED]').
          gsub(%r((number\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((csc\\\":\\\")\d+), '\1[FILTERED]')
      end

      private

      def add_extra_data(post, options)
          post[:email]                        = options[:email] if options[:email]
          post[:description]                  = options[:description] if options[:description]
          post[:return_clr]                   = options[:return_clr] if options[:return_clr]
          post[:custom_dba]                   = options[:custom_dba] if options[:custom_dba]
          post[:enable_partial_authorization] = options[:enable_partial_authorization] if options[:enable_partial_authorization]
          post[:discretionary_data]           = options[:discretionary_data] if options[:discretionary_data]
          post[:tax_amount]                   = options[:tax_amount] if options[:tax_amount]
      end

      def add_level_data(post, options)
        level_data_attributes = [:tax_amount, :national_tax_amount,
          :merchant_tax_id, :customer_tax_id, :commodity_code,
          :discount_amount, :freight_amount, :duty_amount, :source_address,
          :additional_tax_amount, :additional_tax_rate, :additional_tax_included, :line_items]

        (options.keys & level_data_attributes).each do |level_data_attribute|
          post[level_data_attribute] = options[level_data_attribute]
        end
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:billing_address] = {
            name:            address[:name],
            street_address:  address[:address1],
            street_address2: address[:address2],
            city:            address[:city],
            state:           address[:state],
            zip:             address[:zip],
            country:         address[:country]
          }
        end

        if address = options[:shipping_address]
          post[:shipping_address] = {
            name:            address[:name],
            street_address:  address[:address1],
            street_address2: address[:address2],
            city:            address[:city],
            state:           address[:state],
            zip:             address[:zip],
            country:         address[:country]
          }
        end
      end

      def add_payment(post, payment, options)
        if payment.instance_of?(ActiveMerchant::Billing::CreditCard)
          post[:credit_card] = {
            number:           payment.number,
            expiration_year:  payment.year.to_s,
            expiration_month: payment.month.to_s
          }

          # Depending on the type of payment (card or transaction_id),
          # it determines where to pull the verification value from.
          # - pull value from creditcard.verification_value
          #  or
          # - pull from options[:card_verification_value]
          add_card_verification_value(post, payment.verification_value)

        else payment.kind_of?(Integer)
          add_transaction_id(post, payment)
          add_card_verification_value(post, options[:card_verification_value])
        end
      end

      def add_amount(post, money)
        post[:amount] = amount(money)
      end

      def add_invoice(post, options)
        post[:invoice_id] = options[:invoice_id].to_s if options[:invoice_id]

        if po_number = options[:customer_reference_id] || options[:order_id]
          post[:customer_reference_id] = po_number
        end
      end

      def add_transaction_id(post, transaction_id)
        post[:transaction_id] = transaction_id.to_i
      end

      def add_card_verification_value(post, verification_value)
        post[:csc] = verification_value.to_s unless verification_value.blank?
      end

      def parse(body)
        return {} if body.blank?
        JSON.parse(body)
      end

      def request_headers(options)
        if options[:access_token]
          {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{options[:access_token]}"
          }
        else
          {
            "Content-Type" => "application/json",
            "Accept" => "*/*"
          }
        end
      end

      def access_token_request
        commit('/oauth/token', {
          "grant_type" => "password",
          "username" => @options[:username],
          "password" => @options[:password]
        })
      end

      def access_token_from(response, options)
        options[:access_token] = response.params["access_token"]
      end

      def commit(action, parameters, options={})
        raw_response = ssl_post("#{live_url}#{action}", post_data(parameters), request_headers(options))
        response = parse(raw_response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response["avs_response"]),
          cvv_result: CVVResult.new(response["csc_response"]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        if response["response_code"]
          response["success"]
        else
          return true if response["access_token"]
        end
      end

      def message_from(response)
        if response["response_code"]
            response["status_message"]
        else
          response["error_description"]
        end
      end

      def authorization_from(response)
        response["transaction_id"] ? response["transaction_id"] : nil
      end

      def post_data(parameters)
        JSON.generate(parameters)
      end

      def error_code_from(response)
        unless success_from(response)
          return response["errors"].keys.join(',') if response["errors"]
          return response["error"] if response["error"]
          response["status_message"]
        end
      end

      def handle_response(response)
        case response.code.to_i
        when 200..401
          response.body
        else
          raise ResponseError.new(response)
        end
      end

    end
  end
end