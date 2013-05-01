module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayuIn
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          # Was the transaction complete?
          def complete?
            status == "success"
          end

          # Status of the transaction. List of possible values:
          # <tt>invalid</tt>:: transaction id is not present
          # <tt>tampered</tt>:: transaction data has been tampered
          # <tt>success</tt>:: transaction successful
          # <tt>pending</tt>:: transaction is pending for some approval
          # <tt>failure</tt>:: transaction failure
          def status
            @status ||= if checksum_ok?
              if transaction_id.blank?
                'invalid'
              else
                transaction_status.downcase
              end
            else
              'tampered'
            end.freeze
          end

          def invoice_ok?( order_id )
            order_id.to_s == invoice.to_s
          end

          # Order amount should be equal to gross - discount
          def amount_ok?( order_amount, order_discount = BigDecimal.new( '0.0' ) )
            BigDecimal.new( gross ) == order_amount && BigDecimal.new( discount ) == order_discount
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
            return @user_defined if @user_defined
            @user_defined = []
            10.times{ |i| @user_defined.push( params[ "udf#{i+1}" ] ) }
            @user_defined
          end

          def checksum
            params['hash']
          end

          def message
            @message || params['error']
          end

          def checksum_ok?
            fields = user_defined.dup.push( customer_email, customer_first_name, product_info, gross, invoice, :reverse => true )
            fields.unshift( transaction_status )
            unless PayuIn.checksum( *fields ) == checksum
              @message = 'Return checksum not matching the data provided'
              return false
            end
            return true
          end

        end
      end
    end
  end
end

