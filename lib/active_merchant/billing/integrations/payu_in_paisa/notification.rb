module ActiveMerchant
  module Billing
    module Integrations
      module PayuInPaisa
        class Notification < PayuIn::Notification
          def item_id
            params['udf2']
          end
        end
      end
    end
  end
end
