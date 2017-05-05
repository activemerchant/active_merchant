module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Epayservice
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          def initialize(order, merchantnumber, options = {})
            super
            
          end
              

          mapping :merchantnumber, 'EPS_GUID'
          mapping :payment_id, 'payment_id'
          mapping :amount, 'EPS_AMOUNT'
          mapping :description, 'EPS_DESCRIPTION'
        
        end
      end
    end
  end
end

