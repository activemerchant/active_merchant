module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module EPaymentPlans
        autoload :Helper, File.dirname(__FILE__) + '/e_payment_plans/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/e_payment_plans/notification.rb'

        mattr_accessor :production_url
        self.production_url = 'https://www.epaymentplans.com'

        mattr_accessor :test_url
        self.test_url = 'https://test.epaymentplans.com'

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

        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.return(query_string, options = {})
          Return.new(query_string, options)
        end
      end
    end
  end
end
