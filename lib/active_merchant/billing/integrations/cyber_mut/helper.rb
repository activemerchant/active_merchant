module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CyberMut
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            super
            add_field('version', '3.0')
          end

          mapping :account, 'account'
          mapping :amount, 'amount'

          mapping :order, 'order'

          mapping :url_retour, 'url_retour'
          mapping :url_retour_ok, 'url_retour_ok'
          mapping :url_retour_err, 'url_retour_err'
        end
      end
    end
  end
end
