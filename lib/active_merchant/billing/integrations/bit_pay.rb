require File.dirname(__FILE__) + '/bit_pay/helper.rb'
require File.dirname(__FILE__) + '/bit_pay/notification.rb'
require File.dirname(__FILE__) + '/bit_pay/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module BitPay

        mattr_accessor :service_url
        self.service_url = 'https://bitpay.com/invoice'

        mattr_accessor :invoicing_url
        self.invoicing_url = 'https://bitpay.com/api/invoice'

        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.return(query_string, options = {})
          Return.new(query_string)
        end
      end
    end
  end
end
