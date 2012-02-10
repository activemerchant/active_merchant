require 'rubygems'
require 'LitleOnline'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class LitleGateway < Gateway
      
      TEST_URL = 'https://cert.litle.com/vap/communicator/online'
      LIVE_URL = 'https://payments.litle.com/vap/communicator/online'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.litle.com/'
      
      # The name of the gateway
      self.display_name = 'Litle'

      def LitleGateway.initialize(hash_in)
      	LitleOnlineRequest.authentication(hash_in)
      end
    
      def LitleGateway.authorization(order, creditcard, options)
	creditcard = LitleGateway.payment_method(creditcard)
	LitleOnlineRequest.authorization(LitleGateway.commit(order, creditcard, options))
      end
      
      def LitleGateway.authReversal(order, creditcard, options)
	creditcard = LitleGateway.payment_method(creditcard)
	LitleOnlineRequest.authReversal(LitleGateway.commit(order, creditcard, options))
      end
      
      def LitleGateway.capture(order, creditcard, options)
	creditcard = LitleGateway.payment_method(creditcard)
	LitleOnlineRequest.capture(LitleGateway.commit(order, creditcard, options))
      end
      
      def LitleGateway.captureGivenAuth(order, creditcard, options)
	creditcard = LitleGateway.payment_method(creditcard)
	LitleOnlineRequest.captureGivenAuth(LitleGateway.commit(order, creditcard, options))
      end

      def LitleGateway.credit(order, creditcard, options)
	creditcard = LitleGateway.payment_method(creditcard)
	LitleOnlineRequest.credit(LitleGateway.commit(order, creditcard, options))
      end
      
      def LitleGateway.sale(order, creditcard, options)
	creditcard = LitleGateway.payment_method(creditcard)
	LitleOnlineRequest.sale(LitleGateway.commit(order, creditcard, options))
      end

      def LitleGateway.registerTokenRequest(order, creditcard, options)
	creditcard = LitleGateway.payment_method(creditcard)
	LitleOnlineRequest.registerTokenRequest(LitleGateway.commit(order, creditcard, options))
      end

      def LitleGateway.forceCapture(order, creditcard, options)
	creditcard = LitleGateway.payment_method(creditcard)
	LitleOnlineRequest.forceCapture(LitleGateway.commit(order, creditcard, options))
      end

      def LitleGateway.echeckRedeposit(order, creditcard, options)
	creditcard = LitleGateway.payment_method(creditcard)
	LitleOnlineRequest.echeckRedeposit(LitleGateway.commit(order, creditcard, options))
      end

      def LitleGateway.echeckSale(order, creditcard, options)
	creditcard = LitleGateway.payment_method(creditcard)
	LitleOnlineRequest.echeckSale(LitleGateway.commit(order, creditcard, options))
      end 

      def LitleGateway.echeckCredit(order, creditcard, options)
	creditcard = LitleGateway.payment_method(creditcard)
	LitleOnlineRequest.echeckCredit(LitleGateway.commit(order, creditcard, options))
      end

      def LitleGateway.echeckVerification(order, creditcard, options)
	creditcard = LitleGateway.payment_method(creditcard)
	LitleOnlineRequest.echeckVerification(LitleGateway.commit(order, creditcard, options))
      end

      private
      @@card_type = { 
      			'visa' => 'VI',
      			'master' => 'MC',
      			'american_express' => 'AX',
      			'discover' => 'DI',
			'diners_club' => 'DC'
      		}

      def LitleGateway.payment_method(payments)
	if payments == {}
		return payments
	else
	  creditcard = ActiveMerchant::Billing::CreditCard.new(payments)
	  payments = {'card' =>
			  {
			   'number' => creditcard.number,
		 	   'expDate' => [sprintf("%.4i", creditcard.year)[-2..-1], sprintf("%.2i", creditcard.month)].compact.join(''),
		 	   'type' =>@@card_type[@ActiveMerchant::Billing::CreditCard.type?(creditcard.number)],
		 	   'cardValidationNum' => creditcard.verification_value,
		 	   'name' => [creditcard.first_name, creditcard.last_name].compact.join(',')}
			}
	  return payments
	end
      end

      def LitleGateway.commit(order, payments, options)
	return order.merge(payments).merge(options)
      end

      def address(options)
	
      end

      def customer_data(payments)
	
      end

    end
  end
end

