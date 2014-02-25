module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Interkassa
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          mapping :account, 'ik_co_id'
          mapping :order, 'ik_pm_no'
          mapping :amount, 'ik_am'
          mapping :description, 'ik_desc'
          mapping :action, 'ik_act'
          mapping :payment_alias, 'ik_pw_via'
          mapping :currency, 'ik_cur'
        end
      end
    end
  end
end