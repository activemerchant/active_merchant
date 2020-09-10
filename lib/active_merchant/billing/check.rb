module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # The Check object is a plain old Ruby object, similar to CreditCard. It supports validation
    # of necessary attributes such as checkholder's name, routing and account numbers, but it is
    # not backed by any database.
    #
    # You may use Check in place of CreditCard with any gateway that supports it.
    class Check < Model
      attr_accessor :first_name, :last_name,
        :bank_name, :routing_number, :account_number,
        :account_holder_type, :account_type, :number

      # Used for Canadian bank accounts
      attr_accessor :institution_number, :transit_number

      def name
        @name ||= "#{first_name} #{last_name}".strip
      end

      def name=(value)
        return if empty?(value)

        @name = value
        segments = value.split(' ')
        @last_name = segments.pop
        @first_name = segments.join(' ')
      end

      def validate
        errors = []

        %i[name routing_number account_number].each do |attr|
          errors << [attr, 'cannot be empty'] if empty?(self.send(attr))
        end

        errors << [:routing_number, 'is invalid'] unless valid_routing_number?

        errors << [:account_holder_type, 'must be personal or business'] if !empty?(account_holder_type) && !%w[business personal].include?(account_holder_type.to_s)

        errors << [:account_type, 'must be checking or savings'] if !empty?(account_type) && !%w[checking savings].include?(account_type.to_s)

        errors_hash(errors)
      end

      def type
        'check'
      end

      def credit_card?
        false
      end

      # Routing numbers may be validated by calculating a checksum and dividing it by 10. The
      # formula is:
      #   (3(d1 + d4 + d7) + 7(d2 + d5 + d8) + 1(d3 + d6 + d9))mod 10 = 0
      # See http://en.wikipedia.org/wiki/Routing_transit_number#Internal_checksums
      def valid_routing_number?
        digits = routing_number.to_s.split('').map(&:to_i).select { |d| (0..9).cover?(d) }
        case digits.size
        when 9
          checksum = ((3 * (digits[0] + digits[3] + digits[6])) +
                      (7 * (digits[1] + digits[4] + digits[7])) +
                           (digits[2] + digits[5] + digits[8])) % 10
          case checksum
          when 0
            true
          else
            false
          end
        else
          false
        end
      end
    end
  end
end
