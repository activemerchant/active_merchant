module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IyzicoGateway < Gateway
      self.test_url = 'https://stg.iyzipay.com'
      self.live_url = 'https://stg.iyzipay.com'

      self.supported_countries = ['TR']
      self.default_currency = 'TRY'
      self.supported_cardtypes = [:visa, :master, :american_express]

      self.homepage_url = 'http://www.iyzico.com/'
      self.display_name = 'Iyzico'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :api_id, :secret)
        @api_id=options[:api_id]
        @secret=options[:secret]
        super
      end

      def purchase(money, payment, options={})
        request = {}
        create_transaction_parameters(request, money, payment, options)
        commit(:post, '/payment/iyzipos/auth/ecom', request, options)
      end

      def authorize(money, payment, options={})
        request = {}
        create_transaction_parameters(request, money, payment, options)
        commit(:post, '/payment/iyzipos/auth/ecom', request, options)
      end

      def void(authorization, options={})
        request= {}
        create_cancel_request(request, authorization, options)
        commit(:post, '/payment/iyzipos/cancel', request, options)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(0.1, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      class RandomStringGenerator
        RANDOM_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

        def self.random_string(string_length)
          random_string = ''
          string_length.times do |idx|
            random_string << RANDOM_CHARS.split('').sample
          end
          random_string
        end
      end

      class RequestHelper
        AUTHORIZATION_HEADER_STRING = 'IYZWS %s:%s'
        RANDOM_STRING_SIZE = 8

        def self.format_header_string(*args)
          sprintf(RequestHelper::AUTHORIZATION_HEADER_STRING, *args)
        end
      end

      def add_card_data(request, payment)
        payment_card = {}
        payment_card[:cardHolderName] = payment.name
        payment_card[:cardNumber] = payment.number
        payment_card[:expireYear] = payment.year.to_s
        payment_card[:expireMonth] = payment.month.to_s.rjust(2, "0")
        payment_card[:cvc] = payment.verification_value
        request[:paymentCard] = payment_card
      end

      def add_buyer_data(request, options)
        buyer ={}
        billing_data = options[:billing_address] || options[:address]
        buyer[:id] = options[:customer]
        buyer[:name]= options[:name]
        buyer[:surname]= options[:name]
        buyer[:identityNumber]= "SHOPIFY_#{options[:name]}"
        buyer[:email] = options[:email]
        unless billing_data.nil?
          buyer[:gsmNumber] = billing_data[:phone]
          buyer[:registrationAddress] = billing_data[:address1]
          buyer[:city] = billing_data[:city]
          buyer[:country] = billing_data[:country]
        else
          buyer[:gsmNumber] = "not provided"
          buyer[:registrationAddress] ="not provided"
          buyer[:city] = "not provided"
          buyer[:country]= "not provided"
        end
        buyer[:ip] = options[:ip]
        request[:buyer] = buyer
      end

      def add_shipping_address(request, options)
        shipping_address={}
        shipping_data = options[:shipping_address] || options[:address]
        unless shipping_data.nil?
          shipping_address[:address]= shipping_data[:address1]
          shipping_address[:contactName] = shipping_data[:name]
          shipping_address[:city] = shipping_data[:city]
          shipping_address[:country] = shipping_data[:country]
        else
          shipping_address[:address] = "not provided"
          shipping_address[:contactName] = "not provided"
          shipping_address[:city] = "not provided"
          shipping_address[:country]= "not provided"
        end
        request[:shippingAddress] = shipping_address
      end

      def add_billing_address(request, options)
        billing_address={}
        billing_data = options[:billing_address] || options[:address]
        unless billing_data.nil?
          billing_address[:address] = billing_data[:address1]
          billing_address[:zipCode] = billing_data[:zip]
          billing_address[:contactName] = billing_data[:name]
          billing_address[:city] = billing_data[:city]
          billing_address[:country] = billing_data[:country]
        else
          billing_address[:address]= "not provided"
          billing_address[:zipCode] = "not provided"
          billing_address[:contactName] = "not provided"
          billing_address[:city] = "not provided"
          billing_address[:country] = "not provided"
        end
        request[:billingAddress] = billing_address
      end

      def add_basket_items(request, options)
        items = Array.new
        unless options[:items] == nil
          options[:items].each_with_index do |item|
            basket_item ={}
            basket_item[:id] = item[:id]
            basket_item[:price] =item[:amount]
            basket_item[:name] = item[:name]
            basket_item[:category1] = item[:category1]
            basket_item[:itemType] ='PHYSICAL'

            unless item[:subMerchantKey] == nil
              basket_item[:subMerchantKey] = item[:subMerchantKey] ||  "not provided"
              basket_item[:subMerchantPrice] = item[:subMerchantPrice] ||  "not provided"
            end

            items << basket_item
          end
        else
          basket_item ={}
          basket_item[:id] = "not provided"
          basket_item[:price] = "not provided"
          basket_item[:name] = "not provided"
          basket_item[:category1] = "not provided"
          basket_item[:itemType] = 'PHYSICAL'
          items << basket_item
        end
        items
      end

      def sum_of_basket_items(basket_items)
        total_basket_price=0
        return nil unless basket_items
        basket_items.map do |value|
          next if value != false && value.blank?
          if value[:price].kind_of?(Numeric)
            total_basket_price=total_basket_price+ value[:price]
          end
        end
        total_basket_price
      end

      # create request object map to send request to iyzico
      def create_transaction_parameters(request, money, payment, options)
        #create payment basket items and calculate total item price
        basket_items=add_basket_items(request, options)
        request[:locale] = 'tr'
        if options[:order_id] == nil
          uid = rand(36**8).to_s(36)
        else
          uid = options[:order_id]
        end
        request[:conversationId] = "shopify_#{uid}"
        request[:price] =sum_of_basket_items(basket_items)
        request[:paidPrice] = money.to_s
        request[:installment] = 1
        request[:paymentChannel] ='WEB'
        request[:basketId] = options[:order_id]
        request[:paymentGroup] ='PRODUCT'
        # create payment card dto
        add_card_data(request, payment)

        # create payment buyer dto
        add_buyer_data(request, options)

        # create shipping address dto
        add_shipping_address(request, options)

        # create billing address dto
        add_billing_address(request, options)

        request[:basketItems] = basket_items
      end

      def create_cancel_request(request, authorization, options)
        request[:locale] = 'tr'
        request[:paymentId] = authorization
        request[:ip] = options[:ip]
      end

      def parse(body)
        JSON.parse(body)
      end

      def create_pki_string(params)
        sub = ','
        @pki_string = "["
        return nil unless params
        params.map do |key, value|
          next if value != false && value.blank?
          if value.is_a?(Array)
            @pki_string << "#{key}=["
            value.each do |val|
              if val.is_a?(Hash)
                @pki_string << "["
                val.each do |l, m|
                  @pki_string << "#{l}=#{m},"
                end
                @pki_string = @pki_string.gsub(/[#{sub}]+$/, '')
                @pki_string << "], "
              end
            end
            @pki_string = @pki_string.gsub(/[#{sub}] +$/, '')
            @pki_string << "],"
          elsif value.is_a?(Hash)
            @pki_string << "#{key}=["
            value.each do |k, v|
              @pki_string << "#{k}=#{v}," unless v.nil?
            end
            @pki_string = @pki_string.gsub(/[#{sub}]+$/, '')
            @pki_string << "],"
          else
            @pki_string << "#{key}=#{value},"
          end
        end
        @pki_string = @pki_string.gsub(/[#{sub}]+$/, '')
        @pki_string << "]"
      end

      def crate_hash(options={}, random_header_value)
        key = options[:api_id] || @api_id
        secret_key =options[:secret] || @secret
        hash = Digest::SHA1.base64digest("#{key}#{random_header_value}#{secret_key}#{@pki_string}")
        RequestHelper.format_header_string(key, hash)
      end

      def headers(options = {})
        random_header_value = RandomStringGenerator.random_string(RequestHelper::RANDOM_STRING_SIZE)
        headers = {
            "Authorization" => crate_hash(options, random_header_value),
            "x-iyzi-rnd" => random_header_value.to_s,
            "accept" => "application/json",
            "content-type" => "application/json"
        }
        headers
      end

      def api_request(method, endpoint, parameters = nil, options = {})
        url= (test? ? self.test_url : self.live_url)
        create_pki_string(parameters)
        response = ssl_request(method, url + endpoint, parameters.to_json, headers(options))
        response
      end

      def commit(method, endpoint, parameters = nil, options = {})
        response = api_request(method, endpoint, parameters, options)
        result = parse(response)
        if result['status'] == 'success'
          Response.new(true, message_from_transaction_result(result), result, response_options(result))
        else
          Response.new(false, message_from_transaction_result(result), result, {})
        end
      end

      def message_from_transaction_result(result)
        if result['status'] == "success"
          "Transaction success"
        elsif result['status'] == "failure"
          result['errorMessage']
        else
          "Transaction rejected by gateway"
        end
      end

      def response_options(result)
        options = {
            :test => false,
            :authorization => result['paymentId']
        }
        options
      end

    end
  end
end