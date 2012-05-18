module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module TwoCheckout
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            super
            add_field('fixed', 'Y')

            if ActiveMerchant::Billing::Base.integration_mode == :test || options[:test]
              add_field('demo', 'Y')
            end
          end

          # The 2checkout vendor account number
          mapping :account, 'sid'

          # The total amount to be billed, in decimal form, without a currency symbol. (8 characters, decimal, 2 characters: Example: 99999999.99)
          mapping :amount, 'total'

          # Pass your order id if you are using Third Part Cart Parameters. (128 characters max)
          mapping :order, 'cart_order_id'

          # Pass your order id if you are using the Pass Through Products Parameters.  (50 characters max)
          mapping :invoice, 'merchant_order_id'

          # Left here for backward compatibility, do not use. The line_item method will add automatically.
          mapping :mode, 'mode'

          mapping :customer, :email      => 'email',
                  :phone      => 'phone'

          mapping :billing_address, :city     => 'city',
                  :address1 => 'street_address',
                  :address2 => 'street_address2',
                  :state    => 'state',
                  :zip      => 'zip',
                  :country  => 'country'

          mapping :shipping_address, :city     => 'ship_city',
                  :address1 => 'ship_street_address',
                  :state    => 'ship_state',
                  :zip      => 'ship_zip',
                  :country  => 'ship_country'

          # Does nothing, since we've disabled the Continue Shopping button by using the fixed = Y field
          mapping :return_url, 'return_url'

          # Approved URL path
          mapping :notification_url, 'x_receipt_link_url'

          def customer(params = {})
            add_field(mappings[:customer][:email], params[:email])
            add_field(mappings[:customer][:phone], params[:phone])
            add_field('card_holder_name', "#{params[:first_name]} #{params[:last_name]}")
          end

          # Uses Pass Through Product Parameters to pass in lineitems.
          # (must mark tanigble sales as shipped to settle the transaction)
          def line_item(params = {})
            add_field('mode', '2CO')
            (max_existing_line_item_id = form_fields.keys.map do |key|
              i = key.to_s[/^li_(\d+)_/, 1]
              (i && i.to_i)
            end.compact.max || 0)

            line_item_id = max_existing_line_item_id + 1
            params.each do |key, value|
              add_field("li_#{line_item_id}_#{key}", value)
            end
          end

          # Uses Third Party Cart parameter set to pass in lineitem details.
          # (sales settle automatically)
          def auto_settle(params = {})
            add_field('id_type', '1')
            (max_existing_line_item_id = form_fields.keys.map do |key|
              i = key.to_s[/^c_prod_(\d+)/, 1]
              (i && i.to_i)
            end.compact.max || 0)

            line_item_id = max_existing_line_item_id + 1
            params.each do |key, value|
              add_field("c_#{key}_#{line_item_id}", value)
            end
          end
        end
      end
    end
  end
end
