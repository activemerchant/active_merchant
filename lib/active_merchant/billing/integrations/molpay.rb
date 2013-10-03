require File.dirname(__FILE__) + '/molpay/helper.rb'
require File.dirname(__FILE__) + '/molpay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Molpay

        mattr_accessor :service_url
        self.service_url = 'https://www.onlinepayment.com.my/MOLPay/API/shopify/pay.php'

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
