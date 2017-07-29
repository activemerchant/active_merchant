module ActiveMerchant
  module Billing
    # Litle provides functionality to make authorization and sale calls
    # with a Paypage Registration Id instead of a Litle Token.
    # This class wraps the required data for such a request.
    #
    # The first parameter is the paypage_registration_id and is required.
    #
    # The second parameter optionally takes a month, year, verification_value, and name.
    # These parameters are allowed by the Litle endpoints but not necessary for
    # a successful request.
    #
    # The name parameter is allowed by Vantiv as a member of the billToAddress element.
    # It is passed in here to be consistent with the rest of the Litle gateway and Activemerchant.
    class LitlePaypageRegistration
      attr_reader :paypage_registration_id, :month, :year, :verification_value, :name

      def initialize(paypage_registration_id, options = {})
        @paypage_registration_id = paypage_registration_id
        @month = options[:month]
        @year = options[:year]
        @verification_value = options[:verification_value]
        @name = options[:name]
      end
    end
  end
end
