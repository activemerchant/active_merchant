require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dibs
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          def item_id
            params['orderid']
          end

          def transaction_id
            params['transaction']
          end

          # the money amount we received in X.2 decimal.
          def gross
            "%.2f" % (gross_cents / 100.0)
          end
          
          def gross_cents
            params['amount'].to_i
          end
          
          def currency
            params['currency']
          end

          def status
           params['status']
          end

      
          def acknowledge
            result = false
            if params['status'] == 'ACCEPTED'
              result = true
            end
            return result
          end
        end
      end
    end
  end
end
