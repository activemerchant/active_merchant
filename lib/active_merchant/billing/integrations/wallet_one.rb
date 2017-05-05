require File.dirname(__FILE__) + '/wallet_one/helper.rb'
require File.dirname(__FILE__) + '/wallet_one/notification.rb'
require File.dirname(__FILE__) + '/wallet_one/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WalletOne

        mattr_accessor :service_url
        self.service_url = 'https://wl.walletone.com/checkout/checkout/Index'

        mattr_accessor :signature_parameter_name
        self.signature_parameter_name = 'WMI_SIGNATURE'

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(query_string, options = {})
          Notification.new(query_string, options)
        end

        def self.return(query_string)
          Return.new(query_string)
        end
      end
    end
  end
end
