require File.dirname(__FILE__) + '/coinbase/helper.rb'
require File.dirname(__FILE__) + '/coinbase/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Coinbase

        mattr_accessor :service_url
        self.service_url = 'https://coinbase.com/checkouts/redirect'

        mattr_accessor :buttoncreate_url
        self.buttoncreate_url = 'https://coinbase.com/api/v1/buttons'
        
        mattr_accessor :notification_confirmation_url
        self.notification_confirmation_url = 'https://coinbase.com/api/v1/orders/%s'

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
