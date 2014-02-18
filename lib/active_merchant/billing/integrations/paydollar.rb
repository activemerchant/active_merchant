require File.dirname(__FILE__) + '/paydollar/helper.rb'
require File.dirname(__FILE__) + '/paydollar/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paydollar

        #mattr_accessor :service_url
        #self.service_url = 'https://www.example.com'

        #def self.notification(post)
          #Notification.new(post)
        #end
        
        mattr_accessor :production_url, :test_url
        self.production_url = 'https://www.paydollar.com/b2c2/eng/payment/payForm.jsp'
        self.test_url = 'https://test.paydollar.com/b2cDemo/eng/payment/payForm.jsp'
        
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
        
      end
    end
  end
end
