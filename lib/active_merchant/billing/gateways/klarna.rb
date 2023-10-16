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
        response = Klarna.client(:payment).create_session(options)

        if response.success?
          message = "Session Created #{response.session_id}"
          generate_success_response(response, message)
        else
          generate_failure_response(response)
        end
      end

      def update_session(session_id, options)
        response = Klarna.client(:payment).update_session(session_id, options)

        if response.success?
          message = "Session Updated #{session_id}"
          generate_success_response(response, message)
        else
          generate_failure_response(response)
        end
      end

      def purchase(amount, authorize_token, options={})
        auth_response = authorize(amount, authorize_token, options)
        if auth_response.success?
          capture(amount, auth_response.params["authorization"], options)
        else
          auth_response
        end
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

      def store(authorize_token, options={})
        response = Klarna.client(:payment).customer_token(authorize_token, options)

        if response.success?
          message = "Client token Created"
          generate_success_response(response, message)
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
        response = Klarna.client(:refund).create(order_id, {refunded_amount: amount, order_lines: options[:order_lines]})

        if response.success?
          message = "Refunded order with Klarna id: #{order_id}"
          generate_success_response(response, message, response['Refund-ID'])
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
    end
  end
end
