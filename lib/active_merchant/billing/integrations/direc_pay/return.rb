module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:

      module DirecPay
        class Return < ActiveMerchant::Billing::Integrations::Return
          
          def initialize(post_data, options = {})
            @notification = Notification.new(treat_failure_as_pending(post_data), options)
          end

          def success?
            notification.complete?
          end
          
          def message
            notification.status
          end
          
          
          private
          
          # Work around the issue that the initial return from DirecPay is always either SUCCESS or FAIL, there is no PENDING
          def treat_failure_as_pending(post_data)
            post_data.sub(/FAIL/, 'PENDING')
          end
        end
      end
      
    end
  end
end
