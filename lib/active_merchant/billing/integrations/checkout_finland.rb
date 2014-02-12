require File.dirname(__FILE__) + '/checkout_finland/helper.rb'
require File.dirname(__FILE__) + '/checkout_finland/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CheckoutFinland

        mattr_accessor :service_url
        self.service_url = 'https://payment.checkout.fi/'

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
