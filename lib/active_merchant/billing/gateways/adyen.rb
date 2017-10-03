module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AdyenGateway < Gateway

      # we recommend setting up merchant-specific endpoints.
      # https://docs.adyen.com/developers/api-manual#apiendpoints
      self.test_url = 'https://pal-test.adyen.com/pal/servlet/Payment/v18'
      self.live_url = 'https://pal-live.adyen.com/pal/servlet/Payment/v18'

      self.supported_countries = ['AT','AU','BE','BG','BR','CH','CY','CZ','DE','DK','EE','ES','FI','FR','GB','GI','GR','HK','HU','IE','IS','IT','LI','LT','LU','LV','MC','MT','MX','NL','NO','PL','PT','RO','SE','SG','SK','SI','US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb, :dankort, :maestro,  :discover]

      self.money_format = :cents

      self.homepage_url = 'https://www.adyen.com/'
      self.display_name = 'Adyen'

      STANDARD_ERROR_CODE_MAPPING = {
        '101' => STANDARD_ERROR_CODE[:incorrect_number],
        '103' => STANDARD_ERROR_CODE[:invalid_cvc],
        '131' => STANDARD_ERROR_CODE[:incorrect_address],
        '132' => STANDARD_ERROR_CODE[:incorrect_address],
        '133' => STANDARD_ERROR_CODE[:incorrect_address],
        '134' => STANDARD_ERROR_CODE[:incorrect_address],
        '135' => STANDARD_ERROR_CODE[:incorrect_address],
      }

      def initialize(options={})
        requires!(options, :username, :password, :merchant_account)
        @username, @password, @merchant_account = options.values_at(:username, :password, :merchant_account)
        super
      end

      def purchase(money, payment, options={})
        MultiResponse.run do |r|
          r.process{authorize(money, payment, options)}
          r.process{capture(money, r.authorization, options)}
        end
      end

      def authorize(money, payment, options={})
        requires!(options, :order_id)
        post = init_post(options)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_extra_data(post, options)
        add_address(post, options)
        commit('authorise', post)
      end

      def capture(money, authorization, options={})
        post = init_post(options)
        add_invoice_for_modification(post, money, authorization, options)
        add_references(post, authorization, options)
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        post = init_post(options)
        add_invoice_for_modification(post, money, authorization, options)
        add_references(post, authorization, options)
        commit('refund', post)
      end

      def void(authorization, options={})
        post = init_post(options)
        add_references(post, authorization, options)
        commit('cancel', post)
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
          gsub(%r(("number\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cvc\\?":\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      def add_extra_data(post, options)
        post[:shopperEmail] = options[:shopper_email] if options[:shopper_email]
        post[:shopperIP] = options[:shopper_ip] if options[:shopper_ip]
        post[:shopperReference] = options[:shopper_reference] if options[:shopper_reference]
        post[:fraudOffset] = options[:fraud_offset] if options[:fraud_offset]
        post[:selectedBrand] = options[:selected_brand] if options[:selected_brand]
        post[:deliveryDate] = options[:delivery_date] if options[:delivery_date]
        post[:merchantOrderReference] = options[:merchant_order_reference] if options[:merchant_order_reference]
        post[:shopperInteraction] = options[:shopper_interaction] if options[:shopper_interaction]
      end

      def add_address(post, options)
        return unless post[:card] && post[:card].kind_of?(Hash)
        if address = options[:billing_address] || options[:address]
          post[:card][:billingAddress] = {}
          post[:card][:billingAddress][:street] = address[:address1] if address[:address1]
          post[:card][:billingAddress][:houseNumberOrName] = address[:address2] if address[:address2]
          post[:card][:billingAddress][:postalCode] = address[:zip] if address[:zip]
          post[:card][:billingAddress][:city] = address[:city] if address[:city]
          post[:card][:billingAddress][:stateOrProvince] = address[:state] if address[:state]
          post[:card][:billingAddress][:country] = address[:country] if address[:country]
        end
      end

      def add_invoice(post, money, options)
        amount = {
          value: amount(money),
          currency: options[:currency] || currency(money)
        }
        post[:reference] = options[:order_id]
        post[:amount] = amount
      end

      def add_invoice_for_modification(post, money, authorization, options)
        amount = {
          value: amount(money),
          currency: options[:currency] || currency(money)
        }
        post[:modificationAmount] = amount
      end

      def add_payment(post, payment)
        card = {
          expiryMonth: payment.month,
          expiryYear: payment.year,
          holderName: payment.name,
          number: payment.number,
          cvc: payment.verification_value
        }
        card.delete_if{|k,v| v.blank? }
        requires!(card, :expiryMonth, :expiryYear, :holderName, :number, :cvc)
        post[:card] = card
      end

      def add_references(post, authorization, options = {})
        post[:originalReference] = psp_reference_from(authorization)
        post[:reference] = options[:order_id]
      end

      def parse(body)
        return {} if body.blank?
        JSON.parse(body)
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)

        begin
          raw_response = ssl_post("#{url}/#{action.to_s}", post_data(action, parameters), request_headers)
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = parse(raw_response)
        end

        success = success_from(action, response)
        Response.new(
          success,
          message_from(action, response),
          response,
          authorization: authorization_from(action, parameters, response),
          test: test?,
          error_code: success ? nil : error_code_from(response)
        )

      end

      def basic_auth
        Base64.strict_encode64("#{@username}:#{@password}")
      end

      def request_headers
        {
          "Content-Type" => "application/json",
          "Authorization" => "Basic #{basic_auth}"
        }
      end

      def success_from(action, response)
        case action.to_s
        when 'authorise'
          ['Authorised', 'Received', 'RedirectShopper'].include?(response['resultCode'])
        when 'capture', 'refund', 'cancel'
          response['response'] == "[#{action}-received]"
        else
          false
        end
      end

      def message_from(action, response)
        case action.to_s
        when 'authorise'
          response['refusalReason'] || response['resultCode'] || response['message']
        when 'capture', 'refund', 'cancel'
          response['response'] || response['message']
        end
      end

      def authorization_from(action, parameters, response)
        [parameters[:originalReference], response['pspReference']].compact.join("#").presence
      end

      def init_post(options = {})
        {merchantAccount: options[:merchant_account] || @merchant_account}
      end

      def post_data(action, parameters = {})
        JSON.generate(parameters)
      end

      def error_code_from(response)
        STANDARD_ERROR_CODE_MAPPING[response['errorCode']]
      end

      def psp_reference_from(authorization)
        authorization.nil? ? nil : authorization.split("#").first
      end

    end
  end
end
