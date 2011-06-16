require 'active_merchant/billing/integrations/valitor/response_fields'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Valitor
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include ResponseFields
        end
      end
    end
  end
end
