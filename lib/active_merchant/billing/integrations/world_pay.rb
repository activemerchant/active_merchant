require File.dirname(__FILE__) + '/world_pay/helper.rb'
require File.dirname(__FILE__) + '/world_pay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WorldPay 
       
        # production and test have the same endpoint
        mattr_accessor :production_url
        self.production_url = 'https://secure.wp3.rbsworldpay.com/wcc/purchase'
        
        def self.service_url
          production_url
        end

        def self.notification(post, options = {})
          Notification.new(post, options)
        end
        
        def self.return(post, options = {})
          Return.new(post, options)
        end
      end
    end
  end
end
