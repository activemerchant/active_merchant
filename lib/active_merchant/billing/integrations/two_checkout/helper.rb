module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module TwoCheckout
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            super
            if ActiveMerchant::Billing::Base.integration_mode == :test || options[:test]
              add_field('demo', 'Y')
            end
          end

          # The 2checkout vendor account number
          mapping :account, 'sid'

          # The total amount to be billed, in decimal form, without a currency symbol. (8 characters, decimal, 2 characters: Example: 99999999.99)
          # This field is only used with the Third Party Cart parameter set.
          mapping :amount, 'total'

          # Pass the sale's currency code.
          mapping :currency, 'currency_code'

          # Pass your order id.  (50 characters max)
          mapping :order, 'merchant_order_id'

          # Pass your cart identifier if you are using Third Part Cart Parameters. (128 characters max)
          # This value is visible to the buyer and will be listed as the sale's lineitem.
          mapping :invoice, 'cart_order_id'

          mapping :customer,
                  :email      => 'email',
                  :phone      => 'phone'

          mapping :billing_address,
                  :city     => 'city',
                  :address1 => 'street_address',
                  :address2 => 'street_address2',
                  :state    => 'state',
                  :zip      => 'zip',
                  :country  => 'country'

          mapping :shipping_address,
                  :name     => 'ship_name',
                  :city     => 'ship_city',
                  :address1 => 'ship_street_address',
                  :address2 => 'ship_street_address2',
                  :state    => 'ship_state',
                  :zip      => 'ship_zip',
                  :country  => 'ship_country'

          # Overrides Approved URL for return process redirects
          mapping :return_url, 'x_receipt_link_url'

          # notifications are sent via static URLs in the Instant Notification Settings of 2Checkout admin
          mapping :notify_url, 'notify_url'

          # Allow seller to indicate the step of the checkout page
          # Possible values: ‘review-cart’, ‘shipping-information’, ‘shipping-method’, ‘billing-information’ and ‘payment-method’
          mapping :purchase_step, 'purchase_step'

          # Allow referral partners to indicate their shopping cart
          mapping :cart_type, '2co_cart_type'

          def customer(params = {})
            add_field(mappings[:customer][:email], params[:email])
            add_field(mappings[:customer][:phone], params[:phone])
            add_field('card_holder_name', "#{params[:first_name]} #{params[:last_name]}")
          end

          def shipping_address(params = {})
            super
            add_field(mappings[:shipping_address][:name], "#{params[:first_name]} #{params[:last_name]}")
          end

          # Uses Third Party Cart parameter set to pass in lineitem details.
          # You must also specify `service.invoice` when using this method.
          def third_party_cart(params = {})
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
