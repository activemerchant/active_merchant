require File.dirname(__FILE__) + '/dinpay/helper.rb'
require File.dirname(__FILE__) + '/dinpay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dinpay

        mattr_accessor :service_url
        self.service_url = 'https://pay.ddbill.com/gateway?input_charset=UTF-8'

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
