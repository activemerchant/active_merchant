module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NetworkInternationalGateway < Gateway
      self.live_url = 'https://api-gateway.ngenius-payments.com/transactions/outlets/[your-outlet-reference]'
      self.test_url = 'https://api-gateway-uat.ngenius-payments.com/transactions/outlets/[your-outlet-reference]'

      self.supported_countries = ['AE', 'US']
      self.default_currency = 'AED'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.money_format = :cents

      self.homepage_url = 'https://www.network.ae/en'
      self.display_name = 'Network International Payment Solutions'

      STANDARD_ERROR_CODE_MAPPING = {}

      SUCCESS_STATES = %w(AWAIT_3DS AUTHORISED CAPTURED)

      def initialize(options={})
        requires!(options, :token)
        requires!(options, :outlet)
        @token = options[:token]
        @outlet = options[:outlet]
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_order(post, money, options)
        add_payment(post, payment)

        commit('/payment/card', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(Authorization: Bearer )([A-Za-z0-9\-\._~\+\/]+=*)/, '\1[FILTERED]').
          gsub(/(\\?\\?\\?"pan\\?\\?\\?":\\?\\?\\?")\d+/, '\1[FILTERED]').
          gsub(/(\\?\\?\\?"cvv\\?\\?\\?":\\?\\?\\?")\d+/, '\1[FILTERED]')
      end

      private

      def add_customer_data(post, options)
        post[:emailAddress] = options[:email]
        post[:language] = options[:language]
        post[:merchantOrderReference] = options[:reference]
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:billingAddress] = {}
          post[:billingAddress][:firstName] = options[:first_name]
          post[:billingAddress][:lastName] = options[:last_name]
          post[:billingAddress][:address1] = address[:address1]
          post[:billingAddress][:city] = address[:city]
          post[:billingAddress][:countryCode] = address[:country]
        end

        if address = options[:shipping_address] || options[:address]
          post[:shippingAddress] = {}
          post[:shippingAddress][:firstName] = options[:first_name]
          post[:shippingAddress][:lastName] = options[:last_name]
          post[:shippingAddress][:address1] = address[:address1]
          post[:shippingAddress][:city] = address[:city]
          post[:shippingAddress][:countryCode] = address[:country]
        end
      end

      def add_invoice(post, money, options)
        post[:action] = options[:action] || "AUTH"

        post[:type] = options[:order_type] if options.has_key?(:order_type)
        post[:frequency] = options[:frequency] if options.has_key?(:frequency)
        post[:emailAddress] = options[:email]
        post[:channel] = options[:channel] if options.has_key?(:channel)

        post[:amount] = {}
        post[:amount][:value] = amount(money)
        post[:amount][:currencyCode] = options[:currency] || currency(money)
      end

      def add_merchant_data(post, options)
        post[:merchantAttributes] = {}
        post[:merchantAttributes][:skip3DS] = options[:skip3DS] || true

        if options[:skip_confirmation].present?
          post[:merchantAttributes][:skipConfirmationPage] = options[:skip_confirmation]
        end

        if options[:cancel_url].present?
          post[:merchantAttributes][:cancelUrl] = options[:cancel_url]
        end

        if options[:cancel_text].present?
          post[:merchantAttributes][:cancelText] = options[:cancel_text]
        end
      end

      def add_order(post, money, options)
        order = {}

        add_invoice(order, money, options)
        add_address(order, options)
        add_customer_data(order, options)
        add_merchant_data(order, options)

        post[:order] = order
        post
      end

      def add_payment(post, payment)
        post[:payment] = {}
        post[:payment][:pan] = payment.number
        post[:payment][:cvv] = payment.verification_value if payment.verification_value?
        post[:payment][:expiry] = [format(payment.year, :four_digits), format(payment.month, :two_digits)].join('-')
        post[:payment][:cardholderName] = payment.name
      end

      def parse(body)
        JSON.parse(body)
      end

      def headers(options = {})
        {
          'Accept' => 'application/vnd.ni-payment.v2+json',
          'Content-Type' => 'application/vnd.ni-payment.v2+json',
          'User-Agent' => "ActiveMerchant/#{ActiveMerchant::VERSION}",
          'X-Client-IP' => options[:ip] || '',
          'Authorization' => "Bearer #{@token || options[:token]}",
        }
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url).gsub(/\[your-outlet-reference\]/, @outlet) + action

        raw_response = ssl_post(url, parameters.to_json, headers)
        response = parse(raw_response)
        succeeded = success_from(response)

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response.dig('authResponse', 'success') || response['state'].in?(SUCCESS_STATES)
      end

      def message_from(succeeded, response)
        if succeeded
          response['state']
        else
          error_code_from(response)
        end
      end

      def authorization_from(response)
        response.dig('authResponse', 'authorizationCode') || response['_id']
      end

      def error_code_from(response)
        unless success_from(response)
          response.dig('authResponse', 'authorizationCode') || response['_id']
        end
      end
    end
  end
end
