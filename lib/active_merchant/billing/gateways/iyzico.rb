module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IyzicoGateway < Gateway
      self.test_url = 'https://sandbox-api.iyzipay.com'
      self.live_url = 'https://api.iyzipay.com'

      self.supported_countries = ['TR']
      self.default_currency = 'TRY'
      self.supported_cardtypes = [:visa, :master, :american_express]

      self.homepage_url = 'https://www.iyzico.com/'
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
        create_purchase_pki_string(request)
        commit(:post, '/payment/auth', request, options, @purchase_pki_string)
      end

      def authorize(money, payment, options={})
        request = {}
        create_transaction_parameters(request, money, payment, options)
        create_purchase_pki_string(request)
        commit(:post, '/payment/auth', request, options, @purchase_pki_string)
      end

      def void(authorization, options={})
        request= {}
        create_cancel_request(request, authorization, options)
        create_void_pki_string(request)
        commit(:post, '/payment/cancel', request, options, @void_pki_string)
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
        buyer[:surname]= options[:surname]
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

      def add_basket_items(options)
        items = Array.new
        unless options[:items] == nil
          options[:items].each_with_index do |item|
            basket_item ={}
            basket_item[:id] = item[:id]
            basket_item[:price] =item[:price]
            basket_item[:name] = item[:name]
            basket_item[:category1] = item[:category1]
            basket_item[:itemType] ='PHYSICAL'
            basket_item[:subMerchantKey] = item[:subMerchantKey]
            basket_item[:subMerchantPrice] = item[:subMerchantPrice]
            items << basket_item
          end
        else
          basket_item ={}
          basket_item[:id] = "not provided"
          basket_item[:price] = "not provided"
          basket_item[:name] = "not provided"
          basket_item[:category1] = "not provided"
          basket_item[:itemType] = 'PHYSICAL'
          basket_item[:subMerchantKey] = "not provided"
          basket_item[:subMerchantPrice] ="not provided"
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
        basket_items=add_basket_items(options)

        request[:locale] = 'tr'
        if options[:order_id] == nil
          uid = rand(36**8).to_s(36)
        else
          uid = options[:order_id]
        end
        request[:conversationId] = "shopify_#{uid}"
        request[:price] =sum_of_basket_items(basket_items)
        request[:paidPrice] = money.to_s
        request[:currency] = options[:currency] || currency(money)
        request[:installment] = 1
        request[:paymentChannel] ='WEB'
        request[:basketId] = options[:order_id]
        request[:paymentGroup] ='PRODUCT'
        request[:paymentSource] = "SHOPIFY-ACTIVEMERCHANT-#{ActiveMerchant::VERSION}"
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

      class PkiBuilder
        attr_accessor :request_string

        def initialize(request_string = '')
          @request_string = request_string
        end

        def append(key, value = nil)
          unless value.nil?
            append_key_value(key, value)
          end
          self
        end

        def append_price(key, value = nil)
          unless value.nil?
            append_key_value(key, format_price(value))
          end
          self
        end

        def format_price(price)
          unless price.include? '.'
            price = price+'.0'
          end
          sub_str_index = 0
          price_reversed = price.reverse
          i=0
          while i < price.size do
            if price_reversed[i] == '0'
              sub_str_index = i + 1
            elsif price_reversed[i] == '.'
              price_reversed = '0' + price_reversed
              break
            else
              break
            end
            i+=1
          end
          (price_reversed[sub_str_index..-1]).reverse
        end

        def append_array(key, array = nil)
          unless array.nil?
            appended_value = ''
            array.each do |value|
              appended_value << value
              appended_value << ', '
            end
          end
          append_key_value_array(key, appended_value)

          self
        end

        def append_key_value(key, value)
          @request_string = "#{@request_string}#{key}=#{value}," unless value.nil?
        end

        def append_key_value_array(key, value)
          unless value.nil?
            sub = ', '
            value = value.gsub(/[#{sub}]+$/, '')
            @request_string = "#{@request_string}#{key}=[#{value}],"
          end

          self
        end

        def append_prefix
          @request_string = "[#{@request_string}]"
        end

        def remove_trailing_comma
          sub = ','
          @request_string = @request_string.gsub(/[#{sub}]+$/, '')
        end

        def get_request_string
          remove_trailing_comma
          append_prefix

          @request_string
        end
      end

      class PaymentCard
        def self.to_pki_string(request)
          unless request.nil?
            PkiBuilder.new.
                append(:cardHolderName, request[:cardHolderName]).
                append(:cardNumber, request[:cardNumber]).
                append(:expireYear, request[:expireYear]).
                append(:expireMonth, request[:expireMonth]).
                append(:cvc, request[:cvc]).
                append(:registerCard, request[:registerCard]).
                append(:cardAlias, request[:cardAlias]).
                append(:cardToken, request[:cardToken]).
                append(:cardUserKey, request[:cardUserKey]).
                get_request_string
          end
        end
      end

      class Buyer
        def self.to_pki_string(request)
          unless request.nil?
            PkiBuilder.new.
                append(:id, request[:id]).
                append(:name, request[:name]).
                append(:surname, request[:surname]).
                append(:identityNumber, request[:identityNumber]).
                append(:email, request[:email]).
                append(:gsmNumber, request[:gsmNumber]).
                append(:registrationDate, request[:registrationDate]).
                append(:lastLoginDate, request[:lastLoginDate]).
                append(:registrationAddress, request[:registrationAddress]).
                append(:city, request[:city]).
                append(:country, request[:country]).
                append(:zipCode, request[:zipCode]).
                append(:ip, request[:ip]).
                get_request_string
          end
        end
      end

      class Address
        def self.to_pki_string(request)
          unless request.nil?
            PkiBuilder.new.
                append(:address, request[:address]).
                append(:zipCode, request[:zipCode]).
                append(:contactName, request[:contactName]).
                append(:city, request[:city]).
                append(:country, request[:country]).
                get_request_string
          end
        end
      end

      class Basket
        def self.to_pki_string(request)
          unless request.nil?
            basket_items = Array.new
            request.each do |item|
              item_pki = PkiBuilder.new.
                  append(:id, item[:id]).
                  append_price(:price, item[:price].to_s).
                  append(:name, item[:name]).
                  append(:category1, item[:category1]).
                  append(:category2, item[:category2]).
                  append(:itemType, item[:itemType]).
                  append(:subMerchantKey, item[:subMerchantKey]).
                  append(:subMerchantPrice, item[:subMerchantPrice]).
                  append(:ip, item[:ip]).
                  get_request_string
              basket_items << item_pki
            end
            basket_items
          end
        end
      end

      def create_purchase_pki_string(params)
        @purchase_pki_string = PkiBuilder.new.
            append(:locale, params[:locale]).
            append(:conversationId, params[:conversationId]).
            append_price(:price, params[:price].to_s).
            append_price(:paidPrice, params[:paidPrice].to_s).
            append(:installment, params[:installment]).
            append(:paymentChannel, params[:paymentChannel]).
            append(:basketId, params[:basketId]).
            append(:paymentGroup, params[:paymentGroup]).
            append(:paymentCard, PaymentCard.to_pki_string(params[:paymentCard])).
            append(:buyer, Buyer.to_pki_string(params[:buyer])).
            append(:shippingAddress, Address.to_pki_string(params[:shippingAddress])).
            append(:billingAddress, Address.to_pki_string(params[:billingAddress])).
            append_array(:basketItems, Basket.to_pki_string(params[:basketItems])).
            append(:paymentSource, params[:paymentSource]).
            append(:currency, params[:currency]).
            append(:posOrderId, params[:posOrderId]).
            append(:connectorName, params[:connectorName]).
            get_request_string
      end

      def create_void_pki_string(params)
        @void_pki_string = PkiBuilder.new.
            append(:locale, params[:locale]).
            append(:conversationId, params[:conversationId]).
            append(:paymentId, params[:paymentId]).
            append(:ip, params[:ip]).
            get_request_string
      end

      def crate_hash(options={}, random_header_value, pki_string)
        key = options[:api_id] || @api_id
        secret_key =options[:secret] || @secret
        hash = Digest::SHA1.base64digest("#{key}#{random_header_value}#{secret_key}#{pki_string}")
        RequestHelper.format_header_string(key, hash)
      end

      def headers(options = {}, pki_string)
        random_header_value = SecureRandom.hex(RequestHelper::RANDOM_STRING_SIZE)
        {
            "Authorization" => crate_hash(options, random_header_value, pki_string),
            "x-iyzi-rnd" => random_header_value.to_s,
            "accept" => "application/json",
            "content-type" => "application/json"
        }
      end

      def api_request(method, endpoint, parameters = nil, options = {}, pki_string)
        url= (test? ? self.test_url : self.live_url)
        ssl_request(method, url + endpoint, parameters.to_json, headers(options, pki_string))
      end

      def commit(method, endpoint, parameters = nil, options = {}, pki_string)
        response = api_request(method, endpoint, parameters, options, pki_string)
        result = parse(response)
        if result['status'] == 'success'
          Response.new(true, message_from_transaction_result(result), result, response_options(result))
        else
          Response.new(false, message_from_transaction_result(result), result, response_options(result))
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
