module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ipay88
        autoload :Return,       "active_merchant/billing/integrations/ipay88/return.rb"
        autoload :Helper,       "active_merchant/billing/integrations/ipay88/helper.rb"
        autoload :Notification, "active_merchant/billing/integrations/ipay88/notification.rb"

        mattr_accessor :merch_key

        def self.merchant_key
          self.merch_key
        end

        def self.merchant_key=(key)
          self.merch_key = key
        end

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
