module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Yandex
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            @secret = options.delete(:secret)
            super
          end

          mapping :account, 'ShopID'
          mapping :amount, 'Sum'
          mapping :order, 'orderNumber'
          mapping :customer, 'customerNumber'
          mapping :scid, 'scid'
        end
      end
    end
  end
end
