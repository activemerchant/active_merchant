module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Convenience methods that can be included into a custom Credit Card object, such as an ActiveRecord based Credit Card object.
    module CreditCardMethods
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      def valid_month?(month)
        (1..12).include?(month)
      end
      
      def valid_expiry_year?(year)
        (Time.now.year..Time.now.year + 20).include?(year)
      end
      
      def valid_start_year?(year)
        year.to_s =~ /^\d{4}$/ && year.to_i > 1987
      end
      
      def valid_issue_number?(number)
        number.to_s =~ /^\d{1,2}$/
      end
      
      module ClassMethods
        # Returns true if it validates. Optionally, you can pass a card type as an argument and make sure it is of the correct type.
        # == References
        # - http://perl.about.com/compute/perl/library/nosearch/P073000.htm
        # - http://www.beachnet.com/~hstiles/cardtype.html
        def valid_number?(number)
          return true if ActiveMerchant::Billing::Base.gateway_mode == :test and ['1','2','3','success','failure','error'].include?(number.to_s)

          return false unless number.to_s.length >= 13

          sum = 0
          for i in 0..number.length
            weight = number[-1 * (i + 2), 1].to_i * (2 - (i % 2))
            sum += (weight < 10) ? weight : weight - 9
          end

          (number[-1,1].to_i == (10 - sum % 10) % 10)
        end
        
        # Regular expressions for the known card companies
        # == Known card types
        #	 Card Type                         Prefix                           Length
        #  --------------------------------------------------------------------------
        #	 master                            51-55                            16
        #	 visa                              4                                13, 16
        #	 american_express                  34, 37                           15
        #	 diners_club                       300-305, 36, 38                  14
        #	 discover                          6011                             16
        #	 jcb                               3                                16
        #	 jcb                               2131, 1800                       15
        #	 switch                            various                          16,18,19
        #	 solo                              63, 6767                         16,18,19
        def card_companies
          { 
            'visa' =>  /^4\d{12}(\d{3})?$/,
            'master' =>  /^5[1-5]\d{14}$/,
            'discover' =>  /^6011\d{12}$/,
            'american_express' =>  /^3[47]\d{13}$/,
            'diners_club' =>  /^3(0[0-5]|[68]\d)\d{11}$/,
            'jcb' =>  /^(3\d{4}|2131|1800)\d{11}$/,
            'switch' =>  [/^49(03(0[2-9]|3[5-9])|11(0[1-2]|7[4-9]|8[1-2])|36[0-9]{2})\d{10}(\d{2,3})?$/, /^564182\d{10}(\d{2,3})?$/, /^6(3(33[0-4][0-9])|759[0-9]{2})\d{10}(\d{2,3})?$/],
            'solo' =>  /^6(3(34[5-9][0-9])|767[0-9]{2})\d{10}(\d{2,3})?$/ 
          }
        end

        # Returns a string containing the type of card from the list of known information below.
        def type?(number)
          return 'visa' if ActiveMerchant::Billing::Base.gateway_mode == :test and ['1','2','3','success','failure','error'].include?(number.to_s)

          card_companies.each do |company, patterns|
            return company.dup if [patterns].flatten.any? { |pattern| number =~ pattern  } 
          end

          return nil
        end
      end
    end
  end
end