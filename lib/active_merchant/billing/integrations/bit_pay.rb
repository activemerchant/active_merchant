require File.dirname(__FILE__) + '/bit_pay/helper.rb'
require File.dirname(__FILE__) + '/bit_pay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module BitPay

        mattr_accessor :service_url
        self.service_url = 'https://bitpay.com/api/invoice'

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
