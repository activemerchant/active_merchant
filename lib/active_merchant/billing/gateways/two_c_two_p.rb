# frozen_string_literal: true
require 'nokogiri'
require 'active_support/core_ext/hash'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TwoCTwoPGateway < Gateway
      self.test_url = 'https://demo2.2c2p.com/2C2PFrontend/storedCardPaymentV2/AuthPayment.aspx'
      self.live_url = 'https://t.2c2p.com/2C2PFrontend/storedCardPaymentV2/AuthPayment.aspx'

      self.supported_countries = [ "HK", "SG", "MM", "ID", "TH", "PH", "MY", "VN" ]
      self.default_currency = 'SGD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.2c2p.com/'
      self.display_name = '2C2P'

      VERSION = '9.7'

      CURRENCY_CODES = {
        "HKD" => 344, # HONG KONG
        "SGD" => 702, # SINGAPORE
        "MMK" => 104, # MYANMAR
        "IDR" => 360, # INDONESIA
        "THB" => 764, # THAILAND
        "PHP" => 608, # PHILIPPINES
        "MYR" => 458, # MALAYSIA
        "VND" => 704, # VIETNAM
        "USD" => 840, # US Dollar
        "JPY" => 392, # Japan Yen
        "EUR" => 978, # Euro
      }

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options,
          :merchant_id,
          :secret_key,
          :pem_2c2p,
          :merchant_cert,
          :merchant_private_pem,
          :merchant_pem_password)

        super
      end

      def purchase(money, payment, options={})
        post = {}

        add_customer_data(post, options)
        add_invoice(post, money, options)
        add_payment(post, payment, options)

        commit('sale', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r(("pan\\":\\")\d+), '\1[FILTERED]').
          gsub(%r(("merchantID\\":\\")\d+), '\1[FILTERED]')
      end

      private

      def add_customer_data(post, options)
        post[:merchantID] = @options[:merchant_id]
        post[:unique_transaction_code] = options[:order_id][0,10]
        post[:desc] = options[:description]

        post[:user_defined_1] = options[:user_defined_1]
        post[:user_defined_2] = options[:user_defined_2]
        post[:user_defined_3] = options[:user_defined_3]
        post[:user_defined_4] = options[:user_defined_4]
        post[:user_defined_5] = options[:user_defined_5]
      end

      def add_invoice(post, money, options)
        # 12 digit format with leading zero
        post[:amt] = money.to_s.rjust(12, "0")
        post[:currency_code] = currency_code(options[:currency]) || 764
      end

      def add_payment(post, payment, options)
        post[:cardholder_name] = payment.name
        post[:cardholder_email] = options[:email]

        post[:pan] = payment.number
        post[:security_code] = payment.verification_value if payment.verification_value?
        post[:expiry] = {
          month: payment.month.to_s.rjust(2, '0'),
          year: payment.year.to_s
        }
        post[:store_card_unique_i_d] = options[:store_card_uuid] if options[:store_card_uuid].present?

        post[:pan_country] = options[:pan_country]
        post[:payment_channel] = options[:payment_channel]
        post[:client_I_P] = options[:ip]
        post[:pan_bank] = options[:bank_name]
        post[:store_card] = options[:store_card]
      end

      def currency_code(country)
        CURRENCY_CODES.fetch(country, '')
      end

      def parse(body)
        page = Nokogiri::HTML.parse(body)
        payment_response_input = page.search("//input[@id='paymentResponse']")
        if payment_response_input.present?
          encrypted_response = payment_response_input.attr('value').value
          decrypted_data = decrypt(wrap_pkcs7_cert(encrypted_response))

          Hash.from_xml(decrypted_data)
        else
          raise StandardError, "parsing response: #{body}"
        end
      end

      def wrap_pkcs7_cert(content)
        "-----BEGIN PKCS7-----\n" + content + "\n-----END PKCS7-----"
      end

      def unwrap_pkcs7_cert(content)
        content.gsub(/-----(BEGIN|END) PKCS7-----|\n/, '')
      end

      # Encrypt using 2c2p certificate provided
      #
      def encrypt(payload)
        cert = OpenSSL::X509::Certificate.new(@options[:pem_2c2p])
        ciphertext = OpenSSL::PKCS7::encrypt([cert], payload).to_s
        unwrap_pkcs7_cert(ciphertext)
      end

      # Decrypt using merchant private cert
      #
      def decrypt(ciphertext)
        private_key = OpenSSL::PKey::RSA.new(
          @options[:merchant_private_pem],
          @options[:merchant_pem_password])

        cert = OpenSSL::X509::Certificate.new(@options[:merchant_cert])

        pkcs7 = OpenSSL::PKCS7.new(ciphertext)
        pkcs7.decrypt(private_key, cert)
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)

        xml = post_data(parameters)
        encrypted_payload = encrypt(xml)

        response = parse(ssl_post(url, "paymentRequest=#{encrypted_payload}"))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
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

      def error_code_from(response)
        response["PaymentResponse"]["failReason"]
      end

      # Prepare the data to be sent
      #
      #  * compute a hash_value using some parameters and sign them with sha1
      #  * add version to use
      #  * add timestamp and
      #  * convert keys to camelcase
      #
      def post_data(parameters)
        signature_string = @options[:merchant_id] + parameters[:unique_transaction_code] + parameters[:amt]

        parameters[:hash_value] = sign(signature_string)

        build_xml(parameters.merge({
          version: VERSION,
          time_stamp: DateTime.now.strftime("%d%m%y%H%M%S")
        }))
      end

      def sign(payload)
        OpenSSL::HMAC.hexdigest("sha1", @options[:secret_key], payload).upcase
      end

      def build_xml(parameters)
        builder = Builder::XmlMarkup.new
        builder.tag!("PaymentRequest") do |xml|
          parameters.map do |name, value|
            if value.is_a?(Hash)
              add_children(xml, name, value)
            else
              xml.tag!(xmlize_param_name(name), value)
            end
          end
        end
        builder.target!
      end

      def add_children(xml, name, sub_fields)
        xml.tag!(xmlize_param_name(name)) {
          sub_fields.each do |n, v|
            xml.tag!(xmlize_param_name(n), v)
          end
        }
      end

      def xmlize_param_name(name)
        name.to_s.camelcase(:lower)
      end
    end
  end
end
