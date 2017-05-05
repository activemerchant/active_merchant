module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Cardpay
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          mapping :order_xml, 'orderXML'
          mapping :sha512, 'sha512'

        end
      end
    end
  end
end