# All mappings in helper.rb are required fields to be sent to Dwolla.
# :account = 'Dwolla Id of merchant'
# :credential1 = 'key from Dwolla Application'
# :credential2 = 'secret from Dwolla Application'
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
          Notification.new(post)
        end

        def self.return(query_string, options={})
          Return.new(query_string)
        end
      end
    end
  end
end
