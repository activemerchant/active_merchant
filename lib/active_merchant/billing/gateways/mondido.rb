require 'openssl'
require 'digest'
require 'base64'
require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MondidoGateway < Gateway
      self.display_name = 'Mondido'
      self.homepage_url = 'https://www.mondido.com/'
      self.live_url = 'https://api.mondido.com/v1/'

      # For the entire accepted currencies list from Mondido, please access:
      # http://doc.mondido.com/api#currencies
      self.default_currency = 'USD'

      # :dollars  => decimal (e.g., 10.00)
      # :cents    => integer with cents (e.g., 1000 = $10.00)
      self.money_format = :dollars

      self.supported_countries = %w(AT BE BG HR CY CZ DK EE FI FR DE GI GR HU IS IM IT LV LI 
        LT LU MC NL NO PL PT IE MT RO SK SI ES SE CH GB)

      self.supported_cardtypes = [:visa, :master, :discover, :american_express, 
          :diners_club, :jcb, :switch, :solo, :maestro, :laser]

      # Mapping of CVV check result codes from Mondido to CVVResult standard codes
      # For more codes, please check the CVVResult class
      CVC_CODE_TRANSLATOR = {
        'errors.card_cvv.missing' => 'S', # CVV should have been present
        'errors.card_cvv.invalid' => 'N', # CVV does not match
      }

      # Mapping of error codes from Mondido to Gateway class standard error codes
      STANDARD_ERROR_CODE_TRANSLATOR = {
        'errors.card_number.missing' => STANDARD_ERROR_CODE[:invalid_number],
        'errors.card_number.invalid' => STANDARD_ERROR_CODE[:invalid_number],
        'errors.card_expiry.missing' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'errors.card_expiry.invalid' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'errors.card_cvv.missing' => STANDARD_ERROR_CODE[:invalid_cvc],
        'errors.card_cvv.invalid' => STANDARD_ERROR_CODE[:invalid_cvc],
        'errors.card.expired' => STANDARD_ERROR_CODE[:expired_card],
        'errors.zip.missing' => STANDARD_ERROR_CODE[:incorrect_zip],
        'errors.address.missing' => STANDARD_ERROR_CODE[:incorrect_address],
        'errors.city.missing' => STANDARD_ERROR_CODE[:incorrect_address],
        'errors.country_code.missing' => STANDARD_ERROR_CODE[:incorrect_address],
        'errors.payment.declined' => STANDARD_ERROR_CODE[:card_declined],
        'errors.unexpected' => STANDARD_ERROR_CODE[:processing_error]
      }

      def initialize(options={})
        requires!(options, :merchant_id, :api_token, :hash_secret)

        @merchant_id = options[:merchant_id]
        @api_token = options[:api_token]
        @hash_secret = options[:hash_secret]

        super
      end

      def purchase(money, payment, options={})
        # This is combined Authorize and Capture in one transaction. Sometimes we just want to take a payment!
        # API reference: http://doc.mondido.com/api#transaction-create

        options[:authorize] = false
        create_post_for_auth_or_purchase(money, payment, options)
      end

      def authorize(money, payment, options={})
        # Validate the credit card and reserve the money for later collection

        options[:authorize] = true
        create_post_for_auth_or_purchase(money, payment, options)
      end

      def capture(money, authorization, options={})
        # References a previous “Authorize” and requests that the money be drawn down.
        # It’s good practice (required) in many juristictions not to take a payment from a
        #   customer until the goods are shipped.

        put = {}
        add_amount(put, money, options)
        commit(:put, "transactions/#{authorization}/capture", put)
      end

      def refund(money, authorization, options={})
        # Refund money to a card.
        # This may need to be specifically enabled on your account and may not be supported by all gateways

        requires!(options, :reason)
        post = {
          # transaction_id  int *required
          #   ID for the transaction to refund
          :transaction_id => authorization.to_i,

          # reason string *required
          #   The reason for the refund. Ex. "Cancelled order"
          :reason => options[:reason]
        }

        add_amount(post, money, options)
        commit(:post, 'refunds', post)
      end

      def void(authorization, options={})
        # Entirely void a transaction.
        # Any amount into a refund will cancel the whole reservation

        refund(100, authorization, options)
      end

      def verify(credit_card, options={})
        # Test a payment authorizing a value of 1.00
        # Then void the transaction and refund the value
        options[:reason] ||= "Active Merchant Verify"

        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(payment, options = {})
        post = {
          # currency  string* required
          :currency => options[:currency] || self.default_currency,

          # test bool
          #   Must be true if you are using a test card number.
          :test => test?
        }

        # customer_ref  string
        #   Merchant specific customer ID.
        #   If this customer exists the card will be added to that customer.
        #   If it doesn't exists a customer will be created.
        post.merge!( :customer_ref => options[:customer].to_s ) if options[:customer]

        add_credit_card(post, payment)
        commit(:post, 'stored_cards', post)
      end

      def unstore(id, options={})
        params = {}
        commit(:delete, "stored_cards/#{id}", params)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((card_holder=)\w+), '\1[FILTERED]').
          gsub(%r((card_cvv=)\d+), '\1[FILTERED]').
          gsub(%r((card_expiry=)\w+), '\1[FILTERED]').
          gsub(%r((card_number=)\d+), '\1[FILTERED]').
          gsub(%r((card_type=)\w+), '\1[FILTERED]').
          gsub(%r((hash=)\w+), '\1[FILTERED]')
      end

      private

      def create_post_for_auth_or_purchase(money, payment, options={})    
        # A complete (original) options hash might be:
        # options = {
        #   :order_id => '1',
        #   :ip => '10.0.0.1',
        #   :customer => 'Cody Fauser',
        #   :invoice => 525,
        #   :merchant => 'Test Ecommerce',
        #   :description => '200 Web 2.0 M&Ms',
        #   :email => 'codyfauser@gmail.com',
        #   :currency => 'usd',
        #   :address => {
        #     :name => 'Cody Fauser',
        #     :company => '',
        #     :address1 => '',
        #     :address2 => '',
        #     :city => '',
        #     :state => '',
        #     :country => '',
        #     :zip => '90210',
        #     :phone => ''
        #   }
        # }
        ## There are 3 different addresses you can use.
        ## There are :billing_address, :shipping_address, or you can just pass in
        ## :address and it will be used for both.

        requires!(options, :order_id)
        options[:order_id] = options[:order_id].to_s

        post = {
          # string* required
          # The ID of the merchant
          :merchant_id => @merchant_id,

          # string* required
          # Merchant order/payment ID
          :payment_ref => options[:order_id],
        }

        ## API Optional Parameters
        #
        # - test
        # - authorize
        # - metadata
        # - store_card
        # - plan_id
        # - customer_ref
        # - webhook
        # - process

        # test (boolean)
        #   Whether the transaction is a test transaction. Defaults false
        post[:test] = test?

        # authorize (boolean)
        #   [ Not documented ]
        post.merge!( :authorize => options[:authorize] ) if options[:authorize]

        # Merchant custom Metadata (string)
        #   Metadata is custom schemaless information that you can choose to send in to Mondido.
        #   It can be information about the customer, the product or about campaigns or offers.
        #
        #   The metadata can be used to customize your hosted payment window or sending personalized
        #   receipts to your customers in a webhook.
        #
        #   Details: http://doc.mondido.com/api#metadata
        if options[:metadata]
          if options[:metadata].is_a? Hash
            options[:metadata] = options[:metadata].to_json
          end
          post.merge!( :metadata => options[:metadata] ) 
        end

        # Store Card (boolean)
        #   true/false if you want to store the card
        post.merge!( :store_card => options[:store_card] ) if options[:store_card]

        # customer_ref (string)
        #   The merchant specific user/customer ID
        post.merge!( :customer_ref => options[:customer].to_s ) if options[:customer]

        # webhook (object)
        #   You can specify a custom Webhook for a transaction.
        #   For example sending e-mail or POST to your backend.
        #   Details: http://doc.mondido.com/api#webhook
        if options[:webhook]
          if options[:webhook].is_a? Hash
            options[:webhook] = options[:webhook].to_json
          end
          post.merge!( :webhook => options[:webhook] ) 
        end

        # process (boolean)
        #   Should be false if you want to process the payment at a later stage.
        #   You will not need to send in card data
        #   (card_number, card_cvv, card_holder, card_expiry) in this case.
        post.merge!( :process => options[:process] ) if options[:process]

        add_currency(post, money, options)
        add_amount(post, money, options)
        add_credit_card(post, payment)

        # string * required
        # The hash is a MD5 encoded string with some of your merchant and order specific parameters,
        # which is used to verify the payment, and make sure that it is not altered in any way.
        post.merge!(
          :hash => transaction_hash_for(money, options.merge({
            :amount => post[:amount],
            :currency => post[:currency],
            :customer_ref => post[:customer_ref]
          }))
        )

        commit(:post, 'transactions', post)
      end

      def transaction_hash_for(money, options={})
        # Hash recipe: MD5(merchant_id + payment_ref + customer_ref + amount + currency + test + secret)
        # Important to know about the hash-attributes
        # (1)  merchant_id (integer): your merchant id
        # (2)  payment_ref (string): a generated unique order id from your web shop
        # (3)  customer_ref (string): A unique id for your customer
        # (4)  amount (string): Must include two digits, example 10.00
        # (5)  currency (string): An ISO 4214 currency code, must be in lower case (ex. eur)
        # (6)  test (string): "test" if transaction is in test mode, otherwise empty string ""
        # (7)  secret (string): Unique merchant specific string

        hash_attributes = @merchant_id.to_s                             # 1
        hash_attributes += options[:order_id]                           # 2
        hash_attributes += options[:customer_ref].to_s                  # 3
        hash_attributes += options[:amount]                             # 4
        hash_attributes += options[:currency]                           # 5
        hash_attributes += ((test?) ? "test" : "")                      # 6
        hash_attributes += @hash_secret                                 # 7

        md5 = Digest::MD5.new
        md5.update hash_attributes

        return md5.hexdigest
      end

      def add_credit_card(post, credit_card)
        if credit_card.is_a? String      
          post[:card_number] = credit_card
          post[:card_type] = "STORED_CARD"
        else
          post[:card_holder] = credit_card.name if credit_card.name
          post[:card_cvv] = credit_card.verification_value if credit_card.verification_value?
          post[:card_expiry] = format(credit_card.month, :two_digits) + format(credit_card.year, :two_digits)
          post[:card_number] = credit_card.number
          post[:card_type] = credit_card.brand
        end
      end

      def add_amount(post, money, options)
        # amount decimal *required 
        #   The amount to refund. Ex. 5.00
        currency = options[:currency] || currency(money)
        post[:amount] = localized_amount(money, currency)
      end

      def add_currency(post, money, options)
        # string* required
        # The currency (SEK, CAD, CNY, COP, CZK, DKK, HKD, HUF, ISK, INR, ILS, JPY, KES, KRW,
        #  KWD, LVL, MYR, MXN, MAD, OMR, NZD, NOK, PAB, QAR, RUB, SAR, SGD, ZAR, CHF, THB, TTD,
        #  AED, GBP, USD, TWD, VEF, RON, TRY, EUR, UAH, PLN, BRL)
        currency = (options[:currency] || currency(money)).downcase
        post[:currency] = currency
      end  

      def commit(method, uri, parameters = nil, options = {})
        # Perform Request
        response = api_request(method, uri, parameters, options)

        # Construct the Response object below:
        # Success of Response = absence of errors
        success = !(response.count==3 && response.key?("name") \
          && response.key?("code") && response.key?("description"))

        # Mondido doesn't check the purchase address vs billing address
        # So we use the standard code 'E'.
        # 'E' => AVS data is invalid or AVS is not allowed for this card type.
        # For more codes, please check the AVSResult class
        avs_code = success ? 'E' : nil

        # By default, we understand that the CVV matched (code "M")
        # But we find the error 124 or 125, we report the
        # related CVC Code to Active Merchant gem
        cvc_code = success ? "M" : nil
        if !success && ["errors.card_cvv.invalid","errors.card_cvv.missing"].include?(response["name"])
          cvc_code = CVC_CODE_TRANSLATOR[ response["name"] ]
        end

        am_res = Response.new(
          success,
          (success ? "Transaction approved" : response["description"]),
          response,
          :test => response["test"] || test?,
          :authorization => success ? response["id"] : nil,
          :avs_result => { :code => avs_code },
          :cvv_result => cvc_code,
          :error_code => success ? nil : STANDARD_ERROR_CODE_TRANSLATOR[response["name"]]
        )

        return am_res
      end

      def api_request(method, uri, parameters = nil, options = {})
        if parameters.is_a?(Hash) && parameters.count == 0
          parameters = nil
        end

        # Flow for non pinned requests
        # Make sure to use ssl_request because ActiveMerchant already handle
        # Root CAs verification.
        begin
          raw_response = ssl_request(
            method,
            self.live_url + uri,
            (parameters ? URI.encode_www_form(parameters) : nil),
            headers(options)
          )
        rescue ActiveMerchant::ResponseError => e
          raw_response = e.response.body
        end

        return format_response(raw_response)
      end

      def format_response(raw_response)
        # Response Formatting
        begin
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        return response
      end

      def headers(options = {})
        {
          "Authorization" => "Basic " + Base64.encode64("#{@merchant_id}:#{@api_token}").strip,
          "User-Agent" => "Mondido ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          "Content-Type" => "application/x-www-form-urlencoded"
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def json_error(raw_response)
        msg = "Invalid response received from the Mondido API.\n"
        msg += "  Please contact support@mondido.com if you continue to receive this message.\n"
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"

        unexpected_error(msg)
      end

      def unexpected_error(msg)
        {
          "name" => "errors.unexpected",
          "description" => msg,
          "code" => 133
        }
      end

    end
  end
end
