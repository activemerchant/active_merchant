module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module A1agregator
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          # public key
          mapping :account, 'key'

          mapping :amount, 'cost'

          mapping :order, 'order_id'

          mapping :customer, :email => 'email',
                             :phone => 'phone_number'

           # payment description
          mapping :credential2, 'name'

          mapping :credential3, 'comment'

          # on error
          # 1 - raise error
          # 0 - redirect
          mapping :credential4, 'verbose'

        end
      end
    end
  end
end
