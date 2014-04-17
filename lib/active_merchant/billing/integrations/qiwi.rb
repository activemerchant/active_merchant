require File.dirname(__FILE__) + '/qiwi/helper.rb'
require File.dirname(__FILE__) + '/qiwi/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Qiwi

        autoload :Helper, File.dirname(__FILE__) + '/qiwi/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/qiwi/notification.rb'

        mattr_accessor :service_url
        self.service_url = 'https://w.qiwi.ru/payments.action'

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(query_string, options = {})
          Notification.new(query_string, options)
        end
      end
    end
  end
end
