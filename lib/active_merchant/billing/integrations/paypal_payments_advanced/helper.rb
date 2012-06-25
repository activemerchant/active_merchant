module ActiveMerchant
  module Billing
    module Integrations
      module PaypalPaymentsAdvanced
        class Helper < ActiveMerchant::Billing::Integrations::PayflowLink::Helper
          include PostsData

          def initialize(order, account, options)
            super
            add_field('partner', 'PayPal')
          end
        end
      end
    end
  end
end