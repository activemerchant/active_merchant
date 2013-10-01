module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ConektaGateway < Gateway
      self.test_url = 'https://api.conekta.io/'
      self.live_url = 'https://api.conekta.io/'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['MX']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master]

      # The homepage URL of the gateway
      self.homepage_url = 'https://conekta.io/'

      # The name of the gateway
      self.display_name = 'Conekta Gateway'

      # Default money format
      self.money_format = :cents

      # Default currency
      self.default_currency = 'MXN'

      def initialize(options = {})
        requires!(options, :key)
        super
      end

      def offline_purchase(money, method = "cash", type, options)
        requires!(method)
        requires!(type)
        post = {}
        post[:description] = options[:description] if options
        add_details_data(post, options)
        add_reference_id(post, options)
        add_offline_payment(post, method, type)
        commit('offline', money, post)
      end

      #creditcard can be a card hash or a token
      def purchase(money, creditcard, options = {})
        post = {}

        post[:description] = options[:description] if options
        post[:device_fingerprint] = options[:device_fingerprint] if options
        add_creditcard(post, creditcard)
        add_address(post, options)
        add_details_data(post, options)

        add_reference_id(post, options)
        commit('purchase', money, post)
      end

      def refund(money, options)
        post = {}
        requires!(options, :order_id)
        post[:order_id] = options[:order_id]

        add_reference_id(post, options)
        commit('refund', money, post)
      end

      def void(money, options)
        post = {}
        requires!(options, :order_id)
        post[:order_id] = options[:order_id]

        add_reference_id(post, options)
        commit('void', money, post)
      end

      def capture(money, options = {})
        post = {}
        requires!(options, :order_id)
        post[:order_id] = options[:order_id]

        add_reference_id(post, options)
        commit('capture', money, post)
      end

      def authorize(money, creditcard, options = {})
        post = {}

        post[:description] = options[:description] if options
        post[:device_fingerprint] = options[:device_fingerprint] if options
        add_creditcard(post, creditcard)
        add_address(post, options)
        add_details_data(post, options)

        add_reference_id(post, options)
        commit('authorize', money, post)
      end


      private

      def add_reference_id(post, options)
        post[:reference_id] = options[:details] if options[:details]
      end

      def add_details_data(post, options)
        details = {}
        details[:name] = options[:customer]
        details[:email] = options[:email]
        details[:phone] = options[:phone]
        post[:details] = details
        add_billing_address(post, options)
        add_line_items(post, options)
        add_shipment(post, options)
      end

      def add_shipment(post, options)
        shipment = {}
        shipment[:carrier] = options[:carrier]
        shipment[:service] = options[:service]
        shipment[:tracking_number] = options[:tracking_number]
        shipment[:price] = options[:price]
        post[:details][:shipment] = shipment if post[:details]
        add_shipment_address(post, options)
      end

      def add_shipment_address(post, options)
        address = {}
        address[:street1] = options[:address1]
        address[:street2] = options[:address2]
        address[:street3] = options[:address3]
        address[:city] = options[:city]
        address[:state] = options[:state]
        address[:country] = options[:country]
        address[:zip] = options[:zip]
        post[:details][:shipment][:address] = address if post[:details][:shipment]
      end

      def add_line_items(post, options)
        if post[:line_items]
          line_items = []
          post[:line_items].each do |line_item|
            line_items = line_items + line_item[:name]
            line_items = line_items + line_item[:sku]
            line_items = line_items + line_item[:unit_price]
            line_items = line_items + line_item[:description]
            line_items = line_items + line_item[:quantity]
            line_items = line_items + line_item[:type]
          end
          post[:line_items] = line_items if !line_items.blank?
        end
      end

      def add_billing_address(post, options)
        address = {}
        address[:street1] = options[:address1]
        address[:street2] = options[:address2]
        address[:street3] = options[:address3]
        address[:city] = options[:city]
        address[:state] = options[:state]
        address[:country] = options[:country]
        address[:zip] = options[:zip]
        address[:company_name] = options[:company_name]
        address[:tax_id] = options[:tax_id]
        address[:name] = options[:name]
        address[:phone] = options[:phone]
        address[:email] = options[:email]
        post[:details][:billing_address] = address if post[:details]
      end

      def add_address(post, options)
        address = {}
        address[:street1] = options[:address1]
        address[:street2] = options[:address2]
        address[:street3] = options[:address3]
        address[:city] = options[:city]
        address[:state] = options[:state]
        address[:country] = options[:country]
        address[:zip] = options[:zip]
        post[:card][:address] = address if post[:card] and post[:card].respond_to?(:number)
      end

      def add_creditcard(post, creditcard)
        if creditcard.kind_of? String
            post[:card] = creditcard
        elsif creditcard.respond_to?(:number)
            card = {}
            card[:name] = creditcard.name
            card[:cvc] = creditcard.verification_value
            card[:number] = creditcard.number
            card[:exp_month] = "#{sprintf("%02d", creditcard.month)}"
            card[:exp_year] = "#{"#{creditcard.year}"[-2, 2]}"
            post[:card] = card
        end
      end

      def add_offline_payment(post, method, type)
        if method.downcase == "cash" || method.downcase == "bank"
          post[method.to_sym] = { :type => type }
        else
          raise "Incorrect payment_method"
        end
      end

      def parse(body)
        if body
          JSON.parse(body)
        else
          {}
        end
      end

      def commit(action, money, parameters)
        parameters[:amount] = money
        headers = {}
        headers["Authorization"] = "Basic #{Base64.encode64((self.options[:key] || "" )+ ':')}"
        headers["RaiseHtmlError"] = "false"
        version = if self.options[:version] then self.options[:version] else '0.2.0' end
        headers["Accept"] = "application/vnd.conekta-v#{version}+json"
        url = test? ? self.test_url : self.live_url
        case action
        when "refund"
          url = "#{url}charges/#{parameters[:order_id]}/refund"
        when "void"
          url = "#{url}charges/#{parameters[:order_id]}/void"
        when "capture"
          url = "#{url}charges/#{parameters[:order_id]}/capture"
        when "purchase"
          url = "#{url}charges.json"
        when "offline"
          url = "#{url}charges.json"
        else #"authorize"
          parameters[:capture] = false
          url = "#{url}charges.json"
        end
        response = parse(ssl_post(url, parameters.to_query, headers))
        Response.new(success?(response),
                     response["message"],
                     response,
                     :test => test?,
                     :authorization => '')
      end

      def success?(response)
        !response["status"].blank?
      end

      def message_from(response)
      end

      def post_data(parameters = {})
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end

