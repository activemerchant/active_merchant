require File.dirname(__FILE__) + '/focal_payment/helper.rb'
require File.dirname(__FILE__) + '/focal_payment/notification.rb'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module FocalPayment
        mattr_accessor :service_url
        self.service_url = 'https://sales.focalpayments.com/hosted/index/'

        mattr_accessor :signature_parameter_name
        self.signature_parameter_name = 'Key'

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
