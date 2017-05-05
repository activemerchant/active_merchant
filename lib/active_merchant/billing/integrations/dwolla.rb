module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dwolla
        autoload :Return, 'active_merchant/billing/integrations/dwolla/return.rb'
        autoload :Helper, 'active_merchant/billing/integrations/dwolla/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/dwolla/notification.rb'
        autoload :Common, 'active_merchant/billing/integrations/dwolla/common.rb'
        
        mattr_accessor :service_url
        self.service_url = 'https://www.dwolla.com/payment/pay'

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
