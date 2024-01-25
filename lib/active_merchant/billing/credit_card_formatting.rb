module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    module CreditCardFormatting
      def expdate(credit_card)
        "#{format(credit_card.month, :two_digits)}#{format(credit_card.year, :two_digits)}"
      end

      def strftime_yyyymm(credit_card)
        format(credit_card.year, :four_digits) + format(credit_card.month, :two_digits)
      end

      # This method is used to format numerical information pertaining to credit cards.
      #
      #   format(2005, :two_digits)  # => "05"
      #   format(05,   :four_digits) # => "0005"
      def format(number, option)
        return '' if number.blank?

        case option
        when :two_digits  then sprintf('%.2i', number.to_i)[-2..]
        when :four_digits then sprintf('%.4i', number.to_i)[-4..]
        when :four_digits_year then number.to_s.length == 2 ? "20#{number}" : format(number, :four_digits)
        else number
        end
      end
    end
  end
end
