require File.dirname(__FILE__) + '/go_coin/helper.rb'
require File.dirname(__FILE__) + '/go_coin/notification.rb'
require File.dirname(__FILE__) + '/go_coin/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module GoCoin

        def self.create_invoice_url(merchant_id)
          "https://api.gocoin.com/api/v1/merchants/#{merchant_id}/invoices"
        end

        def self.read_invoice_url_prefix
          "https://api.gocoin.com/api/v1/invoices"
        end

        def self.credential_based_url(options)
          "https://gateway.gocoin.com/merchant/#{options[:account_name]}/invoices"
        end

        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.return(query_string, options = {})
          Return.new(query_string)
        end
      end
    end
  end
end
