require 'klarna'

module ActiveMerchant
  module Billing
    class KlarnaGateway < Gateway
      self.supported_countries = %w(AD AT BE BG CA CH CZ DE DK EE ES FI FR GB GR HR HU
                                    IE IS IT LI LT LU LV MC MT NL NO PL PT RO SE SI SK US)
      self.supported_cardtypes = %i[visa master american_express discover jcb diners_club]
      self.display_name = 'Klarna'
      self.homepage_url = 'https://www.klarna.com/'

      def initialize(options={})
        requires!(options, :login, :password, :zone)
        @options = options

        super
        Klarna.configure do |config|
          config.environment = @options[:test] ? 'test' : 'production'
          config.api_key =  @options[:login]
          config.api_secret = @options[:password]
          config.user_agent = "Klarna Gateway/Rails/#{::Rails.version}"
          config.zone = options[:zone].downcase.to_sym
        end
      end

      def create_session(options)
        post = {}
        prepare_billing_address(post, options)
        prepare_shipping_address(post, options)
        prepare_line_items(post, options)
        prepare_order_data(post, options)

        response = Klarna.client(:payment).create_session(post)

        if response.success?
          message = "Session Created #{response.session_id}"
          generate_success_response(response, message)
        else
          generate_failure_response(response)
        end
      end

      def update_session(session_id, options)
        post = {}
        prepare_billing_address(post, options)
        prepare_shipping_address(post, options)
        prepare_line_items(post, options)
        prepare_order_data(post, options)

        response = Klarna.client(:payment).update_session(session_id, post)

        if response.success?
          message = "Session Updated #{session_id}"
          generate_success_response(response, message)
        else
          generate_failure_response(response)
        end
      end

      def purchase(amount, authorize_token, options={})
        post = {}
        prepare_billing_address(post, options)
        prepare_shipping_address(post, options)
        prepare_line_items(post, options)
        prepare_order_data(post, options)

        authorize(amount, authorize_token, post)
      end

      def authorize(amount, authorize_token, options={})
        response = Klarna.client(:payment).place_order(authorize_token, options)

        if response.success?
          message = "Placed order #{response.order_id}"
          generate_success_response(response, message, response.order_id, response.fraud_status)
        else
          generate_failure_response(response)
        end
      end

      def capture(amount, order_id, options={})
        response = Klarna.client.capture(order_id, {captured_amount: amount, shipping_info: options[:shipping_info]})

        if response.success?
          message = "Captured order with Klarna id: '#{order_id}' Capture id: '#{response['Capture-ID']}'"
          generate_success_response(response, message, order_id)
        else
          generate_failure_response(response)
        end
      end

      def refund(amount, order_id, options={})
        # Get the refunded line items for better customer communications
        post = {}
        prepare_line_items(post, options)

        response = Klarna.client(:refund).create(order_id, {refunded_amount: amount, order_lines: post[:order_lines]})

        if response.success?
          message = "Refunded order with Klarna id: #{order_id}"
          generate_success_response(response, message, response['Refund-ID'])
        else
          generate_failure_response(response)
        end
      end

      def store(authorize_token, options={})
        post = {}
        prepare_billing_address(post, options)
        prepare_customer_data(post, options)

        response = Klarna.client(:payment).customer_token(authorize_token, options)

        if response.success?
          message = "Client token Created"
          generate_success_response(response, message)
        else
          generate_failure_response(response)
        end
      end

      alias_method :credit, :refund

      def get(order_id)
        Klarna.client.get(order_id)
      end

      def acknowledge(order_id)
        response = Klarna.client.acknowledge(order_id)

        if response.success?
          message = "Extended Period for order with Klarna id: #{order_id}"
          generate_success_response(response, message)
        else
          generate_failure_response(response)
        end
      end

      def extend_period(order_id)
        response = Klarna.client.extend(order_id)

        if response.success?
          message = "Extended Period for order with Klarna id: #{order_id}"
          generate_success_response(response, message)
        else
          generate_failure_response(response)
        end
      end

      def release(order_id)
        response = Klarna.client.release(order_id)

        if response.success?
          message = "Released reamining amount for order with Klarna id: #{order_id}"
          generate_success_response(response, message, order_id)
        else
          generate_failure_response(response)
        end
      end

      def cancel(order_id)
        response = Klarna.client.cancel(order_id)

        if response.success?
          message = "Cancelled order with Klarna id: #{order_id}"
          generate_success_response(response, message, order_id)
        else
          generate_failure_response(response)
        end
      end

      def shipping_info(order_id, capture_id, shipping_info)
        response = Klarna.client(:capture).shipping_info(
          order_id,
          capture_id,
          shipping_info
        )
        if response.success?
          message = "Updated shipment info for order: #{order_id}, capture: #{capture_id}"
          generate_success_response(response, message)
        else
          generate_failure_response(response)
        end
      end

      def customer_details(order_id, data)
        response = Klarna.client.customer_details(
          order_id,
          data
        )
        if response.success?
          message = "Updated customer details for order: #{order_id}"
          generate_success_response(response, message)
        else
          generate_failure_response(response)
        end
      end

      private

      def generate_success_response(response, message, authorization=nil, fraud_status=nil)
        ActiveMerchant::Billing::Response.new(
          true,
          message,
          response.body || {},
          {
            authorization:,
            fraud_status:,
            response_http_code: response.http_response&.code,
            request_endpoint: response.request_endpoint,
            request_method: response.request_method,
            request_body: response.request_body,
            response_type: get_response_type(response)
          }
        )
      end

      def generate_failure_response(response)
        ActiveMerchant::Billing::Response.new(
          false,
          response.error_code.to_s,
          response.body || {},
          {
            error_code: response.error_code,
            response_http_code: response.http_response&.code,
            request_endpoint: response.request_endpoint,
            request_method: response.request_method,
            request_body: response.request_body,
            response_type: get_response_type(response)
          }
        )
      end

      def get_response_type(response)
        code = response.code&.to_i
        if code == 200
          0
        elsif (500..599).include? code
          1
        else
          2
        end
      end

      def prepare_line_items(post, options)
        return unless options[:order_line_items].present?

        post["order_lines"] = options[:order_line_items].map do |item|
          {
            "name" => item["name"],
            "quantity" => item["quantity"],
            "total_amount" => item["final_amount"].to_f,
            "unit_price" => item["price"].to_f
          }
        end
      end

      def prepare_billing_address(post, options)
        return unless options[:billing_address].present?

        post["billing_address"] = {}
        post["billing_address"]["street_address"] = options[:billing_address][:address1]
        post["billing_address"]["street_address2"] = options[:billing_address][:address2]
        post["billing_address"]["organization_name"] = options[:billing_address][:company]
        post["billing_address"]["city"] = options[:billing_address][:city]
        post["billing_address"]["region"] = options[:billing_address][:state]
        post["billing_address"]["postal_code"] = options[:billing_address][:zip]
        post["billing_address"]["country"] = options[:billing_address][:country]
      end

      def prepare_shipping_address(post, options)
        return unless options[:shipping_address].present?

        post["shipping_address"] = {}
        post["shipping_address"]["street_address"] = options[:shipping_address][:address1]
        post["shipping_address"]["street_address2"] = options[:shipping_address][:address2]
        post["shipping_address"]["organization_name"] = options[:shipping_address][:company]
        post["shipping_address"]["city"] = options[:shipping_address][:city]
        post["shipping_address"]["region"] = options[:shipping_address][:state]
        post["shipping_address"]["postal_code"] = options[:shipping_address][:zip]
        post["shipping_address"]["country"] = options[:shipping_address][:country]
      end

      def prepare_order_data(post, options)
        post["auto_capture"] = true
        post["intent"] = "buy_and_tokenize"
        post["purchase_country"] = options.dig(:billing_address, :country) || options.dig(:shipping_country, :country)
        post["purchase_currency"] = options[:currency]
        post["order_amount"] = options[:total]&.to_f
      end

      def prepare_customer_data(post, options)
        post["purchase_country"] = options.dig(:billing_address, :country) || options.dig(:shipping_country, :country)
        post["purchase_currency"] = options[:currency]
        post["intended_use"] = "SUBSCRIPTION"
        post["description"] = "For Recurring Payments"
        post["locale"] = "en-GB"
      end
    end
  end
end
