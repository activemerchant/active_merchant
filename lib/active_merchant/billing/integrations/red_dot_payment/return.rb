require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module RedDotPayment
        class Return < ActiveMerchant::Billing::Integrations::Return
          def initialize(query_string, options = {})
            @notification = Notification.new(query_string, options)
          end

          def success?
            @notification.status == 'Paid' && @notification.acknowledge
          end
        end
      end
    end
  end
end
