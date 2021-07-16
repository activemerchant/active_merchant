require 'digital_river'

module ActiveMerchant
  module Billing
    class DigitalRiverGateway < Gateway
      def initialize(options = {})
        requires!(options, :token)
        super

        token = options[:token]
        @digital_river_gateway = DigitalRiver::Gateway.new(token, wiredump_device)
      end

      def store(payment_method, options = {})
        MultiResponse.new.tap do |r|
          if options[:customer_vault_token]
            r.process do
              check_customer_exists(options[:customer_vault_token])
            end
            return r unless r.responses.last.success?
            r.process do
              add_source_to_customer(payment_method, options[:customer_vault_token])
            end
          else
            r.process do
              create_customer(options)
            end
            return r unless r.responses.last.success?
            r.process do
              add_source_to_customer(payment_method, r.responses.last.authorization)
            end
          end
        end
      end

      def unstore(payment_method, options)
        customer_id = options[:customer_vault_token]
        result = @digital_river_gateway
          .customer
          .detach_source(
            customer_id,
            payment_method
          )
        ActiveMerchant::Billing::Response.new(
          result.success?,
          message_from_result(result),
          { customer_id: customer_id },
          authorization: customer_id
        )
      end

      def purchase(options)
        return failed_order_response(options) if options[:order_failure_message].present?
        return pending_order_with_success_response(options) if options[:success_pending_order].present? &&
                                                                 options[:source_id].present?

        MultiResponse.new.tap do |r|
          order_exists = nil
          r.process do
            order_exists = @digital_river_gateway.order.find(options[:order_id])
            ActiveMerchant::Billing::Response.new(
              order_exists.success?,
              message_from_result(order_exists),
              {
                order_id: (order_exists.value!.id if order_exists.success?)
              }
            )
          end
          return r unless order_exists.success?
          if order_exists.value!.state == 'accepted'
            r.process do
              create_fulfillment(options[:order_id], items_from_order(order_exists.value!.items))
            end
            return r unless r.responses.last.success?
            r.process do
              get_charge_capture_id(options[:order_id])
            end
          else
            return ActiveMerchant::Billing::Response.new(
              false,
              "Order not in 'accepted' state",
              {
                order_id: order_exists.value!.id,
                order_state: order_exists.value!.state
              },
              authorization: order_exists.value!.id
            )
          end
        end
      end

      def refund(money, _transaction_id, options)
        currency = options[:currency] || currency(money)
        params =
          {
            'order_id' => options[:order_id],
            'currency' => currency.upcase,
            'amount' => localized_amount(money, currency).to_f,
            'reason' => options[:memo],
            'metadata' => options[:metadata],
          }
        result = @digital_river_gateway.refund.create(params)

        ActiveMerchant::Billing::Response.new(
          result.success?,
          message_from_result(result),
          {
            refund_id: (result.value!.id if result.success?)
          }
        )
      end

      def get_charge_capture_id(order_id)
        charges = nil
        sources = nil
        retry_until(2, "charge not found", 0.5) do
          order = @digital_river_gateway.order.find(order_id).value!
          charges = order.payment.charges
          sources = order.payment.sources
          charges&.first.present?
        end

        # for now we assume only one charge will be processed at one order
        captures = nil
        retry_until(2, "capture not found", 0.5) do
          captures = @digital_river_gateway.charge.find(charges.first.id).value!.captures
          captures&.first.present?
        end
        ActiveMerchant::Billing::Response.new(
          true,
          "OK",
          {
            order_id: order_id,
            charge_id: charges.first.id,
            capture_id: captures.first.id,
            source_id: sources.detect { |s| s.type == 'creditCard' }.id
          },
          authorization: captures.first.id
        )
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(%r((Authorization: Bearer )\w+)i, '\1[FILTERED]\2')
      end

      private

      def create_fulfillment(order_id, items)
        fulfillment_params = { order_id: order_id, items: items }
        result = @digital_river_gateway.fulfillment.create(fulfillment_params)
        ActiveMerchant::Billing::Response.new(
          result.success?,
          message_from_result(result),
          {
            fulfillment_id: (result.value!.id if result.success?)
          }
        )
      end

      def add_source_to_customer(payment_method, customer_id)
        result = @digital_river_gateway
                   .customer
                   .attach_source(
                     customer_id,
                     payment_method
                   )
        ActiveMerchant::Billing::Response.new(
          result.success?,
          message_from_result(result),
          {
            customer_vault_token: (result.value!.customer_id if result.success?),
            payment_profile_token: (result.value!.id if result.success?)
          },
          authorization: (result.value!.customer_id if result.success?)
        )
      end

      def create_customer(options)
        params =
        {
          "email": options.dig(:email),
          "shipping": {
            "name": options.dig(:billing_address, :name),
            "organization": options.dig(:organization),
            "phone": options.dig(:phone),
            "address": {
              "line1": options.dig(:billing_address, :address1),
              "line2": options.dig(:billing_address, :address2),
              "city": options.dig(:billing_address, :city),
              "state": options.dig(:billing_address, :state),
              "postalCode": options.dig(:billing_address, :zip),
              "country": options.dig(:billing_address, :country),
            }
          }
        }
        result = @digital_river_gateway.customer.create(params)
        ActiveMerchant::Billing::Response.new(
          result.success?,
          message_from_result(result),
          {
            customer_vault_token: (result.value!.id if result.success?)
          },
          authorization: (result.value!.id if result.success?)
        )
      end

      def check_customer_exists(customer_vault_id)
        if @digital_river_gateway.customer.find(customer_vault_id).success?
          ActiveMerchant::Billing::Response.new(true, "Customer found", {exists: true}, authorization: customer_vault_id)
        else
          ActiveMerchant::Billing::Response.new(false, "Customer '#{customer_vault_id}' not found", {exists: false})
        end
      end

      def failed_order_response(options)
        ActiveMerchant::Billing::Response.new(
          false,
          options[:order_failure_message]
        )
      end

      def pending_order_with_success_response(options)
        ActiveMerchant::Billing::Response.new(
          true,
          "Order not in 'accepted' state",
          {
            order_id: options[:order_id],
            source_id: options[:source_id]
          },
          authorization: options[:order_id]
        )
      end

      def headers(options)
        {
          "Authorization" => "Bearer #{options[:token]}",
          "Content-Type" => "application/json",
        }
      end

      def message_from_result(result)
        if result.success?
          "OK"
        elsif result.failure?
          result.failure[:errors].map { |e| "#{e[:message]} (#{e[:code]})" }.join(" ")
        end
      end

      def items_from_order(items)
        items.map { |item| { itemId: item.id, quantity: item.quantity.to_i, skuId: item.sku_id } }
      end
    end
  end
end
