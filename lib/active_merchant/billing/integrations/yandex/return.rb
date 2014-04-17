# -*- encoding : utf-8 -*-
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Yandex
        class Return < ActiveMerchant::Billing::Integrations::Return
          def item_id
            params['orderNumber']
          end
        end
      end
    end
  end
end