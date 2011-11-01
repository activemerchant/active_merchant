module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayflowLink
        autoload :Helper, 'active_merchant/billing/integrations/payflow_link/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/payflow_link/notification.rb'

        mattr_accessor :service_url
        self.service_url = 'https://payflowlink.paypal.com'

        def self.notification(post, options = {})
          Notification.new(post)
        end

        def self.return(query_string, options = {})
          ActiveMerchant::Billing::Integrations::Return.new(query_string)
        end
      end
    end
  end
end
