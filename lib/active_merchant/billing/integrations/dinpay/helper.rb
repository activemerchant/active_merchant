module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dinpay
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          mapping :account, 'merchant_code'
          mapping :type, 'service_type'
          mapping :payment_id, 'order_no'
          mapping :charset, 'input_charset'
          mapping :interface_v, 'interface_version'
          mapping :sign_type, 'sign_type'
          mapping :notify_url, 'notify_url'
          mapping :time, 'order_time'
          mapping :name, 'product_name'
          mapping :sign, 'sign'
          mapping :amount, 'order_amount'

        end
      end
    end
  end
end
