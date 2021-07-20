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

      # Canadian Institution Numbers
      # Found here: https://en.wikipedia.org/wiki/Routing_number_(Canada)
      CAN_INSTITUTION_NUMBERS = %w(
        001 002 003 004	006 010 016 030 039 117 127 177 219 245 260 269 270 308
        309 310 315 320	338 340 509 540 608 614 623 809 815 819 828 829 837 839
        865 879 889 899 241 242 248 250 265 275 277 290 294 301 303 307 311 314
        321 323 327 328 330 332 334 335 342 343 346 352 355 361 362 366 370 372
        376 378 807 853
      )

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
        if digits.size == 9
          checksum = ((3 * (digits[0] + digits[3] + digits[6])) +
            (7 * (digits[1] + digits[4] + digits[7])) +
            (digits[2] + digits[5] + digits[8])) % 10

          return checksum == 0
        end

        return CAN_INSTITUTION_NUMBERS.include?(routing_number[0..2]) if digits.size == 8

        false
      end
    end
  end
end
