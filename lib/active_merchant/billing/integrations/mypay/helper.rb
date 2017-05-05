module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Mypay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :user_id, 'clientid'
          mapping :wallet_id, 'account'
          mapping :payment_id, 'priceid'
          mapping :service_id, 'serviceid'
          mapping :amount, 'amount'
          mapping :locale, 'lang'
          mapping :successurl, 'successurl'
          mapping :failureurl, 'failureurl'
          mapping :params, 'params'
          mapping :order_id, 'orderid' 
        end
      end
    end
  end
end