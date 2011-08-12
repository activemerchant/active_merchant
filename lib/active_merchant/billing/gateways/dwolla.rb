module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class DwollaGateway < Gateway
      class DwollaPostData < PostData
        def to_json_post_data
          purchase_order = self[:purchase_order]
          items = []
          purchase_order[:ordered_items].each do |item|
            items << %-{"Description":"#{item[:description]}","Name":"#{item[:name]}","Price": #{"%.2f" % item[:price]},"Quantity": #{item[:quantity]}}-
          end

          urls = ""
          test_string = ""
          urls << %-"Callback":"#{self[:payment_callback]}",- unless self[:payment_callback].nil?
          urls << %-"Redirect":"#{self[:payment_redirect]}",- unless self[:payment_redirect].nil?
          test_string << %-"Test":"true",- unless self[:test] == false

          #Fording formatting of dollar amounts to decimals for Dwolla server.
          %-{"Key":"#{self[:key]}","Secret":"#{self[:secret]}",#{urls}#{test_string}"PurchaseOrder":{"DestinationId":"#{purchase_order[:destination_id]}","Discount": #{"%.2f" %  purchase_order[:discount]},"OrderItems":[#{items.join(',')}],"Shipping": #{"%.2f" % purchase_order[:shipping]},"Tax": #{"%.2f" % purchase_order[:tax]},"Total": #{"%.2f" % purchase_order[:total]}}}-
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

      # The type of moneys the gateway takes
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

        commit(post)
      end

      private

      def add_callback(post, options)
          post[:payment_callback] = options[:payment_callback] unless options[:payment_callback].empty?
          post[:payment_redirect] = options[:payment_redirect] unless options[:payment_redirect].empty?
      end

      def add_purchase_order(post, total, options)
        purchase_order = {}
        purchase_order[:destination_id] = options[:destination_id]
        purchase_order[:discount] = options[:discount]
        purchase_order[:shipping] = options[:shipping]
        purchase_order[:tax] = options[:tax]
        purchase_order[:total] = total

        purchase_order = add_ordered_items(purchase_order, options)

        post[:purchase_order] = purchase_order
      end

      def add_ordered_items(purchase_order, options)
        ordered_items = options[:ordered_items]

        if ordered_items.nil?
          ordered_items = [{:name => options[:description],
                          :description => options[:description],
                          :price => options[:total],
                          :quantity => 1}]
        end

        purchase_order[:ordered_items] = ordered_items

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

      def commit(post)
        post[:test] = test? ? true : false
        response = parse(ssl_post(LIVE_URL, post_data(post), {"Content-Type" => "application/json"}) )

        if response[:response] == "ERROR"
          Response.new(
              false,
              'Failed purchase order setup',
              {:error => response[:message]},
              {:test => post[:test]})
        else
          Response.new(true,
                       "Successfully purchase order setup.",
                        {:checkout_id => response[:checkout_id],
                        :redirect_url => CHECKOUT_URL + response[:checkout_id]},
                        {:test => post[:test]})
        end
      end

      def post_data(post = {})
        post[:key]        = @options[:public_key]
        post[:secret]   = @options[:private_key]
        
        post.to_json_post_data
      end
    end
  end
end

