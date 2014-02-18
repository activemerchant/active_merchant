module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paydollar
        class Return < ActiveMerchant::Billing::Integrations::Return

          def success?
            @params.has_key?('Ref')
          end

        end
      end
    end
  end
end
