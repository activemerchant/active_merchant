module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Pxpay
        autoload :Helper, 'active_merchant/billing/integrations/pxpay/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/pxpay/notification.rb'
        
        TOKEN_URL = 'https://sec.paymentexpress.com/pxpay/pxaccess.aspx'

        LIVE_URL = 'https://sec.paymentexpress.com/pxpay/pxpay.aspx'
            
        def self.token_url
          TOKEN_URL
        end

        def self.service_url
          LIVE_URL
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
