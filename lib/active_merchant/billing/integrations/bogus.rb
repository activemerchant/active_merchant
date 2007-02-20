require 'active_merchant/billing/integrations/bogus/helper.rb'
require 'active_merchant/billing/integrations/bogus/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Bogus
        mattr_accessor :service_url
        self.service_url = 'http://www.bogus.com'

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
