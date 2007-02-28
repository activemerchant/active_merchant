module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module CreditCardFormatting
      def format(number, format)
        return '' if number.blank?
        
        case format
        when :two_digits
          sprintf("%.2i", number)[-2..-1]
        when :four_digits
          sprintf("%.4i", number)[-4..-1]
        else
          number
        end
      end
    end
  end
end