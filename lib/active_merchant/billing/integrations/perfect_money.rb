require File.dirname(__FILE__) + '/perfect_money/helper.rb'
require File.dirname(__FILE__) + '/perfect_money/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PerfectMoney
        mattr_accessor :service_url
        self.service_url = 'https://perfectmoney.is/api/step1.asp'

        def self.notification(*args)
          Notification.new(*args)
        end
      end
    end
  end
end
