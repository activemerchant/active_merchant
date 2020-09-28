require 'active_merchant/billing/gateways/braintree/braintree_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BraintreeGateway < Gateway
      include BraintreeCommon

      self.abstract_class = true

      def self.new(options={})
        if options.has_key?(:login)
          BraintreeOrangeGateway.new(options)
        else
          BraintreeBlueGateway.new(options)
        end
      end
    end
  end
end
