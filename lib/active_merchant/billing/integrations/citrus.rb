module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Citrus
        autoload :Return, File.dirname(__FILE__) +'/citrus/return.rb'
        autoload :Helper, File.dirname(__FILE__) +'/citrus/helper.rb'
        autoload :Notification, File.dirname(__FILE__) +'/citrus/notification.rb'

        mattr_accessor :test_url, :production_url

        self.test_url = 'https://sandbox.citruspay.com/'
        self.production_url = 'https://www.citruspay.com/'

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

        def self.return(post, options = {})
          Return.new(post, options)
        end
	  end
    end
  end
end