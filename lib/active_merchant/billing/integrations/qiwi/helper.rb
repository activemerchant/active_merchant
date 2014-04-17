module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Qiwi
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          mapping :account, 'account'
          mapping :amount, 'amount'
          mapping :order, 'id'

          def form_method
            'GET'
          end
        end
      end
    end
  end
end
