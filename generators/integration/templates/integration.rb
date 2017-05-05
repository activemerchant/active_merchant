require File.dirname(__FILE__) + '/<%= identifier %>/helper.rb'
require File.dirname(__FILE__) + '/<%= identifier %>/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module <%= class_name %>

        mattr_accessor :service_url
        self.service_url = 'https://www.example.com'

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
