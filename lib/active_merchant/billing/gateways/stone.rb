require 'active_merchant/billing/gateways/stone/stone_response'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class StoneGateway < Gateway

      STONE_RESOURCE_MAP = {
        sale: '/Sale/',
        capture: '/Sale/Capture',
        cancel: '/Sale/Cancel'
      }

      self.live_url = 'https://transaction.stone.com.br'

      self.supported_countries = ['BR']
      self.default_currency = 'BR'
      self.supported_cardtypes = [:visa, :master]
      self.money_format = :cents

      self.homepage_url = 'http://www.stone.com.br/'
      self.display_name = 'Stone E-commerce'

      def initialize(options={})
        requires!(options, :merchant_key)
        @merchant_key = options[:merchant_key]
        super
      end

      def purchase(money, payment, options={})
        options[:operation] = 'AuthAndCapture'
        request_sale(money, payment, options)
      end

      def authorize(money, payment, options={})
        options[:operation] = 'AuthOnly'
        request_sale(money, payment, options)
      end

      def request_sale(money, payment, options={})
        post = {}
        add_payment(post, payment, options)
        add_invoice(post, money, options)

        commit(:sale, post)
      end

      def capture(money, params, options={})
        post = {}
        add_transaction_information(post, money, params)
        commit(:capture, post)
      end

      # Stone API right now use cancel to make a refund
      def void(money, params, options={})
        post = {}
        add_transaction_information(post, money, params)
        commit(:cancel, post)
      end
      alias_method :refund, :void

      def verify(credit_card, options={})
        options[:money] ||= 100
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(options[:money], credit_card, options) }
          r.process(:ignore_result) { void(options[:money], r.params, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(/(CreditCardNumber\\":\\")\d+/, '\1[FILTERED]')
          .gsub(/(SecurityCode\\":\\")\d+/, '\1[FILTERED]')
          .gsub(@merchant_key, '[FILTERED]')
      end

      private
      def add_transaction_information(post, money, params)
        post[:request_key] = params.request_key
        post[:credit_card_transaction_collection] = [{
          amount_in_cents: amount(money),
          transaction_key: params.transaction_key,
          transaction_reference: params.transaction_reference
        }]
        post[:order_key] = params.order_key
      end

      def add_invoice(post, money, options)
        requires!(options, :order_id)

        post[:credit_card_transaction_collection][0][:transaction_reference] = options[:order_id]
        post[:credit_card_transaction_collection][0][:amount_in_cents] = amount(money)
      end

      def add_payment(post, card, options)
        requires!(options, :operation)

        creditcard = {}
        if card.is_a? String
          creditcard[:instant_buy_key] = card
        else
          creditcard[:credit_card_brand] = card.brand
          creditcard[:credit_card_number] = card.number
          creditcard[:exp_month] = card.expiry_date.month
          creditcard[:exp_year] = card.expiry_date.year
          creditcard[:holder_name] = card.name
          creditcard[:security_code] = card.verification_value
        end

        opt = {}
        opt[:payment_method_code] = test? ? 1 : 0

        creditcard_transaction = {}
        creditcard_transaction[:credit_card] = creditcard
        creditcard_transaction[:options] = opt
        creditcard_transaction[:credit_card_operation] = options[:operation]

        post[:credit_card_transaction_collection] = [creditcard_transaction]
      end

      def commit(action, parameters)
        begin
          raw_response = ssl_post(resource_url(action), post_data(parameters))
        rescue ResponseError => e
          raw_response = e.message
        end
        stone = StoneResponse.new(raw_response)

        Response.new(
            stone.success?,
            stone.message,
            stone,
            authorization: stone.authorization,
            test: test?,
            error_code: stone.error_code
          )
      end

      def resource_url(action)
        "#{self.live_url}#{STONE_RESOURCE_MAP[action]}"
      end

      def ssl_post(url, data, headers = {})
        headers['MerchantKey'] = @merchant_key
        headers['Accept'] = 'application/json'
        headers['Content-Type'] = 'application/json'
        super
      end

      def post_data(parameters = {})
        parameters.deep_transform_keys{ |key| key.to_s.camelize }.to_json
      end
    end
  end
end
