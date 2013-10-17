require 'active_merchant/billing/integrations/netgiro/response_fields'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Netgiro
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include ResponseFields
        end
      end
    end
  end
end
