module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Pxpay
        class Return < ActiveMerchant::Billing::Integrations::Return
          def initialize(query_string, options={})
            @notification = Notification.new(query_string, options)
          end

          def success?
            @notification && @notification.complete?
          end

          def cancelled?
            @notification && @notification.cancelled?
          end

          def message
            @notification.message
          end
        end
      end
    end
  end
end
