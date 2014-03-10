require File.dirname(__FILE__) + '/red_dot_payment/helper.rb'
require File.dirname(__FILE__) + '/red_dot_payment/return.rb'
require File.dirname(__FILE__) + '/red_dot_payment/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module RedDotPayment

        mattr_accessor :service_url
        def self.service_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :test
            'http://test.reddotpayment.com/merchant/cgi-bin'
          when :production
            'https://connect.reddotpayment.com/merchant/cgi-bin-live'
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.return(query_string, options = {})
          Return.new(query_string, options)
        end

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end
      end
    end
  end
end
