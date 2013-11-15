module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayuIn
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          def initialize(post, options = {})
            super(post, options)
            @merchant_id = options[:credential1]
            @secret_key = options[:credential2]
          end

          def complete?
            status == "Completed"
          end

          def status
            case transaction_status.downcase
            when 'success' then 'Completed'
            when 'failure' then 'Failed'
            when 'pending' then 'Pending'
            end
          end

          def invoice_ok?( order_id )
            order_id.to_s == invoice.to_s
          end

          # Order amount should be equal to gross - discount
          def amount_ok?( order_amount, order_discount = BigDecimal.new( '0.0' ) )
            BigDecimal.new( gross ) == order_amount && BigDecimal.new( discount.to_s ) == order_discount
          end

          # Status of transaction return from the PayU. List of possible values:
          # <tt>SUCCESS</tt>::
          # <tt>PENDING</tt>::
          # <tt>FAILURE</tt>::
          def transaction_status
            params['status']
          end

          # ID of this transaction (PayU.in number)
          def transaction_id
            params['mihpayid']
          end

          # Mode of Payment
          #
          # 'CC' for credit-card
          # 'NB' for net-banking
          # 'CD' for cheque or DD
          # 'CO' for Cash Pickup
          def type
            params['mode']
          end

          # What currency have we been dealing with
          def currency
            'INR'
          end

          def item_id
            params['txnid']
          end

          # This is the invoice which you passed to PayU.in
          def invoice
            params['txnid']
          end

          # Merchant Id provided by the PayU.in
          def account
            params['key']
          end

          # original amount send by merchant
          def gross
            params['amount']
          end

          # This is discount given to user - based on promotion set by merchants.
          def discount
            params['discount']
          end

          # Description offer for what PayU given the offer to user - based on promotion set by merchants.
          def offer_description
            params['offer']
          end

          # Information about the product as send by merchant
          def product_info
            params['productinfo']
          end

          # Email of the customer
          def customer_email
            params['email']
          end

          # Phone of the customer
          def customer_phone
            params['phone']
          end

          # Firstname of the customer
          def customer_first_name
            params['firstname']
          end

          # Lastname of the customer
          def customer_last_name
            params['lastname']
          end

          # Full address of the customer
          def customer_address
            { :address1 => params['address1'], :address2 => params['address2'],
              :city => params['city'], :state => params['state'],
              :country => params['country'], :zipcode => params['zipcode'] }
          end

          def user_defined
            @user_defined ||= 10.times.map { |i| params["udf#{i + 1}"] }
          end

          def checksum
            params['hash']
          end

          def message
            @message || params['error']
          end

          def acknowledge(authcode = nil)
            checksum_ok?
          end

          def checksum_ok?
            checksum_fields = [transaction_status, *user_defined.reverse, customer_email, customer_first_name, product_info, gross, invoice]

            unless Digest::SHA512.hexdigest([@secret_key, *checksum_fields, @merchant_id].join("|")) == checksum
              @message = 'Return checksum not matching the data provided'
              return false
            end
            true
          end

        end
      end
    end
  end
end

