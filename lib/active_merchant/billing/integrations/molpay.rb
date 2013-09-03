module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Molpay
        autoload :Return,       "active_merchant/billing/integrations/molpay/return.rb"
        autoload :Helper,       "active_merchant/billing/integrations/molpay/helper.rb"
				#will be implement IPN callback later
        #autoload :Notification, "active_merchant/billing/integrations/molpay/notification.rb"

				#MOLPay payment URL
				#will be change when going to new server
        def self.service_url
          "https://www.onlinepayment.com.my/MOLPay/API/shopify/pay.php"
        end
				
				#MOLPay return definition
        def self.return(query_string, options={})
          Return.new(query_string, options)
        end
      end
    end
  end
end
