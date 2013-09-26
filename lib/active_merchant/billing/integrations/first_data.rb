module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module FirstData
        autoload :Helper, 'active_merchant/billing/integrations/first_data/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/first_data/notification.rb'

        # Overwrite this if you want to change the ANS test url
        mattr_accessor :test_url
        self.test_url = 'https://demo.globalgatewaye4.firstdata.com/payment'

        # Overwrite this if you want to change the ANS production url
        mattr_accessor :production_url
        self.production_url = 'https://checkout.globalgatewaye4.firstdata.com/payment'

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

        def self.notification(post)
          Notification.new(post)
        end

        def self.return(query_string)
          Return.new(query_string)
        end
      end
    end
  end
end
