require 'active_merchant/billing/integrations/chronopay/helper.rb'
require 'active_merchant/billing/integrations/chronopay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Chronopay
        mattr_accessor :service_url
        self.service_url = 'https://secure.chronopay.com/index_shop.cgi'

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
