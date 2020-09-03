# frozen_string_literal: true
require 'nokogiri'
require 'active_support/core_ext/hash'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TwoCTwoPGateway < Gateway
      self.test_url = 'https://demo2.2c2p.com/2C2PFrontEnd/SecurePayment/Payment.aspx'
      self.live_url = 'https://example.com/live'

      self.supported_countries = [ "HK", "SG", "MM", "ID", "TH", "PH", "MY", "VN" ]
      self.default_currency = 'SGD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.example.net/'
      self.display_name = 'New Gateway'

      VERSION = '9.9'

      CURRENCY_CODES = {
        "HKD" => 344, # HONG KONG
        "SGD" => 702, # SINGAPORE
        "MMK" => 104, # MYANMAR
        "IDR" => 360, # INDONESIA
        "THB" => 764, # THAILAND
        "PHP" => 608, # PHILIPPINES
        "MYR" => 458, # MALAYSIA
        "VND" => 704, # VIETNAM
      }

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :merchant_id, :secret_key)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('sale', post)
      end

      # payload is an encoded string, there is no way to scrub something there
      def supports_scrubbing?
        false
      end

      private

      def encode64(payload)
        Base64.strict_encode64(payload)
      end

      def build_xml(parameters)
        builder = Builder::XmlMarkup.new
        builder.tag!("PaymentRequest") do |xml|
          parameters.map do |name, value|
            xml.tag!(xmlize_param_name(name), value)
          end
        end
        builder.target!
      end

      def add_customer_data(post, options)
        post[:merchantID] = @options[:merchant_id]
        post[:unique_transaction_code] = options[:order_id][0,10]
        post[:desc] = options[:description]
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, money, options)
        # 12 digit format with leading zero
        post[:amt] = money.to_s.rjust(12, "0")
        post[:currency_code] = currency_code(options[:currency])
      end

      def add_payment(post, payment, options)
        post[:pan_country] = options[:pan_country]
        post[:cardholder_name] = payment.name
        post[:enc_card_data] = options[:enc_card_data]
      end

      def currency_code(country)
        CURRENCY_CODES.fetch(country, '')
      end

      def parse(body)
        xml_response = Nokogiri::XML(Base64.decode64(body))

        payload = xml_response.xpath('//payload').text

        decode_payload = Base64.decode64(payload)

        xml = Nokogiri::XML(decode_payload)

        JSON.parse(Hash.from_xml(xml.to_xml).to_json)
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        payload = "paymentRequest=#{post_data(parameters)}"
        response = parse(ssl_post(url, payload))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response["some_avs_response_key"]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response["PaymentResponse"]["status"] == "A"
      end

      # response reason is always in 'failReason'
      def message_from(response)
        response["PaymentResponse"]["failReason"]
      end

      def authorization_from(response)
        response["PaymentResponse"]["approvalCode"]
      end

      # https://developer.2c2p.com/docs/submit-payment-request-s2s
      #
      # Here is implemented the data setting described in the above link.
      #
      # 1. Construct payment request message as xml
      # 2. Convert payment request xml to base64
      # 3. sign the payload in 2
      # 4. build a new payment request xml with 2 & 3
      # 5. Convert the new payment request xml to base64 again
      # 6. encode the final payload
      #
      def post_data(parameters)
        params_xml = build_xml(parameters)

        params_xml_encoded = encode64(params_xml)

        signature = sign(params_xml_encoded)

        payment_request_xml = build_xml({
          version: VERSION,
          payload: params_xml_encoded,
          signature: signature
        })

        payment_request_encoded = encode64(payment_request_xml)

        CGI.escape(payment_request_encoded)
      end

      def sign(payload)
        OpenSSL::HMAC.hexdigest("sha256", @options[:secret_key], payload).upcase
      end

      def error_code_from(response)
        response["PaymentResponse"]["failReason"]
      end

      def xmlize_param_name(name)
        name.to_s.camelcase(:lower)
      end
    end
  end
end
