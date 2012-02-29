module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module AuthorizeNetSim 
        autoload :Helper, 'active_merchant/billing/integrations/authorize_net_sim/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/authorize_net_sim/notification.rb'

        # Overwrite this if you want to change the ANS test url
        mattr_accessor :test_url
        self.test_url = 'https://test.authorize.net/gateway/transact.dll'
        
        # Overwrite this if you want to change the ANS production url
        mattr_accessor :production_url 
        self.production_url = 'https://secure.authorize.net/gateway/transact.dll' 
        
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
