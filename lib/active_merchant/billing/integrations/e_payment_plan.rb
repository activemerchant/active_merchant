require File.dirname(__FILE__) + '/e_payment_plan/helper.rb'
require File.dirname(__FILE__) + '/e_payment_plan/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module EPaymentPlan

        mattr_accessor :production_url
        self.production_url = 'https://epaymentplans.com'

        mattr_accessor :test_url
        self.test_url = 'https://test.epaymentplans.com'

        def initialize
        end

        def self.service_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            "#{production_url}/order/purchase"
          when :test
            "#{test_url}/order/purchase"
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.notification_confirmation_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            "#{production_url}/order/confirmation"
          when :test
            "#{test_url}/order/confirmation"
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
