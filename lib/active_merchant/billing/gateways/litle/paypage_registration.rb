module ActiveMerchant
  module Billing
    class LitlePaypageRegistration
      attr_reader :paypage_registration_id, :month, :year, :verification_value

      def initialize(paypage_registration_id, options = {})
        @paypage_registration_id = paypage_registration_id
        @month = options[:month]
        @year = options[:year]
        @verification_value = options[:verification_value]
      end
    end
  end
end
