module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class DwollaGateway < Gateway
      class DwollaPostData < PostData
        def to_json_post_data
          purchase_order = self[:purchaseorder]
          items = []
          purchase_order[:ordereditems].each do |item|
            items << "{\"Description\":\"#{item[:description]}\",\"Name\":\"#{item[:name]}\",\"Price\": #{item[:price]},\"Quantity\": #{item[:quantity]}}"
          end

          urls = ""
          if self[:payment_callback].nil? == false
            urls << "\"Callback\":\"#{self[:payment_callback]}\","
          end

          puts urls
    
          if self[:payment_redirect].nil? == false
            urls << "\"Redirect\":\"#{self[:payment_redirect]}\","
          end

           puts urls

          test_string = ""
          if self[:test]
            test_string << "\"Test\":\"true\","
          end

          "{\"Key\":\"#{self[:key]}\",\"Secret\":\"#{self[:secret]}\",#{urls}#{test_string}\"PurchaseOrder\":{\"DestinationId\":\"#{purchase_order[:destination_id]}\",\"Discount\": #{purchase_order[:discount]},\"OrderItems\":[#{items.join(',')}],\"Shipping\": #{purchase_order[:shipping]},\"Tax\": #{purchase_order[:tax]},\"Total\": #{purchase_order[:total]}}}"
       end
      end

      LIVE_URL = 'https://www.dwolla.com/payment/request'
      CHECKOUT_URL = 'https://www.dwolla.com/payment/checkout/'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = []

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.dwolla.com/'

      # The name of the gateway
      self.display_name = 'Dwolla'

       self.money_format = :dollars

      def initialize(options = {})
        requires!(options, :public_key, :private_key)
        @options = options
        super
      end

      def purchase(total, options = {})
        post = DwollaPostData.new
        add_purchase_order(post, total, options)
        add_callback(post, options)



        commit('sale', post)
      end

      private

      def add_callback(post, options)
        if options[:payment_callback]
          post[:payment_callback] = options[:payment_callback]
        end

        if options[:payment_redirect]
          post[:payment_redirect] = options[:payment_redirect]
        end
      end

      def add_purchase_order(post, total, options)
        purchase_order = {}
        purchase_order[:destination_id] = options[:destination_id]
        purchase_order[:discount] = options[:discount]
        purchase_order[:shipping] = options[:shipping]
        purchase_order[:tax] = options[:tax]
        purchase_order[:total] = total

        purchase_order = add_ordered_items(purchase_order, options)

        post[:purchaseorder] = purchase_order
      end

      def add_ordered_items(purchase_order, options)
        ordered_items = options[:ordered_items]

        if ordered_items.nil?
          ordered_items = [{:name => options[:description],
                          :description => options[:description],
                          :price => options[:total],
                          :quantity => 1}]
        end

        purchase_order[:ordereditems] = ordered_items

        purchase_order
      end

      def parse(body)
        response = {}

        json_response = JSON.parse(body)
        
        if json_response["Result"] == "Failure"
          response[:response] = 'ERROR'
          response[:message] = json_response["Message"]
        else
          response[:checkout_id] = json_response["CheckoutId"]
        end

        response
      end

      def commit(action, post)
        post[:test] = test? ? true : false
        response = parse( ssl_post(LIVE_URL, post_data(action, post), {"Content-Type" => "application/json"}) )

        puts response.inspect

        if response[:response] == "ERROR"
          Response.new(
              false,
              response[:message],
              {:error => response[:message],
              :test => post[:test]},
              {})
        else
          Response.new(true,
                       response[:message],
                        {:checkout_id => response[:checkout_id],
                        :redirect_url => CHECKOUT_URL + response[:checkout_id],
                       :test => post[:test]},
                        {})
        end
      end

      def message_from(response)

      end

      def post_data(action, post = {})
        post[:key]        = @options[:public_key]
        post[:secret]   = @options[:private_key]

        puts post.to_json_post_data
        
        post.to_json_post_data
      end
    end
  end
end

