require File.dirname(__FILE__) + '/interkassa/helper.rb'
require File.dirname(__FILE__) + '/interkassa/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Interkassa
        mattr_accessor :service_url
        self.service_url = 'https://sci.interkassa.com/'

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(*args)
          Notification.new(*args)
        end

      end
    end
  end
end