module ActiveMerchant
  module Billing
    module Integrations
      module Citrus
        class Return < ActiveMerchant::Billing::Integrations::Return

          def initialize(query_string, options = {})
            super
            @notification = Notification.new(query_string, options)
          end

          def transaction_id
            @notification.transaction_id
          end

          def status( order_id, order_amount )
            if @notification.invoice_ok?( order_id ) && @notification.amount_ok?( BigDecimal.new(order_amount) )
              @notification.status
            else
              'Mismatch'
            end
          end

          def success?
            status( @params['TxId'], @params['amount'] ) == 'Completed'
          end

          def message
            @notification.message
          end

          def cancelled?
            @notification.status == 'Cancelled'
          end

        end
      end
    end
  end
end
