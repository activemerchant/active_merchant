require File.dirname(__FILE__) + '/dibs/helper.rb'
require File.dirname(__FILE__) + '/dibs/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dibs

        mattr_accessor :service_url
        self.service_url = 'https://sat1.dibspayment.com/dibspaymentwindow/entrypoint'

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
