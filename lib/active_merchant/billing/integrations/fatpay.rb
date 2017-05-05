require File.dirname(__FILE__) + '/fatpay/helper.rb'
require File.dirname(__FILE__) + '/fatpay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Fatpay
        mattr_accessor :service_url
        self.service_url = 'https://fatpay.net/pay'

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