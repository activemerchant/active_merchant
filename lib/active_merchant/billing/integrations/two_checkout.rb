
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module TwoCheckout 
        autoload 'Helper', File.dirname(__FILE__) + '/two_checkout/helper'
        autoload 'Return', File.dirname(__FILE__) + '/two_checkout/return'
        autoload 'Notification', File.dirname(__FILE__) + '/two_checkout/notification'
       
        mattr_accessor :service_url
        self.service_url = 'https://www.2checkout.com/2co/buyer/purchase'

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
