module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneybookers

        autoload :Notification, File.dirname(__FILE__) + '/moneybookers/notification.rb'
        autoload :Helper, File.dirname(__FILE__) + '/moneybookers/helper.rb'

        mattr_accessor :production_url
        self.production_url = 'https://www.moneybookers.com/app/payment.pl'
        
        def self.service_url
          self.production_url
        end

        def self.notification(post, options)
          Notification.new(post, options)
        end

        def self.return(post, options = {})
          Return.new(post, options)
        end
      end
    end
  end
end
