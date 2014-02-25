module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Payonline
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :account, 'MerchantId'
          mapping :amount, 'Amount'
          mapping :currency, 'Currency'
          mapping :order, 'OrderId'
          mapping :return_url, 'ReturnUrl'
          mapping :fail_url, 'FailUrl'
          mapping :security_key, 'SecurityKey'
        end
      end
    end
  end
end