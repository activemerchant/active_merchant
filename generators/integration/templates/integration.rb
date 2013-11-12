module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module <%= class_name %>
        autoload :Helper, File.dirname(__FILE__) + '/<%= identifier %>/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/<%= identifier %>/notification.rb'

        mattr_accessor :service_url
        self.service_url = 'https://www.example.com'

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
