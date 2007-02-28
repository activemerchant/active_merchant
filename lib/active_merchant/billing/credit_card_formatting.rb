module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module CreditCardFormatting
      def format_month(month, format = nil)
        case format
        when :two_digit
          sprintf("%.2i", month)[-2..-1]
        else
          month.to_s
        end
      end
    
      def format_year(year, format = nil)
        case format
        when :two_digit
          sprintf("%.2i", year)[-2..-1]
        when :four_digit
          sprintf("%.4i", year)
        else
          year.to_s
        end
      end
    end
  end
end