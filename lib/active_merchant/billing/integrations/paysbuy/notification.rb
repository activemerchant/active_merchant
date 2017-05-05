module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paysbuy
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          SUCCESS = '00'
          FAIL = '99'
          PENDING = '02'

          def complete?
            status == 'Completed'
          end

          def item_id
            params['result'][2..-1]
          end

          def status
            status_code = params['result'][0..1]
            case status_code
            when SUCCESS
              'Completed'
            when FAIL
              'Failed'
            when PENDING
              'Pending'
            else
              raise "Unknown status code"
            end
          end

          def acknowledge(authcode = nil)
            true
          end
        end
      end
    end
  end
end
