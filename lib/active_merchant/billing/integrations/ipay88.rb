module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ipay88
        autoload :Return,       "active_merchant/billing/integrations/ipay88/return.rb"
        autoload :Helper,       "active_merchant/billing/integrations/ipay88/helper.rb"
        autoload :Notification, "active_merchant/billing/integrations/ipay88/notification.rb"

        mattr_accessor :merch_key

        # The merchant key provided to you by iPay88.
        def self.merchant_key
          self.merch_key
        end

        # Set the merchant key (in a Rails initializer, for example)
        #
        #   ActiveMerchant::Billing::Integrations::Ipay88.merchant_key = "foo"
        #
        def self.merchant_key=(key)
          self.merch_key = key
        end

        # The requery URL upon returning from iPay88
        def self.service_url
          "https://www.mobile88.com/epayment/enquiry.asp"
        end

        # The URL to POST your payment form to
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
