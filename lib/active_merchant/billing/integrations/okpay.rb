require File.dirname(__FILE__) + '/okpay/helper.rb'
require File.dirname(__FILE__) + '/okpay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Okpay
        mattr_accessor :service_url
        self.service_url = 'https://www.okpay.com/process.html'

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
