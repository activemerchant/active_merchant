# With help from Giovanni Intini and his code for RGestPay - http://medlar.it/it/progetti/rgestpay

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Gestpay 
        autoload :Return, File.dirname(__FILE__) + '/gestpay/return.rb'
        autoload :Common, File.dirname(__FILE__) + '/gestpay/common.rb'
        autoload :Helper, File.dirname(__FILE__) + '/gestpay/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/gestpay/notification.rb'
       
        mattr_accessor :service_url
        self.service_url = 'https://ecomm.sella.it/gestpay/pagam.asp'

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
