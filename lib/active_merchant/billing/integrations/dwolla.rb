# Dwolla ActiveMerchant Integration
# http://www.dwolla.com/
# Authors: Michael Schonfeld <michael@dwolla.com>, Gordon Zheng <gordon@dwolla.com>
# Date: May 1, 2013

# All mappings in helper.rb are required fields to be sent to Dwolla.
# :account = 'Dwolla Id of merchant'
# :credential2 = 'key from Dwolla Application'
# :credential3 = 'secret from Dwolla Application'
# :redirect_url = 'can be different that what is specified on Dwolla Application creation'
# :return_url = 'can be different that what is specified on Dwolla Application creation'
# :order_id = must be unique for each transaction

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dwolla 
        autoload :Return, 'active_merchant/billing/integrations/dwolla/return.rb'
        autoload :Helper, 'active_merchant/billing/integrations/dwolla/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/dwolla/notification.rb'
       
        mattr_accessor :service_url
        self.service_url = 'https://www.dwolla.com/payment/pay'

        def self.notification(post, options={})
          Notification.new(post, options)
        end

        def self.return(query_string, options={})
          Return.new(query_string, options)
        end
      end
    end
  end
end
