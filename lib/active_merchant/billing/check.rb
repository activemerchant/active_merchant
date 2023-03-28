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
        :account_holder_type, :account_type, :number,
        :account_holder_name, :country, :currency

      # Used for Canadian bank accounts
      attr_accessor :institution_number, :transit_number

      # Canadian Institution Numbers
      # Partial list found here: https://en.wikipedia.org/wiki/Routing_number_(Canada)
      CAN_INSTITUTION_NUMBERS = %w(
        001 002 003 004 006 010 016 030 039 117 127 177 219 245 260 269 270 308
        309 310 315 320 338 340 509 540 608 614 623 809 815 819 828 829 837 839
        865 879 889 899 241 242 248 250 265 275 277 290 294 301 303 307 311 314
        321 323 327 328 330 332 334 335 342 343 346 352 355 361 362 366 370 372
        376 378 807 853 890 618 842
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

      def valid_routing_number?
        digits = routing_number.to_s.split('').map(&:to_i).select { |d| (0..9).cover?(d) }
        case digits.size
        when 9
          return checksum(digits) == 0 || CAN_INSTITUTION_NUMBERS.include?(routing_number[1..3])
        when 8
          return CAN_INSTITUTION_NUMBERS.include?(routing_number[5..7])
        end

        false
      end

      # Routing numbers may be validated by calculating a checksum and dividing it by 10. The
      # formula is:
      #   (3(d1 + d4 + d7) + 7(d2 + d5 + d8) + 1(d3 + d6 + d9))mod 10 = 0
      # See http://en.wikipedia.org/wiki/Routing_transit_number#Internal_checksums
      def checksum(digits)
        ((3 * (digits[0] + digits[3] + digits[6])) +
        (7 * (digits[1] + digits[4] + digits[7])) +
        (digits[2] + digits[5] + digits[8])) % 10
      end

      # Always return MICR-formatted routing number for Canadian routing numbers, US routing numbers unchanged
      def micr_format_routing_number
        digits = routing_number.to_s.split('').map(&:to_i).select { |d| (0..9).cover?(d) }
        case digits.size
        when 9
          if checksum(digits) == 0
            return routing_number
          else
            return routing_number[4..8] + routing_number[1..3]
          end
        when 8
          return routing_number
        end
      end

      # Always return electronic-formatted routing number for Canadian routing numbers, US routing numbers unchanged
      def electronic_format_routing_number
        digits = routing_number.to_s.split('').map(&:to_i).select { |d| (0..9).cover?(d) }
        case digits.size
        when 9
          return routing_number
        when 8
          return '0' + routing_number[5..7] + routing_number[0..4]
        end
      end
    end
  end
end
