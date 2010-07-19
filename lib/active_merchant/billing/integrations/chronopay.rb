
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Chronopay
        autoload :Return, 'active_merchant/billing/integrations/chronopay/return.rb'
        autoload :Helper, 'active_merchant/billing/integrations/chronopay/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/chronopay/notification.rb'

        mattr_accessor :service_url
        self.service_url = 'https://secure.chronopay.com/index_shop.cgi'

        def self.notification(post)
          Notification.new(post)
        end
        
        def self.return(query_string)
          Return.new(query_string)
        end
      end
    end
  end
end
