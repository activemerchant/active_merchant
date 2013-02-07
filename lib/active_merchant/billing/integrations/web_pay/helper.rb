module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WebPay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include Common

          def initialize(order, account, options = {})
            @md5secret = options.delete(:secret)
            @line_item_count = 0
            super
          end

          def form_fields
            @fields.merge(ActiveMerchant::Billing::Integrations::WebPay.signature_parameter_name => generate_signature(:request))
          end

          def params
            @fields
          end

          def secret
            @md5secret
          end

          def add_line_item(options)
            options.each do |key, value|
              add_field("wsb_invoice_item_#{key}[#{@line_item_count}]", value)
            end

            @line_item_count += 1
          end

          def calculate_total
            sum = 0

            @line_item_count.times do |i|
              sum += @fields["wsb_invoice_item_quantity[#{i}]"].to_i * @fields["wsb_invoice_item_price[#{i}]"].to_i
            end

            sum + @fields[mappings[:tax]].to_i + @fields[mappings[:shipping_price]].to_i - @fields[mappings[:discount_price]].to_i
          end

          mapping :scart, '*scart'
          mapping :account, 'wsb_storeid'
          mapping :store, 'wsb_store'
          mapping :order, 'wsb_order_num'
          mapping :currency, 'wsb_currency_id'
          mapping :version, 'wsb_version'
          mapping :language, 'wsb_language_id'
          mapping :seed, 'wsb_seed'
          mapping :success_url, 'wsb_return_url'
          mapping :cancel_url, 'wsb_cancel_return_url'
          mapping :notify_url, 'wsb_notify_url'
          mapping :test, 'wsb_test'
          mapping :tax, 'wsb_tax'
          mapping :shipping_name, 'wsb_shipping_name'
          mapping :shipping_price, 'wsb_shipping_price'
          mapping :discount_name, 'wsb_discount_name'
          mapping :discount_price, 'wsb_discount_price'
          mapping :amount, 'wsb_total'
          mapping :email, 'wsb_email'
          mapping :phone, 'wsb_phone'
        end
      end
    end
  end
end
