module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ConektaGateway < Gateway
      self.live_url = 'https://api.conekta.io/'

      self.supported_countries = ['MX']
      self.supported_cardtypes = [:visa, :master]
      self.homepage_url = 'https://conekta.io/'
      self.display_name = 'Conekta Gateway'
      self.money_format = :cents
      self.default_currency = 'MXN'

      def initialize(options = {})
        requires!(options, :key)
        options[:version] ||= '0.2.0'
        super
      end

      def purchase(money, payment_source, options = {})
        post = {}

        add_order(post, money, options)
        add_payment_source(post, payment_source, options)
        add_details_data(post, options)

        commit(:post, 'charges', post)
      end

      def authorize(money, payment_source, options = {})
        post = {}

        add_order(post, money, options)
        add_payment_source(post, payment_source, options)
        add_details_data(post, options)

        post[:capture] = false
        commit(:post, "charges", post)
      end

      def capture(money, identifier, options = {})
        post = {}

        post[:order_id] = identifier
        add_order(post, money, options)

        commit(:post, "charges/#{identifier}/capture", post)
      end

      def refund(money, identifier, options)
        post = {}

        post[:order_id] = identifier
        add_order(post, money, options)

        commit(:post, "charges/#{identifier}/refund", post)
      end

      def store(creditcard, options = {})
        post = {}
        add_payment_source(post, creditcard, options)
        post[:name] = options[:name]
        post[:email] = options[:email]

        path = if options[:customer]
          "customers/#{CGI.escape(options[:customer])}"
        else
          'customers'
        end

        commit(:post, path, post)
      end

      def unstore(customer_id, options = {})
        commit(:delete, "customers/#{CGI.escape(customer_id)}", nil)
      end

      private

      def add_order(post, money, options)
        post[:description] = options[:description] || "Active Merchant Purchase"
        post[:reference_id] = options[:order_id]
        post[:currency] = (options[:currency] || currency(money)).downcase
        post[:amount] = amount(money)
      end

      def add_details_data(post, options)
        details = {}
        details[:name] = options[:customer]
        details[:email] = options[:email]
        details[:phone] = options[:phone]
        details[:device_fingerprint] = options[:device_fingerprint]
        details[:ip] = options[:ip]
        add_billing_address(details, options)
        add_line_items(details, options)
        add_shipment(details, options)

        post[:details] = details
      end

      def add_shipment(post, options)
        shipment = {}
        shipment[:carrier] = options[:carrier]
        shipment[:service] = options[:service]
        shipment[:tracking_number] = options[:tracking_number]
        shipment[:price] = options[:price]
        add_shipment_address(shipment, options)
        post[:shipment] = shipment
      end

      def add_shipment_address(post, options)
		if address = options[:shipping_address]
			post[:address] = {}
			post[:address][:street1] = address[:address1]
			post[:address][:street2] = address[:address2]
			post[:address][:street3] = address[:address3]
			post[:address][:city] = address[:city]
			post[:address][:state] = address[:state]
			post[:address][:country] = address[:country]
			post[:address][:zip] = address[:zip]
		end
      end

      def add_line_items(post, options)
        post[:line_items] = (options[:line_items] || []).collect do |line_item|
          line_item
        end
      end

      def add_billing_address(post, options)
		if address = options[:billing_address] || options[:address]
			post[:billing_address] = {}
			post[:billing_address][:street1] = address[:address1]
			post[:billing_address][:street2] = address[:address2]
			post[:billing_address][:street3] = address[:address3]
			post[:billing_address][:city] = address[:city]
			post[:billing_address][:state] = address[:state]
			post[:billing_address][:country] = address[:country]
			post[:billing_address][:zip] = address[:zip]
			post[:billing_address][:company_name] = address[:company_name]
			post[:billing_address][:tax_id] = address[:tax_id]
			post[:billing_address][:name] = address[:name]
			post[:billing_address][:phone] = address[:phone]
			post[:billing_address][:email] = address[:email]
		end
      end

      def add_address(post, options)
		if address = options[:billing_address] || options[:address]
			post[:address] = {}
			post[:address][:street1] = address[:address1]
			post[:address][:street2] = address[:address2]
			post[:address][:street3] = address[:address3]
			post[:address][:city] = address[:city]
			post[:address][:state] = address[:state]
			post[:address][:country] = address[:country]
			post[:address][:zip] = address[:zip]
		end
      end

      def add_payment_source(post, payment_source, options)
        if payment_source.kind_of?(String)
          post[:card] = payment_source
        elsif payment_source.respond_to?(:number)
          card = {}
          card[:name] = payment_source.name
          card[:cvc] = payment_source.verification_value
          card[:number] = payment_source.number
          card[:exp_month] = "#{sprintf("%02d", payment_source.month)}"
          card[:exp_year] = "#{"#{payment_source.year}"[-2, 2]}"
          post[:card] = card
          add_address(post[:card], options)
        end
      end

      def parse(body)
        return {} unless body
        JSON.parse(body)
      end

      def headers(meta)
        @@ua ||= JSON.dump({
          :bindings_version => ActiveMerchant::VERSION,
          :lang => 'ruby',
          :lang_version => "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})",
          :platform => RUBY_PLATFORM,
          :publisher => 'active_merchant'
        })

        {
          "Accept" => "application/vnd.conekta-v#{options[:version]}+json",
          "Authorization" => "Basic " + Base64.encode64("#{options[:key]}:"),
          "RaiseHtmlError" => "false",
          "User-Agent" => "Conekta ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          "X-Conekta-Client-User-Agent" => @@ua,
          "X-Conekta-Client-User-Metadata" => meta.to_json
        }
      end

      def commit(method, url, parameters, options = {})
        success = false
        begin
          raw_response = parse(ssl_request(method, live_url + url, (parameters ? parameters.to_query : nil), headers(options[:meta])))
          success = (raw_response.key?("object") && (raw_response["object"] != "error"))
        rescue ResponseError => e
          raw_response = response_error(e.response.body)
        rescue JSON::ParserError
          raw_response = json_error(raw_response)
        end

        Response.new(
          success,
          raw_response["message"],
          raw_response,
          :test => test?,
          :authorization => raw_response["id"]
        )
      end

      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Conekta API.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          "message" => msg
        }
      end
    end
  end
end

