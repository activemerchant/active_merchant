require File.dirname(__FILE__) + '/alipay/helper.rb'
require File.dirname(__FILE__) + '/alipay/notification.rb'
require File.dirname(__FILE__) + '/alipay/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Alipay

        mattr_accessor :service_url
        self.service_url = 'https://mapi.alipay.com/gateway.do?_input_charset=utf-8'

        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.return(query_string, options = {})
          Return.new(query_string, options)
        end
      end
    end
  end
end
