module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module SagePayForm 
        autoload :Helper,       File.dirname(__FILE__) + '/sage_pay_form/helper.rb'
        autoload :Return,       File.dirname(__FILE__) + '/sage_pay_form/return.rb'
        autoload :Notification, File.dirname(__FILE__) + '/sage_pay_form/notification.rb'
        autoload :Encryption,   File.dirname(__FILE__) + '/sage_pay_form/encryption.rb'

        mattr_accessor :production_url
        mattr_accessor :test_url
        mattr_accessor :simulate_url
        self.production_url = 'https://live.sagepay.com/gateway/service/vspform-register.vsp'
        self.test_url       = 'https://test.sagepay.com/gateway/service/vspform-register.vsp'
        self.simulate_url   = 'https://test.sagepay.com/Simulator/VSPFormGateway.asp'

        def self.return(query_string, options = {})
          Return.new(query_string, options)
        end

        def self.service_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            self.production_url    
          when :test
            self.test_url
          when :simulate
            self.simulate_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end
      end
    end
  end
end
