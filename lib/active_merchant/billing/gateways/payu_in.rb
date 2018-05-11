# encoding: utf-8

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayuInGateway < Gateway
      self.test_url = "https://test.payu.in/_payment"
      self.live_url = "https://secure.payu.in/_payment"

      TEST_INFO_URL = "https://test.payu.in/merchant/postservice.php?form=2"
      LIVE_INFO_URL = "https://info.payu.in/merchant/postservice.php?form=2"

      self.supported_countries = ['IN']
      self.default_currency = 'INR'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :maestro]

      self.homepage_url = 'https://www.payu.in/'
      self.display_name = 'PayU India'

      def initialize(options={})
        requires!(options, :key, :salt)
        super
      end

      def purchase(money, payment, options={})
        requires!(options, :order_id)

        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_addresses(post, options)
        add_customer_data(post, options)
        add_auth(post)

        MultiResponse.run do |r|
          r.process{commit(url("purchase"), post)}
          if(r.params["enrolled"].to_s == "0")
            r.process{commit(r.params["post_uri"], r.params["form_post_vars"])}
          else
            r.process{handle_3dsecure(r)}
          end
        end
      end

      def refund(money, authorization, options={})
        raise ArgumentError, "Amount is required" unless money

        post = {}

        post[:command] = "cancel_refund_transaction"
        post[:var1] = authorization
        post[:var2] = generate_unique_id
        post[:var3] = amount(money)

        add_auth(post, :command, :var1)

        commit(url("refund"), post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(ccnum=)[^&\n"]*(&|\n|"|$)/, '\1[FILTERED]\2').
          gsub(/(ccvv=)[^&\n"]*(&|\n|"|$)/, '\1[FILTERED]\2').
          gsub(/(card_hash=)[^&\n"]*(&|\n|"|$)/, '\1[FILTERED]\2').
          gsub(/(ccnum":")[^"]*(")/, '\1[FILTERED]\2').
          gsub(/(ccvv":")[^"]*(")/, '\1[FILTERED]\2')
      end

      private

      PAYMENT_DIGEST_KEYS = %w(
        txnid amount productinfo firstname email
        udf1 udf2 udf3 udf4 udf5
        bogus bogus bogus bogus bogus
      )
      def add_auth(post, *digest_keys)
        post[:key] = @options[:key]
        post[:txn_s2s_flow] = 1

        digest_keys = PAYMENT_DIGEST_KEYS if digest_keys.empty?
        digest = Digest::SHA2.new(512)
        digest << @options[:key] << "|"
        digest_keys.each do |key|
          digest << (post[key.to_sym] || "") << "|"
        end
        digest << @options[:salt]
        post[:hash] = digest.hexdigest
      end

      def add_customer_data(post, options)
        post[:email] = clean(options[:email] || "unknown@example.com", nil, 50)
        post[:phone] = clean((options[:billing_address] && options[:billing_address][:phone]) || "11111111111", :numeric, 50)
      end

      def add_addresses(post, options)
        if options[:billing_address]
          post[:address1] = clean(options[:billing_address][:address1], :text, 100)
          post[:address2] = clean(options[:billing_address][:address2], :text, 100)
          post[:city] = clean(options[:billing_address][:city], :text, 50)
          post[:state] = clean(options[:billing_address][:state], :text, 50)
          post[:country] = clean(options[:billing_address][:country], :text, 50)
          post[:zipcode] = clean(options[:billing_address][:zip], :numeric, 20)
        end

        if options[:shipping_address]
          if options[:shipping_address][:name]
            first, *rest = options[:shipping_address][:name].split(/\s+/)
            post[:shipping_firstname] = clean(first, :name, 60)
            post[:shipping_lastname] = clean(rest.join(" "), :name, 20)
          end
          post[:shipping_address1] = clean(options[:shipping_address][:address1], :text, 100)
          post[:shipping_address2] = clean(options[:shipping_address][:address2], :text, 100)
          post[:shipping_city] = clean(options[:shipping_address][:city], :text, 50)
          post[:shipping_state] = clean(options[:shipping_address][:state], :text, 50)
          post[:shipping_country] = clean(options[:shipping_address][:country], :text, 50)
          post[:shipping_zipcode] = clean(options[:shipping_address][:zip], :numeric, 20)
          post[:shipping_phone] = clean(options[:shipping_address][:phone], :numeric, 50)
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)

        post[:txnid] = clean(options[:order_id], :alphanumeric, 30)
        post[:productinfo] = clean(options[:description] || "Purchase", nil, 100)

        post[:surl] = "http://example.com"
        post[:furl] = "http://example.com"
      end

      BRAND_MAP = {
        visa: "VISA",
        master: "MAST",
        american_express: "AMEX",
        diners_club: "DINR",
        maestro: "MAES"
      }

      def add_payment(post, payment)
        post[:pg] = "CC"
        post[:firstname] = clean(payment.first_name, :name, 60)
        post[:lastname] = clean(payment.last_name, :name, 20)

        post[:bankcode] = BRAND_MAP[payment.brand.to_sym]
        post[:ccnum] = payment.number
        post[:ccvv] = payment.verification_value
        post[:ccname] = payment.name
        post[:ccexpmon] = format(payment.month, :two_digits)
        post[:ccexpyr] = format(payment.year, :four_digits)
      end

      def clean(value, format, maxlength)
        value ||= ""
        value = case format
        when :alphanumeric
          value.gsub(/[^A-Za-z0-9]/, "")
        when :name
          value.gsub(/[^A-Za-z ]/, "")
        when :numeric
          value.gsub(/[^0-9]/, "")
        when :text
          value.gsub(/[^A-Za-z0-9@\-_\/\. ]/, "")
        when nil
          value
        else
          raise "Unknown format #{format} for #{value}"
        end
        value[0...maxlength]
      end

      def parse(body)
        top = JSON.parse(body)

        if result = top.delete("result")
          result.split("&").inject({}) do |hash, string|
            key, value = string.split("=")
            hash[CGI.unescape(key).downcase] = CGI.unescape(value || "")
            hash
          end.each do |key, value|
            if top[key]
              top["result_#{key}"] = value
            else
              top[key] = value
            end
          end
        end

        if response = top.delete("response")
          top.merge!(response)
        end

        top
      rescue JSON::ParserError
        {
          "error" => "Invalid response received from the PayU API. (The raw response was `#{body}`)."
        }
      end

      def commit(url, parameters)
        response = parse(ssl_post(url, post_data(parameters), "Accept-Encoding" => "identity"))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def url(action)
        case action
        when "purchase"
          (test? ? test_url : live_url)
        else
          (test? ? TEST_INFO_URL : LIVE_INFO_URL)
        end
      end

      def success_from(response)
        if response["result_status"]
          (response["status"] == "success" && response["result_status"] == "success")
        else
          (response["status"] == "success" || response["status"].to_s == "1")
        end
      end

      def message_from(response)
        (response["error_message"] || response["error"] || response["msg"])
      end

      def authorization_from(response)
        response["mihpayid"]
      end

      def post_data(parameters = {})
        PostData.new.merge!(parameters).to_post_data
      end

      def handle_3dsecure(response)
        Response.new(false, "3D-secure enrolled cards are not supported.")
      end
    end
  end
end
