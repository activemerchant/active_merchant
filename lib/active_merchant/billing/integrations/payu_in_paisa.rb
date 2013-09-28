module ActiveMerchant
  module Billing
    module Integrations
      module PayuInPaisa

        autoload :Return, 'active_merchant/billing/integrations/payu_in_paisa/return.rb'
        autoload :Helper, 'active_merchant/billing/integrations/payu_in_paisa/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/payu_in_paisa/notification.rb'

        mattr_accessor :test_url
        mattr_accessor :production_url

        self.test_url = 'https://test.payu.in/_payment.php'
        self.production_url = 'https://secure.payu.in/_payment.php'

        def self.service_url
          ActiveMerchant::Billing::Base.integration_mode == :production ? self.production_url : self.test_url
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
