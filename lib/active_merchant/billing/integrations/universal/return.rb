module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Universal
        class Return < ActiveMerchant::Billing::Integrations::Return
          def initialize(query_string, options = {})
            super
            @notification = Notification.new(query_string, options)
          end

          def success?
            @notification.acknowledge
          end
        end
      end
    end
  end
end
