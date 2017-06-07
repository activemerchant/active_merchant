require File.dirname(__FILE__) + '/paydollar/helper.rb'
require File.dirname(__FILE__) + '/paydollar/notification.rb'

module ActiveMerchant # Primary active_merchant module
  module Billing # Primary active_merchant billing module
    module Integrations # Primary active_merchant integrations module
      module Paydollar # The active_merchant's Paydollar module
        # Gets the Paydollar's service URL
        # @return [String] The service url based on current environment (production/test)
        def self.service_url
          service_urls(ActiveMerchant::Billing::Base.integration_mode)
        end

        # Generates a new Paydollar's notification object
        def self.notification(post)
          Notification.new(post)
        end

        # Gets the notification confirmation URL
        def self.notification_confirmation_url
          service_urls(ActiveMerchant::Billing::Base.integration_mode)
        end

  	private
        def self.service_urls(mode)
           case mode
             when :production
               'https://www.paydollar.com/b2c2/eng/payment/payForm.jsp'    
             when :test
               'https://test.paydollar.com/b2cDemo/eng/payment/payForm.jsp'
             else
               raise StandardError, "Integration mode set to an invalid value: #{mode}"
           end
        end
      end
    end
  end
end
