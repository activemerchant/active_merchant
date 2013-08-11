module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Citrus
        class Notification < ActiveMerchant::Billing::Integrations::Notification
      	  
      	  def initialize(post, options = {})
            super(post, options)
            @secret_key = options[:credential2]
          end

          def complete?
            status == "success" || status == 'canceled'
          end

          # Status of the transaction. List of possible values:
          # <tt>invalid</tt>:: transaction id is not present
          # <tt>tampered</tt>:: transaction data has been tampered
          # <tt>success</tt>:: transaction successful
          # <tt>canceled</tt>:: transaction is pending for some approval
          def status
            @status ||= if checksum_ok?
              if transaction_id.blank?
                'invalid'
              else
                transaction_status.downcase
              end
            else
              'tampered'
            end
          end

          def invoice_ok?( order_id )
            order_id.to_s == invoice.to_s
          end

          # Order amount should be equal to gross - discount
          def amount_ok?( order_amount )
            BigDecimal.new( amount ) == order_amount 
          end
		  
		  # capture Citrus response parameters
		  
		  # This is the invoice which you passed to Citrus
          def invoice
            params['TxId']
          end

          # Status of transaction return from the Citrus. List of possible values:
          # <tt>SUCCESS</tt>::
          # <tt>CANCELED</tt>::
          def transaction_status
            params['TxStatus']
          end
		  
          # amount paid by customer
          def amount
            params['amount']
          end
		  		
          # ID of this transaction returned by Citrus
          def transaction_id
            params['pgTxnNo']
          end
		  
		  # for future use	
          def issuerrefno
		  	params['issuerRefNo']
		  end

		  # authorization code by Citrus
		  def authidcode
		  	params['authIdCode']
		  end
		  
		  # gateway resp code by Citrus
		  def pgrespcode
		  	params['pgRespCode']
		  end
		  
		  # by Citrus
		  def checksum
            params['signature']
          end
		  
		  def paymentmode
		  	params['paymentMode']
		  end
		  
          # payment currency
          def currency
            params['currency']
          end

		  
          # Email of the customer
          def customer_email
            params['email']
          end

          # Phone of the customer
          def customer_phone
            params['mobileNo']
          end

          # Firstname of the customer
          def customer_first_name
            params['firstName']
          end

          # Lastname of the customer
          def customer_last_name
            params['lastName']
          end

          # Full address of the customer
          def customer_address
            { :address1 => params['addressStreet1'], :address2 => params['addressStreet2'],
              :city => params['addressCity'], :state => params['addressState'],
              :country => params['addressCountry'], :zip => params['addressZip'] }
          end


          def message
            @message || params['TxMsg']
          end
          
          def acknowledge
            checksum_ok?
          end

          def checksum_ok?
            fields = invoice + transaction_status + amount.to_s + transaction_id + issuerrefno + authidcode + customer_first_name + customer_last_name + pgrespcode + customer_address[:zip]
            
            unless Citrus.checksum(@secret_key, fields ) == checksum
              @message = 'checksum mismatch...'
              return false
            end
            true
          end
        end
      end
    end
  end
end
