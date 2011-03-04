module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Quickpay 
        autoload :Helper, File.dirname(__FILE__) + '/quickpay/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/quickpay/notification.rb'
       
        mattr_accessor :service_url
        self.service_url = 'https://secure.quickpay.dk/form/'

        def self.notification(post, options = {})
          Notification.new(post)
        end
        
        def self.return(post, options = {})
          Return.new(post, options)
        end
      end
    end
  end
end
