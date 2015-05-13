require 'openssl'
require 'open-uri'
require 'nokogiri'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ZaakpayGateway < Gateway
      self.test_url = 'https://api.zaakpay.com/transactD?v=3'
      self.live_url = 'https://api.zaakpay.com/transactD?v=3'

      self.supported_countries = ['IN']
      self.default_currency = 'INR'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :maestro]

      self.homepage_url = 'http://www.zaakpay.com/'
      self.display_name = 'Zaakpay'
      
      STANDARD_ERROR_CODE_MAPPING = {}
      
      def initialize(options={})
        requires!(options, :merchantIdentifier, :secretKey)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_params(money, payment, post, options)

        commit('sale', post)
      end


      def encrypt_card(value)
        zaakpay_js = open('https://api.zaakpay.com/zaakpay.js').read
        zaakpay_js_split = zaakpay_js.split("'")
        zaakpay_js_key = zaakpay_js_split[1]
        value_str = value.to_s
        encrypted_value = ""

        for index in 0..(value_str.length()-1)
          encrypted_value += (value_str[index].ord.to_s + zaakpay_js_key[index%(zaakpay_js_key.length())].ord.to_s + ",")
        end

        encrypted_value
      end


      def add_params(money, payment, post , options)
        post[:merchantIdentifier] = @options[:merchantIdentifier]
        for key, value in options
          post[key] = value
        end
        post[:amount]                 = money
        post[:debitorcredit]          = "credit"
        post[:encrypted_pan]          = encrypt_card(payment.number)
        post[:nameoncard]             = payment.first_name
        post[:encryptedcvv]           = encrypt_card(payment.verification_value)
        post[:encrypted_expiry_month] = encrypt_card(payment.month)
        post[:encrypted_expiry_year]  = encrypt_card(payment.year)
        checksum = calculate_checksum(money, @options[:secretKey], options)
        post[:checksum]               = checksum
      end


      def calculate_checksum(money, secretKey, options = {})
        checksum_string = ""
        checksum_string += ("'" + @options[:merchantIdentifier] + "'")
        checksum_string += ("'" + options[:orderId] + "'")
        checksum_string += ("'" + options[:mode] + "'")
        checksum_string += ("'" + options[:currency] + "'")
        checksum_string += ("'" + options[:merchantIpAddress] + "'")
        checksum_string += ("'" + options[:txnDate] + "'")
        checksum_string += ("'" + money.to_s + "'")
        
        OpenSSL::HMAC.hexdigest('sha256', secretKey, checksum_string)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        commit('refund', post)
      end

      def void(authorization, options={})
        commit('void', post)
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
          gsub(%r((<n1:Password>).+(</n1:Password>)), '\1[FILTERED]\2').
          gsub(%r((<n1:Username>).+(</n1:Username>)), '\1[FILTERED]\2').
          gsub(%r((<n2:CreditCardNumber>).+(</n2:CreditCardNumber)), '\1[FILTERED]\2').
          gsub(%r((<n2:CVV2>).+(</n2:CVV2)), '\1[FILTERED]\2')
      end

      private

      def add_customer_data(post, options)
        
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
      end

      def parse(body)
        # print "-----------------------body------------------------", body
        body
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        # load 'lib/active_merchant/posts_data.rb'
        response = parse(ssl_post(url, post_data(action, parameters))) #

        return_params = parse_params(response)
        
        message = message_from(response)
        success = success_from(response)
        authorization = authorization_from(response)

        Response.new(
          success,
          message,
          return_params,
          authorization: authorization,
          test: test?
        )
      end

      def parse_params(response)
        params = {}
        parsed_html = Nokogiri::HTML(response)
        form_obj = parsed_html.search("form")[0]
        if form_obj
          inputs = form_obj.search("input")

          for input in inputs
            if input.to_s.include? "responseDescription"
              params["message"] = input.to_s.split('"')[5]
            end
          end

          for input in inputs
            if input.to_s.include? "checksum"
              params["checksum"] = input.to_s.split('"')[5]
            end
          end

        end

        params        
      end

      def success_from(response)
        parsed_html = Nokogiri::HTML(response)
        
        forms = parsed_html.search("form")

        if forms
          form_obj = parsed_html.search("form")[0]
        end

        if form_obj
          inputs = form_obj.search("input")
          success = false
          for input in inputs
            if input.to_s.include? "responseDescription"
              if input.to_s.include? "success"
                success = true
              end
            end
          end
        end

        success
      end

      def message_from(response)
        parsed_html = Nokogiri::HTML(response)
        forms = parsed_html.search("form")

        if forms
          form_obj = parsed_html.search("form")[0]
        end

        if form_obj
          inputs = form_obj.search("input")
          for input in inputs
            if input.to_s.include? "responseDescription"
              return input.to_s.split('"')[5]
            end
          end
        end


      end

      def authorization_from(response)
        ""
      end

      def post_data(action, parameters = {})
        parameters.collect { |key, value| "#{key}=#{ CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end
