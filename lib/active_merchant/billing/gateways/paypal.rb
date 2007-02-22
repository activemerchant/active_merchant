require File.dirname(__FILE__) + '/paypal/paypal_common_api'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalGateway < Gateway
      include PaypalCommonAPI
      
      def self.supported_cardtypes
        [:visa, :master, :american_express, :discover]
      end
      
      def authorize(money, credit_card, options = {})
        requires!(options, :ip)
        
        if result = test_result_from_cc_number(credit_card.number)
          return result
        end

        commit 'DoDirectPayment', build_sale_or_authorization_request('Authorization', money, credit_card, options)
      end

      def purchase(money, credit_card, options = {})
        requires!(options, :ip)
        
        if result = test_result_from_cc_number(credit_card.number)
          return result
        end
        
        commit 'DoDirectPayment', build_sale_or_authorization_request('Sale', money, credit_card, options)
      end
      
      def express
        @express ||= PaypalExpressGateway.new(@options)
      end
      
      private
      def build_sale_or_authorization_request(action, money, credit_card, options)
        shipping_address = options[:shipping_address] || options[:address]
       
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'DoDirectPaymentReq', 'xmlns' => 'urn:ebay:api:PayPalAPI' do
          xml.tag! 'DoDirectPaymentRequest', 'xmlns:n2' => 'urn:ebay:apis:eBLBaseComponents' do
            xml.tag! 'n2:Version', '2.0'
            xml.tag! 'n2:DoDirectPaymentRequestDetails' do
              xml.tag! 'n2:PaymentAction', action
              xml.tag! 'n2:PaymentDetails' do
                xml.tag! 'n2:OrderTotal', amount(money), 'currencyID' => currency(money)
                xml.tag! 'n2:NotifyURL', options[:notify_url]
                
                add_address(xml, 'n2:ShipToAddress', shipping_address)
              end
              add_credit_card(xml, credit_card, options[:billing_address] || shipping_address)
              xml.tag! 'n2:IPAddress', options[:ip]
            end
          end
        end

        xml.target!        
      end
      
      def add_credit_card(xml, credit_card, address)
        xml.tag! 'n2:CreditCard' do
          xml.tag! 'n2:CreditCardType', credit_card_type(credit_card.type)
          xml.tag! 'n2:CreditCardNumber', credit_card.number
          xml.tag! 'n2:ExpMonth', sprintf("%.2i", credit_card.month)
          xml.tag! 'n2:ExpYear', sprintf("%.4i", credit_card.year)
          xml.tag! 'n2:CVV2', credit_card.verification_value
          
          xml.tag! 'n2:CardOwner' do
            xml.tag! 'n2:PayerName' do
              xml.tag! 'n2:FirstName', credit_card.first_name
              xml.tag! 'n2:LastName', credit_card.last_name
            end
            
            add_address(xml, 'n2:Address', address)
          end
        end
      end

      def credit_card_type(type)
        case type
        when 'visa'             then 'Visa'
        when 'master'           then 'MasterCard'
        when 'discover'         then 'Discover'
        when 'american_express' then 'Amex'
        end
      end
      
      def build_response(success, message, response, options = {})
         Response.new(success, message, response, options)
      end
    end
  end
end
