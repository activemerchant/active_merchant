module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paysbuy
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          SUCCESS = '00'
          FAIL = '99'

          def complete?
            status == 'complete'
          end

          def item_id
            params['result'][2..-1]
          end

          def status
            params['result'][0..1] == SUCCESS ? 'complete' : 'fail'
          end
        end
      end
    end
  end
end
