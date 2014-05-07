module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Pxpay
        autoload :Helper, 'active_merchant/billing/integrations/pxpay/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/pxpay/notification.rb'
        autoload :Return, 'active_merchant/billing/integrations/pxpay/return.rb'

        def self.token_url
          'https://sec.paymentexpress.com/pxpay/pxaccess.aspx'
        end

        def self.notification(post, options={})
          Notification.new(post, options)
        end

        def self.return(query_string, options={})
          Return.new(query_string, options)
        end
      end
    end
  end
end
