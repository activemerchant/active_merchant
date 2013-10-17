require 'active_merchant/billing/integrations/netgiro/response_fields'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Netgiro
        class Return < ActiveMerchant::Billing::Integrations::Return
          include ResponseFields
        end
      end
    end
  end
end
