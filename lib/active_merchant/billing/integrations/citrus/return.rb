module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Citrus
        class Return < ActiveMerchant::Billing::Integrations::Return

          def initialize(query_string, options = {})
            super
            @notification = Notification.new(query_string, options)
          end

          # PayU Transaction Id
          #
          def transaction_id
            @notification.transaction_id
          end

         
          def status( order_id, order_amount )
            if @notification.invoice_ok?( order_id ) && @notification.amount_ok?( BigDecimal.new(order_amount) )
              @notification.status
            else
              'mismatch'
            end
          end

          # check success of the transaction
          # check order_id and
          def success?
            status( @params['txnid'], @params['amount'] ) == 'success'
          end

          def message
            @notification.message
          end

        end
      end
    end
  end
end