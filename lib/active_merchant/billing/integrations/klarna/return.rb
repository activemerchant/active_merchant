module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Klarna
        class Return < ActiveMerchant::Billing::Integrations::Return
          def success?
            true
          end
        end
      end
    end
  end
end
