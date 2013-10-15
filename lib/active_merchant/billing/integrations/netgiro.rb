require File.dirname(__FILE__) + '/netgiro/helper.rb'
require File.dirname(__FILE__) + '/netgiro/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Netgiro
        autoload :Return, 'active_merchant/billing/integrations/netgiro/return.rb'
        autoload :Helper, 'active_merchant/billing/integrations/netgiro/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/netgiro/notification.rb'

        mattr_accessor :test_url
        self.test_url = 'http://test.netgiro.is/user/securepay'

        mattr_accessor :production_url
        self.production_url = 'https://www.netgiro.is/SecurePay'

        def self.test?
          (ActiveMerchant::Billing::Base.integration_mode == :test)
        end

        def self.service_url
          (test? ? test_url : production_url)
        end

        def self.notification(params, options={})
          Notification.new(params, options.merge(:test => test?))
        end

      end
    end
  end
end
