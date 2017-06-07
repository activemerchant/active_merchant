require File.dirname(__FILE__) + '/adyen/helper.rb'
require File.dirname(__FILE__) + '/adyen/notification.rb'
require File.dirname(__FILE__) + '/adyen/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Adyen 
       
        mattr_accessor :service_url

        TEST_URL = 'https://test.adyen.com/hpp/select.shtml'
        LIVE_URL = 'https://live.adyen.com/hpp/select.shtml'
        
        def self.service_url
          ActiveMerchant::Billing::Base.integration_mode == :test ? TEST_URL : LIVE_URL
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
