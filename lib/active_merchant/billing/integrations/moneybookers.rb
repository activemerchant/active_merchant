module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneybookers

        autoload :Notification, 'active_merchant/billing/integrations/moneybookers/notification.rb'
        autoload :Helper, 'active_merchant/billing/integrations/moneybookers/helper.rb'

        mattr_accessor :production_url
        self.production_url = 'https://www.moneybookers.com/app/payment.pl'
        
        def self.service_url
          self.production_url
        end

        def self.notification(post)
          Notification.new(post)
        end

      end
    end
  end
end
