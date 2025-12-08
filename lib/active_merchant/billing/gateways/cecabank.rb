require 'active_merchant/billing/gateways/cecabank/cecabank_xml'
require 'active_merchant/billing/gateways/cecabank/cecabank_json'

module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class CecabankGateway < Gateway
      self.abstract_class = true

      def self.new(options = {})
        return CecabankJsonGateway.new(options) if options[:is_rest_json]

        CecabankXmlGateway.new(options)
      end
    end
  end
end
