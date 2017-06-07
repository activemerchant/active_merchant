module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paysbuy
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :account, 'biz'
          mapping :amount, 'amt'
          mapping :order, 'inv'
          mapping :description, 'itm'
          mapping :notify_url, 'postURL'
        end
      end
    end
  end
end
