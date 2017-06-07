module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Payza
        autoload :Helper, File.dirname(__FILE__) + '/payza/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/payza/notification.rb'

        mattr_accessor :test_url
        self.test_url = 'https://sandbox.Payza.com/sandbox/payprocess.aspx'

        mattr_accessor :production_url
        self.production_url = 'https://secure.payza.com/checkout'

        mattr_accessor :ipn_test_url
        self.ipn_test_url = 'https://sandbox.Payza.com/sandbox/IPN2.ashx'

        mattr_accessor :ipn_production_url
        self.ipn_production_url = 'https://secure.payza.com/ipn2.ashx'

        mattr_accessor :production_ips
        self.production_ips = [
          '72.52.13.101',
          '108.163.136.234',
          '108.163.136.235'
        ]

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

        def self.notification_confirmation_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            self.ipn_production_url
          when :test
            self.ipn_test_url
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
