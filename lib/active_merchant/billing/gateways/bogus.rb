module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Bogus Gateway
    class BogusGateway < Gateway
      
      self.supported_countries = ['US']
      self.supported_cardtypes = [:bogus]
      self.homepage_url = 'http://example.com'
      self.display_name = 'Bogus'
      
      def authorize(money, creditcard, options = {})
        case creditcard.number
        when '1'
          Response.new(true, "Bogus Gateway: Forced success", {:authorized_amount => money.to_s}, :test => true, :authorization => '53433' )
        when '2'
          Response.new(false, "Bogus Gateway: Forced failure", {:authorized_amount => money.to_s, :error => 'Bogus Gateway: Forced failure' }, :test => true)
        else
          raise Error, 'Bogus Gateway: Use CreditCard number 1 for success, 2 for exception and anything else for error'
        end      
      end
  
      def purchase(money, creditcard, options = {})
        case creditcard.number
        when '1'
          Response.new(true, "Bogus Gateway: Forced success", {:paid_amount => money.to_s}, :test => true)
        when '2'
          Response.new(false, "Bogus Gateway: Forced failure", {:paid_amount => money.to_s, :error => 'Bogus Gateway: Forced failure' },:test => true)
        else
          raise Error, 'Bogus Gateway: Use CreditCard number 1 for success, 2 for exception and anything else for error'
        end
      end
 
      def credit(money, ident, options = {})
        case ident
        when '1'
          Response.new(true, "Bogus Gateway: Forced success", {:paid_amount => money.to_s}, :test => true)
        when '2'
          Response.new(false, "Bogus Gateway: Forced failure", {:paid_amount => money.to_s, :error => 'Bogus Gateway: Forced failure' },:test => true)
        else
          raise Error, 'Bogus Gateway: Use trans_id 1 for success, 2 for exception and anything else for error'
        end
      end
 
      def capture(money, ident, options = {})
        case ident
        when '1'
          raise Error, 'Bogus Gateway: Use authorization number 1 for exception, 2 for error and anything else for success'
        when '2'
          Response.new(false, "Bogus Gateway: Forced failure", {:paid_amount => money.to_s, :error => 'Bogus Gateway: Forced failure' }, :test => true)
        else
          Response.new(true, "Bogus Gateway: Forced success", {:paid_amount => money.to_s}, :test => true)
        end
      end
      
      def store(creditcard, options = {})
        case creditcard.number
        when '1'
          Response.new(true, "Bogus Gateway: Forced success", {:billingid => '1'}, :test => true, :authorization => '53433' )
        when '2'
          Response.new(false, "Bogus Gateway: Forced failure", {:billingid => nil, :error => 'Bogus Gateway: Forced failure' }, :test => true)
        else
          raise Error, 'Bogus Gateway: Use CreditCard number 1 for success, 2 for exception and anything else for error'
        end              
      end
      
      def unstore(identification, options = {})
        case identification
        when '1'
          Response.new(true, "Bogus Gateway: Forced success", {}, :test => true)
        when '2'
          Response.new(false, "Bogus Gateway: Forced failure", {:error => 'Bogus Gateway: Forced failure' },:test => true)
        else
          raise Error, 'Bogus Gateway: Use trans_id 1 for success, 2 for exception and anything else for error'
        end
      end

      private 
    
      def deal_with_cc(creditcard)
        case creditcard.number
          when '1'
            Response.new(true, "Bogus Gateway: Forced success", {}, :test => true)
          when '2'
            Response.new(false, "Bogus Gateway: Forced failure", @response, :test => true)
          else
            raise Error, 'Bogus Gateway: Use CreditCard number 1 for success, 2 for exception and anything else for error'
        end      
      end
 
    end
  end
end