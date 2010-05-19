module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BraintreeGateway
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
