require File.dirname(__FILE__) + '/ecommpay/helper.rb'
require File.dirname(__FILE__) + '/ecommpay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ecommpay
        mattr_accessor :service_url
        self.service_url = 'https://terminal.ecommpay.com/'

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
