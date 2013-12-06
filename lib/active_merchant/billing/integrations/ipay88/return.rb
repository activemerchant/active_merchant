require "digest/sha1"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ipay88
        class Return < ActiveMerchant::Billing::Integrations::Return

          def initialize(query_string, options = {})
            super
            @notification = Notification.new(query_string, options)
          end

          def success?
            params["Status"] == "1"
          end

          def cancelled?
            params["ErrDesc"] == 'Customer Cancel Transaction'
          end

          def message
            params["ErrDesc"]
          end
        end
      end
    end
  end
end
