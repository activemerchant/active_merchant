require "active_merchant/billing/compatibility"
require "active_merchant/empty"

module ActiveMerchant
  module Billing
    class Model
      include Compatibility::Model
      include Empty

      def initialize(attributes = {})
        attributes.each do |key, value|
          send("#{key}=", value)
        end
      end

      def validate
        {}
      end

      private

      def errors_hash(array)
        array.inject({}) do |hash, (attribute, error)|
          (hash[attribute] ||= []) << error
          hash
        end
      end
    end
  end
end
