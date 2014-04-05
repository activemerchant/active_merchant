module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Mobikwikwallet
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          def initialize(post, options = {})
            super(post, options)
            @secret_key = options[:credential3]
          end

          def complete?
            status == "Completed"
          end

          def status
            @status ||= if checksum_ok?
              if transaction_id.blank?
                'Invalid'
              else
                case statuscode
                when '0' then 'Completed'
                else 'Failed'
                end
              end
            else
              'Tampered'
            end
          end

          def merchantid
            params['mid']
          end

          def item_id
            params['orderid']
          end

          def transaction_id
            params['orderid']
          end
          
          def invoice
            params['orderid']
          end

          def checksum
            params['checksum']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['amount']
          end

          def statuscode
            params['statuscode']
          end

          def statusmessage
            params['statusmessage']
          end

          def amount
            gross
          end

          def invoice_ok?( order_id )
            order_id.to_s == invoice.to_s
          end

          def amount_ok?( order_amount )
            BigDecimal.new( amount ) == order_amount
          end

          def message
            @message || statusmessage
          end

          def checksum_ok?
            @fields = "'" + statuscode + "''" + invoice + "''" + amount + "''" + statusmessage + "''" + merchantid + "'"

            unless Mobikwikwallet.checksum(@secret_key, @fields) == checksum
              @message = 'checksum mismatch...'
              return false
            end
            true
          end
   
          def acknowledge(authcode = nil)
            checksum_ok?
          end          
        end
      end
    end
  end
end
