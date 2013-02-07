module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paysbuy
        autoload :Helper, File.dirname(__FILE__) + '/paysbuy/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/paysbuy/notification.rb'

        mattr_accessor :test_url
        self.test_url = 'https://demo.paysbuy.com/paynow.aspx'

        mattr_accessor :production_url
        self.production_url = 'https://www.paysbuy.com/paynow.aspx'

        def self.service_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            self.production_url
          when :test
            self.test_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(query_string, options = {})
          Notification.new(query_string, options)
        end
      end
    end
  end
end
