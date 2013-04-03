require 'digest/sha1'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dwolla
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            super
            add_field('name', 'Store Purchase')

            if ActiveMerchant::Billing::Base.integration_mode == :test || options[:test]
              add_field('test', 'true')
            end

            timestamp = Time.now.to_i.to_s
            add_field('timestamp', timestamp)
            add_field('allowFundingSources', 'true')

            key = options[:credential2].to_s
            secret = options[:credential3].to_s
            orderid = order.to_s
            signature = Digest::SHA1.hexdigest(secret + "#{key}&#{timestamp}&#{orderid}")
            add_field('signature', signature)
          end

          mapping :account, 'destinationid'
          mapping :credential2, 'key'
          mapping :notify_url, 'callback'
          mapping :return_url, 'redirect'
          mapping :description, 'description'
          mapping :amount, 'amount'
          mapping :tax, 'tax'
          mapping :shipping, 'shipping'
          mapping :order, 'orderid'
        end
      end
    end
  end
end
