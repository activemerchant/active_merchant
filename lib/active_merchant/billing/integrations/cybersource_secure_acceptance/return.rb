module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CybersourceSecureAcceptance
        class Return < ActiveMerchant::Billing::Integrations::Return

          def initialize(post_data, options = {})
            @notification = Notification.new(post_data, options)
          end

          def success?
            notification.complete?
          end

          def cancelled?
            !success?
          end

          def message
            notification.message
          end
        end
      end
    end
  end
end
