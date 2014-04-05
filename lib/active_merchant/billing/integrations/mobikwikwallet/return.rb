module ActiveMerchant
  module Billing
    module Integrations
      module Mobikwikwallet
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
              'Tampered'
            end
          end

          def success?
            status( @params['orderid'], @params['amount'] ) == 'Completed'
          end

          def message
            @notification.message
          end

        end
      end
    end
  end
end
