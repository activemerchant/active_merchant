require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module HiTrust
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          SUCCESS = '00'
          
          def complete?
            status == 'Completed'
          end 

          def transaction_id
            params['authRRN']
          end
          
          def item_id
            params['ordernumber']
          end
          
          def received_at
            Time.parse(params['orderdate']) rescue nil
          end
          
          def currency
            params['currency']
          end

          def gross
            params['approveamount']
          end
          
          def gross_cents
            gross.to_i
          end
          
          def account
            params['storeid']
          end

          def status
            params['retcode'] == SUCCESS ? 'Completed' : 'Failed'
          end
          
          def test?
            ActiveMerchant::Billing::Base.integration_mode == :test
          end
    
          def acknowledge      
            true
          end
        end
      end
    end
  end
end
