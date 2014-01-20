require 'net/http'
require 'base64'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module TwoCheckout
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          # message_type - Indicates type of message
          # message_description	- Human readable description of message_type
          # timestamp - Timestamp of event; format YYYY-MM-DD HH:MM:SS ZZZ
          # md5_hash - UPPERCASE(MD5_ENCRYPTED(sale_id + vendor_id + invoice_id + Secret Word))
          # message_id - This number is incremented for each message sent to a given seller.
          # key_count - Indicates the number of parameters sent in message
          # vendor_id - Seller account number
          # sale_id - 2Checkout sale number
          # sale_date_placed - Date of sale; format YYYY-MM-DD
          # vendor_order_id - Custom order id provided by seller, if available.
          # invoice_id - 2Checkout invoice number; Each recurring sale can have several invoices
          # recurring - recurring=1 if any item on the invoice is a recurring item, 0 otherwise
          # payment_type - Buyer’s payment method (credit card, online check, paypal ec, OR paypal pay later)
          # list_currency - 3-Letter ISO code for seller currency
          # cust_currency - 3-Letter ISO code for buyer currency
          # auth_exp - The date credit authorization will expire; format YYYY-MM-DD
          # invoice_status - Status of a transaction (approved, pending, deposited, or declined)
          # fraud_status - Status of 2Checkout fraud review (pass, fail, or wait); This parameter could be empty.
          # invoice_list_amount - Total in seller pricing currency; format as appropriate to currency=
          # invoice_usd_amount - Total in US Dollars; format with 2 decimal places
          # invoice_cust_amount - Total in buyer currency; format as appropriate to currency=
          # customer_first_name - Buyer’s first name (may not be available on older sales)
          # customer_last_name - Buyer’s last name (may not be available on older sales)
          # customer_name - Buyer's full name (name as it appears on credit card)
          # customer_email - Buyer's email address
          # customer_phone - Buyer's phone number; all but digits stripped out
          # customer_ip - Buyer's IP address at time of sale
          # customer_ip_country - Country of record for buyer's IP address at time of sale
          # bill_street_address - Billing street address
          # bill_street_address2 - Billing street address line 2
          # bill_city - Billing address city
          # bill_state - Billing address state or province
          # bill_postal_code - Billing address postal code
          # bill_country - 3-Letter ISO country code of billing address
          # ship_status - not_shipped, shipped, or empty (if intangible / does not need shipped)
          # ship_tracking_number - Tracking Number as entered in Seller Admin
          # ship_name - Shipping Recipient’s name (as it should appears on shipping label)
          # ship_street_address - Shipping street address
          # ship_street_address2 - Shipping street address line 2
          # ship_city - Shipping address city
          # ship_state - Shipping address state or province
          # ship_postal_code - Shipping address postal code
          # ship_country - 3-Letter ISO country code of shipping address
          # item_count - Indicates how many numbered sets of item parameters to expect
          # item_name_# - Product name
          # item_id_# - Seller product id
          # item_list_amount_# - Total in seller pricing currency; format as appropriate to currency
          # item_usd_amount_# - Total in US Dollars; format with 2 decimal places
          # item_cust_amount_# - Total in buyer currency; format as appropriate to currency
          # item_type_# - Indicates if item is a bill or refund; Value will be bill or refund
          # item_duration_# - Product duration, how long it re-bills for Ex. 1 Year
          # item_recurrence_# - Product recurrence, how often it re-bills Ex. 1 Month
          # item_rec_list_amount_# - Product price; format as appropriate to currency
          # item_rec_status_# - Indicates status of recurring subscription: live, canceled, or completed
          # item_rec_date_next_# - Date of next recurring installment; format YYYY-MM-DD
          # item_rec_install_billed_# - The number of successful recurring installments successfully billed

          # INS message type
          def type
            params['message_type']
          end

          # Seller currency sale was placed in
          def currency
            params['list_currency']
          end

          def complete?
            status == 'Completed'
          end

          # The value passed with 'merchant_order_id' is passed back as 'vendor_order_id'
          def item_id
            params['vendor_order_id'] || params['merchant_order_id']
          end

          # 2Checkout Sale ID
          def transaction_id
            params['sale_id'] || params['order_number']
          end

          # 2Checkout Invoice ID
          def invoice_id
            params['invoice_id']
          end

          def received_at
            params['timestamp']
          end

          #Customer Email
          def payer_email
            params['customer_email']
          end

          # The MD5 Hash
          def security_key
            params['md5_hash'] || params['key']
          end

          # The money amount we received in X.2 decimal.
          # passback || INS gross amount for new orders || default INS gross
          def gross
            params['invoice_list_amount'] || params['total'] || params['item_list_amount_1']
          end

          # Determine status based on parameter set, if the params include a fraud status we know we're being
          # notified of the finalization of an order (an INS message)
          # If the params include 'credit_card_processed' we know we're being notified of a new order being inbound,
          # which we handle in the deferred demo sale scenario.
          def status
            if params['fraud_status'] == 'pass' || params['credit_card_processed'] == 'Y'
              'Completed'
            elsif params['fraud_status'] == 'wait'
              'Pending'
            else
              'Failed'
            end
          end

          # Secret Word defined in 2Checkout account
          def secret
            @options[:credential2]
          end

          # Checks against MD5 Hash
          def acknowledge(authcode = nil)
            return false if security_key.blank?
            if ins_message?
              Digest::MD5.hexdigest("#{ transaction_id }#{ params['vendor_id'] }#{ invoice_id }#{ secret }").upcase == security_key.upcase
            elsif passback?
              order_number = params['demo'] == 'Y' ? 1 : params['order_number']
              Digest::MD5.hexdigest("#{ secret }#{ params['sid'] }#{ order_number }#{ gross }").upcase == params['key'].upcase
            else
              false
            end
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

          def ins_message?
            params.include? 'message_type'
          end

          def passback?
            params.include? 'credit_card_processed'
          end
        end
      end
    end
  end
end
