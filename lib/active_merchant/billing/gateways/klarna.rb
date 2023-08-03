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
        Klarna.client(:payment).create_session(options)
      end

      def update_session(session_id, options)
        Klarna.client(:payment).update_session(session_id, options)
      end

      def purchase(amount, authorize_token, options = {})
        auth_response = authorize(amount, authorize_token, options)
      end

      def authorize(amount, authorize_token, options={})
        response = Klarna.client(:payment).place_order(authorize_token, options)

        if response.success?
          ActiveMerchant::Billing::Response.new(
            true,
            "Placed order #{response.order_id}",
            response.body,
            {
              authorization: response.order_id,
              fraud_review: response.fraud_status
            }
          )
        else
          ActiveMerchant::Billing::Response.new(
            false,
            response.error_code.to_s,
            response.body,
            {
              error_code: response.error_code
            }
          )
        end
      end

      def store(authorize_token, options = {})
        Klarna.client(:payment).customer_token(authorize_token, options)
      end

      def capture(amount, order_id, options={})
        response = Klarna.client.capture(order_id, {captured_amount: amount, shipping_info: options[:shipping_info]})

        if response.success?
          capture_id = response['Capture-ID']

          ActiveMerchant::Billing::Response.new(
            true,
            "Captured order with Klarna id: '#{order_id}' Capture id: '#{capture_id}'",
            response.body || {},
            {
              authorization: order_id
            }
          )
        else
          ActiveMerchant::Billing::Response.new(
            false,
            response.error_code.to_s,
            response.body || {},
            {
              error_code: response.error_code
            }
          )
        end
      end

      def refund(amount, order_id, options={})
        # Get the refunded line items for better customer communications
        response = Klarna.client(:refund).create(order_id, {refunded_amount: amount, order_lines: options[:order_lines]})

        if response.success?
          ActiveMerchant::Billing::Response.new(
            true,
            "Refunded order with Klarna id: #{order_id}",
            response.body || {},
            {
              authorization: response['Refund-ID']
            }
          )
        else
          ActiveMerchant::Billing::Response.new(
            false,
            'Klarna Gateway: There was an error refunding this refund.',
            response.body || {},
            { error_code: response.error_code }
          )
        end
      end

      alias_method :credit, :refund

      def get(order_id)
        Klarna.client.get(order_id)
      end

      def acknowledge(order_id)
        response = Klarna.client.acknowledge(order_id)

        if response.success?
          ActiveMerchant::Billing::Response.new(
            true,
            "Extended Period for order with Klarna id: #{order_id}",
            response.body || {}
          )
        else
          ActiveMerchant::Billing::Response.new(
            false,
            'Klarna Gateway: There was an error processing this acknowledge.',
            response.body || {},
            {
              error_code: response.error_code
            }
          )
        end
      end

      def extend_period(order_id)
        response = Klarna.client.extend(order_id)

        if response.success?
          ActiveMerchant::Billing::Response.new(
            true,
            "Extended Period for order with Klarna id: #{order_id}",
            response.body || {}
          )
        else
          ActiveMerchant::Billing::Response.new(
            false,
            'Klarna Gateway: There was an error processing this period extension.',
            response.body || {},
            {
              error_code: response.error_code
            }
          )
        end
      end

      def release(order_id)
        response = Klarna.client.release(order_id)

        if response.success?
          ActiveMerchant::Billing::Response.new(
            true,
            "Released reamining amount for order with Klarna id: #{order_id}",
            response.body || {},
            {
              authorization: order_id
            }
          )
        else
          ActiveMerchant::Billing::Response.new(
            false,
            'Klarna Gateway: There was an error processing this release.',
            response.body || {},
            {
              error_code: response.error_code
            }
          )
        end
      end

      def cancel(order_id)
        response = Klarna.client.cancel(order_id)

        if response.success?
          ActiveMerchant::Billing::Response.new(
            true,
            "Cancelled order with Klarna id: #{order_id}",
            response.body || {},
            {
              authorization: order_id
            }
          )
        else
          ActiveMerchant::Billing::Response.new(
            false,
            'Klarna Gateway: There was an error cancelling this payment.',
            response.body || {},
            { error_code: response.error_code }
          )
        end
      end

      def shipping_info(order_id, capture_id, shipping_info)
        response = Klarna.client(:capture).shipping_info(
          order_id,
          capture_id,
          shipping_info
        )
        if response.success?
          ActiveMerchant::Billing::Response.new(
            true,
            "Updated shipment info for order: #{order_id}, capture: #{capture_id}",
            response.body || {},
          )
        else
          ActiveMerchant::Billing::Response.new(
            false,
            "Cannot update the shipment info for order: #{order_id} capture: #{capture_id}",
            response.body || {},
            { error_code: response.error_code }
          )
        end
      end

      def customer_details(order_id, data)
        response = Klarna.client.customer_details(
          order_id,
          data
        )
        if response.success?
          ActiveMerchant::Billing::Response.new(
            true,
            "Updated customer details for order: #{order_id}",
            response.body || {},
          )
        else
          ActiveMerchant::Billing::Response.new(
            false,
            "Cannot update customer details for order: #{order_id}",
            response.body || {},
            { error_code: response.error_code }
          )
        end
      end
    end
  end
end
