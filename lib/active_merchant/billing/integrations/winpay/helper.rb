module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Winpay
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          mapping :id, 'id'
          mapping :phone, 'phone'
          mapping :goodphone, 'goodphone'
          mapping :smstext, 'smstext'
          mapping :control, 'control'
          mapping :result, 'result'

        end
      end
    end
  end
end