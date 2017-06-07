module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Rbkmoney
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :account, 'eshopId'
          mapping :amount, 'recipientAmount'

          mapping :currency, 'recipientCurrency'
          # NOTE: rbkmoney uses outdated currency code 'RUR'

          mapping :order, 'orderId'

          mapping :customer, :email => 'user_email'

          mapping :credential2, 'serviceName'
          mapping :credential3, 'successUrl'
          mapping :credential4, 'failUrl'
        end
      end
    end
  end
end
