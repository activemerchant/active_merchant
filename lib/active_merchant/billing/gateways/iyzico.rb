require 'active_merchant/billing/gateways/iyzico/Iyzipay'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IyzicoGateway < Gateway
      self.test_url = 'https://stg.iyzipay.com'
      self.live_url = 'https://stg.iyzipay.com'

      self.supported_countries = ['TR']
      self.default_currency = 'TRY'
      self.supported_cardtypes = [:visa, :master, :american_express]

      self.homepage_url = 'http://iyzico.com'
      self.display_name = 'iyzico'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :api_id, :secret)
        @api_id = options[:api_id]
        @secret = options[:secret]
        super

        #iyzico Api secret and url configuration class
        @configuration = Iyzipay::Client::Configuration::ClientConfiguration.new
        @configuration.api_key = @api_id
        @configuration.secret_key = @secret
        @configuration.base_url = self.live_url
      end

      def purchase(money, payment, options={})
        authorize(money, payment, options)
      end

      def authorize(money, payment, options={})
        #request to iyzico for payment
        request_to_iyzico(money, payment, options)
      end

      def capture(money, authorization, options={})

      end

      def refund(money, authorization, options={})

      end

      def void(authorization, options={})
        cancel_request(authorization,options)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def add_billing_address(options)
        billing_data = options[:billing_address] || options[:address]
        billing_address = Iyzipay::Client::Ecom::Payment::Dto::EcomPaymentBillingAddressDto.new
        unless billing_data == nil
          billing_address.city = billing_data[:city]
          billing_address.country = billing_data[:country]
          billing_address.address = billing_data[:address1]
          billing_address.contactName = billing_data[:name]
          billing_address.zipCode = billing_data[:zip]
        else
          billing_address.city = "not provided"
          billing_address.country = "not provided"
          billing_address.address = "not provided"
          billing_address.contactName = "not provided"
          billing_address.zipCode = "not provided"
        end
        billing_address
      end

      def add_shipping_address(options)
        shipping_data = options[:shipping_address] || options[:address]
        shipping_address = Iyzipay::Client::Ecom::Payment::Dto::EcomPaymentShippingAddressDto.new
        unless shipping_data == nil
          shipping_address.city = shipping_data[:city]
          shipping_address.country = shipping_data[:country]
          shipping_address.address = shipping_data[:address1]
          shipping_address.contactName = shipping_data[:name]
        else
          shipping_address.city = "not provided"
          shipping_address.country = "not provided"
          shipping_address.address = "not provided"
          shipping_address.contactName = "not provided"
        end
        shipping_address
      end

      def add_buyer_data(options)
        billing_data = options[:billing_address] || options[:address]
        buyer = Iyzipay::Client::Ecom::Payment::Dto::EcomPaymentBuyerDto.new
        buyer.id = options[:customer]
        buyer.email = options[:email]
        buyer.identityNumber = "SHOPIFY_#{options[:name]}"
        buyer.ip = options[:ip]
        buyer.name = options[:name]
        buyer.surname = options[:name]
        unless billing_data == nil
          buyer.city = billing_data[:city]
          buyer.country = billing_data[:country]
          buyer.gsmNumber = billing_data[:phone]
          buyer.registrationAddress = billing_data[:address1]
        else
          buyer.city = "not provided"
          buyer.country = "not provided"
          buyer.gsmNumber = "not provided"
          buyer.registrationAddress = "not provided"
        end
        buyer
      end

      def add_card_data(payment)
        payment_card = Iyzipay::Client::Basic::Payment::Dto::PaymentCardDto.new
        payment_card.cardNumber = payment.number
        payment_card.cvc = payment.verification_value
        payment_card.expireMonth = payment.month.to_s.rjust(2, "0")
        payment_card.expireYear = payment.year.to_s
        payment_card.cardHolderName = payment.name
        payment_card
      end

      def create_transaction_parameters(money, payment, options)
        # create request class object to send request to iyzico
        request = Iyzipay::Client::Ecom::Payment::Request::EcomPaymentAuthRequest.new
        request.locale = Iyzipay::Client::RequestLocaleType::TR
        if options[:order_id] == nil
          uid = rand(36**8).to_s(36)
        else
          uid = options[:order_id]
        end
        request.conversationId = "shopify_#{uid}"
        request.paidPrice = money.to_s
        request.installment = 1
        request.basketId = options[:order_id]
        request.paymentChannel = Iyzipay::Client::Ecom::Payment::Enumtype::PaymentChannelRequestType::WEB
        request.paymentGroup = Iyzipay::Client::Ecom::Payment::Enumtype::PaymentGroupRequestType::PRODUCT
        # create payment card dto
        request.paymentCard = add_card_data(payment)

        # create payment buyer dto
        request.buyer = add_buyer_data(options)

        # create billing address dto
        request.billingAddress = add_billing_address(options)

        # create shipping address dto
        request.shippingAddress = add_shipping_address(options)

        #create payment basket items and calculate total item price
        items = Array.new
        total_price = 0
        unless options[:items] == nil
          options[:items].each_with_index do |item, index|
            itemObj = "item#{index}"
            itemObj = Iyzipay::Client::Ecom::Payment::Dto::EcomPaymentBasketItemDto.new
            itemObj.name = item[:name]
            itemObj.category1 = item[:category]
            itemObj.id = item[:sku]
            itemObj.price = item[:amount]
            itemObj.itemType = Iyzipay::Client::Ecom::Payment::Enumtype::BasketItemRequestType::PHYSICAL
            total_price = total_price + item[:amount]
            items << itemObj
          end
          request.basketItems = items
        else
          itemObj = Iyzipay::Client::Ecom::Payment::Dto::EcomPaymentBasketItemDto.new
          itemObj.name = "not provided"
          itemObj.category1 = "not provided"
          itemObj.id = "not provided"
          itemObj.price = "not provided"
          itemObj.itemType = Iyzipay::Client::Ecom::Payment::Enumtype::BasketItemRequestType::PHYSICAL
          total_price = 0
          items << itemObj
        end
        request.price = total_price.to_s
        request
      end

      def request_to_iyzico(money, payment, options)
        client = Iyzipay::Client::Service::EcomPaymentServiceClient.from_configuration(@configuration)

        request = create_transaction_parameters(money, payment, options)
        raw_response = nil

        #make payment request
        response = client.auth(request)
        raw_response = response.raw_result
        result = JSON(raw_response)
        if result['status'] == 'success'
          return_response = Response.new(true, message_from_transaction_result(result), result, response_options(result))
        else
          return_response = Response.new(false, message_from_transaction_result(result), result, {})
        end
        return_response
      end

      def response_options(result)
        options = {
            :test => false,
            :authorization => result['paymentId']
        }
        options
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

      def cancel_request(authorization,options)
        # create request class
        client = Iyzipay::Client::Service::EcomPaymentServiceClient.from_configuration(@configuration)
        request = Iyzipay::Client::Basic::Payment::Request::PaymentCancelRequest.new
        request.locale = Iyzipay::Client::RequestLocaleType::TR
        request.paymentId = authorization
        request.ip = options[:ip]
        response = client.cancel(request)
        raw_response = response.raw_result
        result = JSON(raw_response)
        if result['status'] == 'success'
          return_response = Response.new(true, message_from_transaction_result(result), result, response_options(result))
        else
          return_response = Response.new(false, message_from_transaction_result(result), result, {})
        end
        return_response
      end

      def commit(method, post)

      end

    end
  end
end
