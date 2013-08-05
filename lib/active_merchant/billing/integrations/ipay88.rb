module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ipay88
        autoload :Return,       "active_merchant/billing/integrations/ipay88/return.rb"
        autoload :Helper,       "active_merchant/billing/integrations/ipay88/helper.rb"
        autoload :Notification, "active_merchant/billing/integrations/ipay88/notification.rb"

        def self.service_url
          "https://www.mobile88.com/epayment/enquiry.asp"
        end

        def self.entry_url
          "https://www.mobile88.com/epayment/entry.asp"
        end

        def self.return(query_string)
          Return.new(query_string)
        end
      end
    end
  end
end
