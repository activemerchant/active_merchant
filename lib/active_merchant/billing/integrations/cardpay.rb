require File.dirname(__FILE__) + '/cardpay/helper.rb'
require File.dirname(__FILE__) + '/cardpay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Cardpay
        mattr_accessor :service_url
        self.service_url = 'https://cardpay.com/MI/cardpayment.html'

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