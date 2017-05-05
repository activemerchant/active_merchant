module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Epayservice
        autoload :Helper, File.dirname(__FILE__) + '/epayservice/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/epayservice/notification.rb'
       
        mattr_accessor :service_url
        self.service_url = 'https://online.epayservices.com/merchant'
        # self.service_url = 'https://staging.epayservices.com/merchant'

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(*args)
          Notification.new(*args)
        end
        
      end
    end
  end
end
