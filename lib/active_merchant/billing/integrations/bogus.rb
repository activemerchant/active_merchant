
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Bogus
        autoload :Return, 'active_merchant/billing/integrations/bogus/return.rb'
        autoload :Helper, 'active_merchant/billing/integrations/bogus/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/bogus/notification.rb'

        mattr_accessor :service_url
        self.service_url = 'http://www.bogus.com'

        def self.notification(post, options = {})
          Notification.new(post)
        end
        
        def self.return(query_string, options = {})
          Return.new(query_string)
        end
      end
    end
  end
end
