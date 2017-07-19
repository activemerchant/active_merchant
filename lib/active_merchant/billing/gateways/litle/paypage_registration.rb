module ActiveMerchant
  module Billing
    # Litle provides functionality to make authorization and sale calls
    # with a Paypage Registration Id instead of a Litle Token.
    # This class wraps the required data for such a request.
    #
    # The first parameter is the paypage_registration_id and is required.
    #
    # The second parameter optionally takes a month, year, and verification_value.
    # These parameters are allowed by the Litle endpoints but not necessary for
    # a successful request.
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
