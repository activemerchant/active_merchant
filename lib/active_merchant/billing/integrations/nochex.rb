require File.dirname(__FILE__) + '/nochex/helper.rb'
require File.dirname(__FILE__) + '/nochex/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Nochex
       
        mattr_accessor :service_url
        self.service_url = 'https://www.nochex.com/nochex.dll/checkout'

        mattr_accessor :notification_confirmation_url
        self.notification_confirmation_url = 'https://www.nochex.com/nochex.dll/apc/apc'

        def self.notification(post)
          Notification.new(post)
        end  
      end
    end
  end
end
