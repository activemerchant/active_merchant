module ActiveMerchant
  module Billing
    module Integrations
      module PayuInPaisa

        class Helper < PayuIn::Helper
          mapping :service_provider, 'service_provider'

          def initialize(order, account, options = {})
            super
            self.service_provider = 'payu_paisa'
            self.user_defined = { :var2 => order }
          end
        end

      end
    end
  end
end
