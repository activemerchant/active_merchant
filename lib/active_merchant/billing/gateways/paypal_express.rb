require File.dirname(__FILE__) + '/paypal/paypal_common_api'
require File.dirname(__FILE__) + '/paypal/paypal_express_response'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalExpressGateway < Gateway
      include PaypalCommonAPI
      
      LIVE_REDIRECT_URL = 'https://www.paypal.com/cgibin/webscr?cmd=_express-checkout&token='
      TEST_REDIRECT_URL = 'https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token='

      def redirect_url
        test? ? TEST_REDIRECT_URL : LIVE_REDIRECT_URL 
      end
      
      def redirect_url_for(token)
        "#{redirect_url}#{token}"
      end
      
      def setup_authorization(money, options = {})
        requires!(options, :return_url, :cancel_return_url)
        
        commit 'SetExpressCheckout', build_setup_request('Authorization', money, options)
      end
      
      def setup_purchase(money, options = {})
        requires!(options, :return_url, :cancel_return_url)
        
        commit 'SetExpressCheckout', build_setup_request('Sale', money, options)
      end

      def details_for(token)
        commit 'GetExpressCheckoutDetails', build_get_details_request(token)
      end

      def authorize(money, options = {})
        requires!(options, :token, :payer_id)
      
        commit 'DoExpressCheckoutPayment', build_sale_or_authorization_request('Authorization', money, options)
      end

      def purchase(money, options = {})
        requires!(options, :token, :payer_id)
        
        commit 'DoExpressCheckoutPayment', build_sale_or_authorization_request('Sale', money, options)
      end

      private
      def build_get_details_request(token)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'GetExpressCheckoutDetailsReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'GetExpressCheckoutDetailsRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'Token', token
          end
        end

        xml.target!
      end
      
      def build_sale_or_authorization_request(action, money, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'DoExpressCheckoutPaymentReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoExpressCheckoutPaymentRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'n2:DoExpressCheckoutPaymentRequestDetails' do
              xml.tag! 'n2:PaymentAction', action
              xml.tag! 'n2:Token', options[:token]
              xml.tag! 'n2:PayerID', options[:payer_id]
              xml.tag! 'n2:PaymentDetails' do
                xml.tag! 'n2:OrderTotal', amount(money), 'currencyID' => currency(money)
                xml.tag! 'n2:NotifyURL', options[:notify_url]
              end
            end
          end
        end

        xml.target!
      end

      def build_setup_request(action, money, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'SetExpressCheckoutReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'SetExpressCheckoutRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'n2:SetExpressCheckoutRequestDetails' do
              xml.tag! 'n2:PaymentAction', action
              xml.tag! 'n2:OrderTotal', amount(money).to_f.zero? ? amount(100) : amount(money), 'currencyID' => currency(money)
              xml.tag! 'n2:MaxAmount', amount(options[:max_amount]), 'currencyID' => currency(options[:max_amount]) if options[:max_amount]
              add_address(xml, 'n2:Address', options[:billing_address] || options[:address])
              xml.tag! 'n2:AddressOverride', 1 if !options[:address_override].blank?
              xml.tag! 'n2:NoShipping', 1 if !options[:no_shipping].blank?
              xml.tag! 'n2:PageStyle', options[:page_style] unless options[:page_style].blank?
              xml.tag! 'n2:ReturnURL', options[:return_url]
              xml.tag! 'n2:CancelURL', options[:cancel_return_url]
              xml.tag! 'n2:IPAddress', options[:ip]
              xml.tag! 'n2:OrderDescription', options[:description]
              xml.tag! 'n2:BuyerEmail', options[:email] unless options[:email].blank?
              xml.tag! 'n2:InvoiceID', options[:order_id]
        
              # This should be set to the same locale as the shop
              # localeCode          - String
            end
          end
        end

        xml.target!
      end
      
      def build_response(success, message, response, options = {})
        PaypalExpressResponse.new(success, message, response, options)
      end
    end
  end
end
