module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:

      # Documentation:
      # https://www.payfast.co.za/s/std/integration-guide
      module PayFast
        autoload :Return, File.dirname(__FILE__) + '/pay_fast/return.rb'
        autoload :Helper, File.dirname(__FILE__) + '/pay_fast/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/pay_fast/notification.rb'
        autoload :Common, File.dirname(__FILE__) + '/pay_fast/common.rb'

        # Overwrite this if you want to change the PayFast sandbox url
        mattr_accessor :process_test_url
        self.process_test_url = 'https://sandbox.payfast.co.za/eng/process'

        # Overwrite this if you want to change the PayFast production url
        mattr_accessor :process_production_url
        self.process_production_url = 'https://www.payfast.co.za/eng/process'

        # Overwrite this if you want to change the PayFast sandbox url
        mattr_accessor :validate_test_url
        self.validate_test_url = 'https://sandbox.payfast.co.za/eng/query/validate'

        # Overwrite this if you want to change the PayFast production url
        mattr_accessor :validate_production_url
        self.validate_production_url = 'https://www.payfast.co.za/eng/query/validate'

        mattr_accessor :signature_parameter_name
        self.signature_parameter_name = 'signature'

        def self.service_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            self.process_production_url
          when :test
            self.process_test_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.validate_service_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            self.validate_production_url
          when :test
            self.validate_test_url
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
        
        def self.return(post, options = {})
          Return.new(post, options)
        end
      end
    end
  end
end
