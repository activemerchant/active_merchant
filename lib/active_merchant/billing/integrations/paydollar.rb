require File.dirname(__FILE__) + '/paydollar/helper.rb'
require File.dirname(__FILE__) + '/paydollar/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paydollar
	def self.service_url
	  service_urls(ActiveMerchant::Billing::Base.integration_mode)
	end

        def self.notification(post)
          Notification.new(post)
        end

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
