require File.dirname(__FILE__) + '/rbkmoney/helper.rb'
require File.dirname(__FILE__) + '/rbkmoney/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Rbkmoney
        mattr_accessor :service_url
        self.service_url = 'https://rbkmoney.ru/acceptpurchase.aspx'

        def self.notification(*args)
          Notification.new(*args)
        end
      end
    end
  end
end
