module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Pxpay
        autoload :Helper, 'active_merchant/billing/integrations/pxpay/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/pxpay/notification.rb'

        ENDPOINT_URL = 'https://sec.paymentexpress.com/pxpay/pxaccess.aspx'
        
        def self.service_url
          ENDPOINT_URL
        end
            
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
