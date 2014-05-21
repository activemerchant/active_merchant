module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CybersourceSecureAcceptance
        autoload :Helper, File.dirname(__FILE__) + '/cybersource_secure_acceptance/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/cybersource_secure_acceptance/notification.rb'
        autoload :Return, File.dirname(__FILE__) + '/cybersource_secure_acceptance/return.rb'
        autoload :Security, File.dirname(__FILE__) + '/cybersource_secure_acceptance/security.rb'

        # Integration module for Cybersource Secure Acceptance Web/Mobile and Silent Order.
        #
        # Defaults to Web/Mobile (payment window).
        #
        # Notes:
        #
        # - Main credential is the access_key from your Cybersource SA profile.
        # - credential2 is the profile code.
        # - credential3 is the secret key.
        # - (optional) Set transaction type by passing the :transaction_type option.
        #     Valid transaction types are defined in Cybersource's documentation.
        # - (optional) Switch endpoints using :endpoint => :<endpoint>
        #     Valid endpoints are: :oneclick, :create_token, :update_token, :silent_order
        # - (optional) Set payment token using: service.payment_token


        # Overwrite this if you want to change the test url
        mattr_accessor :test_url
        self.test_url = 'https://testsecureacceptance.cybersource.com'

        # Overwrite this if you want to change the production url
        mattr_accessor :production_url
        self.production_url = 'https://secureacceptance.cybersource.com'

        def self.service_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            production_url
          when :test
            test_url
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
