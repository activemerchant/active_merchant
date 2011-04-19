module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Quickpay 
        autoload :Helper, File.dirname(__FILE__) + '/quickpay/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/quickpay/notification.rb'
       
        mattr_accessor :service_url
        self.service_url = 'https://secure.quickpay.dk/form/'

        def self.notification(post)
          Notification.new(post)
        end  
      end
    end
  end
end
