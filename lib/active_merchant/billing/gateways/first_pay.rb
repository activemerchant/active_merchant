require 'active_merchant/billing/gateways/first_pay/first_pay_xml'
require 'active_merchant/billing/gateways/first_pay/first_pay_json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FirstPayGateway < Gateway
      self.abstract_class = true

      def self.new(options = {})
        return FirstPayJsonGateway.new(options) if options[:merchant_key]

        FirstPayXmlGateway.new(options)
      end
    end
  end
end
