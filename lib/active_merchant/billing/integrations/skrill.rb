require File.dirname(__FILE__) + '/skrill/helper.rb'
require File.dirname(__FILE__) + '/skrill/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Skrill

        mattr_accessor :service_url
        self.service_url = 'https://www.skrill.com/app/payment.pl'

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