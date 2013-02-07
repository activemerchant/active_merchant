require 'net/http'
require 'base64'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module TwoCheckout
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          # card_holder_name - Provides the customer’s name.
          # city - Provides the customer’s city.
          # country - Provides the customer’s country.
          # credit_card_processed - This parameter will always be passed back as Y.
          # demo - Defines if an order was live, or if the order was a demo order. If the order was a demo, the MD5 hash will fail.
          # email - Provides the email address the customer provided when placing the order.
          # fixed - This parameter will only be passed back if it was passed into the purchase routine.
          # ip_country - Provides the customer’s IP location.
          # key - An MD5 hash used to confirm the validity of a sale.
          # lang - Customer language
          # merchant_order_id - The order ID you had assigned to the order.
          # order_number - The 2Checkout order number associated with the order.
          # invoice_id - The 2Checkout invoice number.
          # pay_method - Provides seller with the customer’s payment method. CC for Credit Card, PPI for PayPal.
          # phone - Provides the phone number the customer provided when placing the order.
          # ship_name - Provides the ship to name for the order.
          # ship_street_address - Provides ship to address.
          # ship_street_address2 - Provides more detailed shipping address if this information was provided by the customer.
          # ship_city - Provides ship to city.
          # ship_state - Provides ship to state.
          # ship_zip - Ship Zip

          # Pass Through Products Only
          # li_#_name - Name of the corresponding lineitem.
          # li_#_quantity - Quantity of the corresponding lineitem.
          # li_#_price - Price of the corresponding lineitem.
          # li_#_tangible - Specifies if the corresponding li_#_type is a tangible or intangible. ‘Y’ OR ‘N’
          # li_#_product_id - ID of the corresponding lineitem.
          # li_#_product_description - Description of the corresponding lineitem.
          # li_#_recurrence - # WEEK | MONTH | YEAR – always singular.
          # li_#_duration - Forever or # WEEK | MONTH | YEAR – always singular, defaults to Forever.
          # li_#_startup_fee - Amount in account pricing currency.
          # li_#_option_#_name - Name of option. 64 characters max – cannot include '<' or '>'.
          # li_#_option_#_value - Name of option. 64 characters max – cannot include '<' or '>'.
          # li_#_option_#_surcharge - Amount in account pricing currency.

          #Third Party Cart Only
          # cart_order_id - The order ID you had assigned to the order.

          # Allow seller to define default currency (should match 2Checkout account pricing currency)
          def currency
              'USD'
          end

          def complete?
            status == 'Completed'
          end

          # Third Party Cart parameters will return 'card_order_id'
          # Pass Through Product parameters will only return 'merchant_order_id'
          def item_id
            if (params['cart_order_id'].nil?)
              params['merchant_order_id']
            else
              params['cart_order_id']
            end
          end

          # 2Checkout Sale ID
          def transaction_id
            params['order_number']
          end

          def received_at
            params['']
          end

          #Customer Email
          def payer_email
            params['email']
          end

          def receiver_email
            params['']
          end

          # The MD5 Hash
          def security_key
            params['key']
          end

          # The money amount we received in X.2 decimal.
          def gross
            params['total']
          end

          # Was this a test transaction? # Use the hash
          # Please note 2Checkout forces the order number computed in the hash to '1' on demo sales.
          def test?
            params['demo'] == 'Y'
          end

          # 2Checkout only returns 'Y' for this parameter. If the sale is not authorized, no passback occurs.
          def status
            case params['credit_card_processed']
              when 'Y'
                'Completed'
              else
                'Failed'
            end
          end

          # Secret Word defined in 2Checkout account
          def secret
            @options[:credential2]
          end

          # Checks against MD5 Hash
          def acknowledge
            return false if security_key.blank?

            Digest::MD5.hexdigest("#{secret}#{params['sid']}#{transaction_id}#{gross}").upcase == security_key.upcase
          end

          private

          # Parses Header Redirect Query String
          def parse(post)
            @raw = post.to_s
            for line in @raw.split('&')
              key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
              params[key] = CGI.unescape(value || '')
            end
          end

        end
      end
    end
  end
end
