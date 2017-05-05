module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Rbkmoney
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :account, 'eshopId'
          mapping :amount, 'recipientAmount'
          mapping :pay_method, 'preference'

          # NOTE: rbkmoney uses outdated currency code 'RUR'
          mapping :currency, 'recipientCurrency'

          mapping :order, 'orderId'

          mapping :email, 'user_email'

          mapping :credential2, 'serviceName'
          mapping :credential3, 'successUrl'
          mapping :credential4, 'failUrl'
          mapping :language, 'language'
        end
      end
    end
  end
end
