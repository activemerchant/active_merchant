module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Valitor 
        autoload :Return, 'active_merchant/billing/integrations/valitor/return.rb'
        autoload :Helper, 'active_merchant/billing/integrations/valitor/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/valitor/notification.rb'

        mattr_accessor :test_url
        self.test_url = 'https://testvefverslun.valitor.is/1_1/'

        mattr_accessor :production_url 
        self.production_url = 'https://vefverslun.valitor.is/1_1/'
        
        def self.test?
          (ActiveMerchant::Billing::Base.integration_mode == :test)
        end

        def self.service_url
          (test? ? test_url : production_url)
        end

        def self.notification(params, options={})
          Notification.new(params, options.merge(:test => test?))
        end

        def self.return(query_string, options={})
          Return.new(query_string, options.merge(:test => test?))
        end
      end
    end
  end
end
