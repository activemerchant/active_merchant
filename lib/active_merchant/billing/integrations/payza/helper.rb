module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Payza
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :account, 'ap_merchant'
          mapping :amount, 'ap_amount'
          mapping :currency, 'ap_currency'
          mapping :order, 'ap_itemcode'
          mapping :notify_url, 'ap_alerturl'
          mapping :return_url, 'ap_returnurl'
          mapping :cancel_return_url, 'ap_cancelurl'
          mapping :description, 'ap_itemname'
        end
      end
    end
  end
end
