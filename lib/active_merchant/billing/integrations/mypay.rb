require File.dirname(__FILE__) + '/mypay/helper.rb'
require File.dirname(__FILE__) + '/mypay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Mypay

        mattr_accessor :service_url
        self.service_url = 'https://api.mypaymobi.com/api/payment/initializepayment'

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