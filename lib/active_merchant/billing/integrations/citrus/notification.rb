module ActiveMerchant
  module Billing
    module Integrations
      module Citrus
        class Notification < ActiveMerchant::Billing::Integrations::Notification

      	  def initialize(post, options = {})
            super(post, options)
            @secret_key = options[:credential2]
          end

          def complete?
            status == "Completed" || status == 'Canceled'
          end

          def status
            @status ||= if checksum_ok?
              if transaction_id.blank?
                'Invalid'
              else
                case transaction_status.downcase
                when 'success' then 'Completed'
                when 'canceled' then 'Cancelled'
                end
              end
            else
              'Tampered'
            end
          end

          def invoice_ok?( order_id )
            order_id.to_s == invoice.to_s
          end

          def amount_ok?( order_amount )
            BigDecimal.new( amount ) == order_amount
          end

          def item_id
            params['TxId']
          end

          def invoice
            item_id
          end

          # Status of transaction return from the Citrus. List of possible values:
          # <tt>SUCCESS</tt>::
          # <tt>CANCELED</tt>::
          def transaction_status
            params['TxStatus']
          end

          def gross
            params['amount']
          end

          def amount
            gross
          end

          def transaction_id
            params['pgTxnNo']
          end

          def issuerrefno
            params['issuerRefNo']
          end

          def authidcode
            params['authIdCode']
          end

          def pgrespcode
            params['pgRespCode']
          end

          def checksum
            params['signature']
          end

          def paymentmode
            params['paymentMode']
          end

          def currency
            params['currency']
          end

          def customer_email
            params['email']
          end

          def customer_phone
            params['mobileNo']
          end

          def customer_first_name
            params['firstName']
          end

          def customer_last_name
            params['lastName']
          end

          def customer_address
            { :address1 => params['addressStreet1'], :address2 => params['addressStreet2'],
              :city => params['addressCity'], :state => params['addressState'],
              :country => params['addressCountry'], :zip => params['addressZip'] }
          end

          def message
            @message || params['TxMsg']
          end

          def acknowledge(authcode = nil)
            checksum_ok?
          end

          def checksum_ok?
            fields = [invoice, transaction_status, amount.to_s, transaction_id, issuerrefno, authidcode, customer_first_name, customer_last_name, pgrespcode, customer_address[:zip]].join

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
