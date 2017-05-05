require File.dirname(__FILE__) + '/world_pay/helper.rb'
require File.dirname(__FILE__) + '/world_pay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WorldPay

        mattr_accessor :production_url, :test_url
        self.production_url = 'https://secure.worldpay.com/wcc/purchase'
        self.test_url = 'https://secure-test.worldpay.com/wcc/purchase'

        def self.service_url
          case ActiveMerchant::Billing::Base.integration_mode
          when :production
            self.production_url
          when :test
            self.test_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.return(post, options = {})
          Return.new(post, options)
        end
      end
    end
  end
end
