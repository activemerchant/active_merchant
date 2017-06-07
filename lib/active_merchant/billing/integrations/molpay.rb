require File.dirname(__FILE__) + '/molpay/helper.rb'
require File.dirname(__FILE__) + '/molpay/notification.rb'
require File.dirname(__FILE__) + '/molpay/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Molpay

      	mattr_accessor :acknowledge_url 
        self.acknowledge_url = 'https://www.onlinepayment.com.my/MOLPay/API/chkstat/returnipn.php' 

        def self.notification(post)
          Notification.new(post)
        end

        def self.return(query_string, options={})
          Return.new(query_string, options)
        end
      end
    end
  end
end
