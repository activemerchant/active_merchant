require File.dirname(__FILE__) + '/citrus/helper.rb'
require File.dirname(__FILE__) + '/citrus/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Citrus

        mattr_accessor :service_url
        self.service_url = 'https://www.example.com'

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
