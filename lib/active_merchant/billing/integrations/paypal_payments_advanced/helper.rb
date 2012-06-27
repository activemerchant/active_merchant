module ActiveMerchant
  module Billing
    module Integrations
      module PaypalPaymentsAdvanced
        class Helper < PayflowLink::Helper

          def initialize(order, account, options)
            super
            add_field('partner', 'PayPal')
          end
        end
      end
    end
  end
end