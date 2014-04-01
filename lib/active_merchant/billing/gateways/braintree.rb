require File.dirname(__FILE__) + '/braintree/braintree_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BraintreeGateway < Gateway
      include BraintreeCommon

      self.abstract_class = true

      def self.new(options={})
        if options.has_key? required_login_params.first
          BraintreeOrangeGateway.new(options)
        else
          BraintreeBlueGateway.new(options)
        end
      end

      def self.required_login_params
        @@required_params ||= [super.first]
      end
    end
  end
end
