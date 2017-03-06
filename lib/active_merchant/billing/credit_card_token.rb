module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # The Token object is a plain old Ruby object used to do card tokenization. It supports validation
    # of necessary attributes such as checkholder's name, type, exp_date and value, but it is
    # not backed by any database.
    #
    # You may use a CreditCardToken in place of a CreditCard with Payeezy gateway
    class CreditCardToken < Model
      attr_accessor :cardholder_name, :brand, :exp_date, :value

      def type
        'credit_card_token'
      end

      def credit_card?
        false
      end

      def validate
        errors = []
        [:cardholder_name, :type, :exp_date, :value].each do |attr|
          errors << [attr, "cannot be empty"] if empty?(self.send(attr))
        end
      end
    end
  end
end
