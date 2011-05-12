require File.dirname(__FILE__) + '/paypal/paypal_common_api'
require File.dirname(__FILE__) + '/paypal/paypal_express_response'
require File.dirname(__FILE__) + '/paypal_express_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalExpressGateway < Gateway
      include PaypalCommonAPI
      include PaypalExpressCommon
      
      self.test_redirect_url = 'https://www.sandbox.paypal.com/cgi-bin/webscr'
      self.supported_countries = ['US']
      self.homepage_url = 'https://www.paypal.com/cgi-bin/webscr?cmd=xpt/merchant/ExpressCheckoutIntro-outside'
      self.display_name = 'PayPal Express Checkout'
      
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
        currency_code = options[:currency] || currency(money)
        
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'DoExpressCheckoutPaymentReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoExpressCheckoutPaymentRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'n2:DoExpressCheckoutPaymentRequestDetails' do
              xml.tag! 'n2:PaymentAction', action
              xml.tag! 'n2:Token', options[:token]
              xml.tag! 'n2:PayerID', options[:payer_id]
              xml.tag! 'n2:PaymentDetails' do
                xml.tag! 'n2:OrderTotal', localized_amount(money, currency_code), 'currencyID' => currency_code
                
                # All of the values must be included together and add up to the order total
                if [:subtotal, :shipping, :handling, :tax].all?{ |o| options.has_key?(o) }
                  xml.tag! 'n2:ItemTotal', localized_amount(options[:subtotal], currency_code), 'currencyID' => currency_code
                  xml.tag! 'n2:ShippingTotal', localized_amount(options[:shipping], currency_code),'currencyID' => currency_code
                  xml.tag! 'n2:HandlingTotal', localized_amount(options[:handling], currency_code),'currencyID' => currency_code
                  xml.tag! 'n2:TaxTotal', localized_amount(options[:tax], currency_code), 'currencyID' => currency_code
                end
                
                xml.tag! 'n2:NotifyURL', options[:notify_url]
                xml.tag! 'n2:ButtonSource', application_id.to_s.slice(0,32) unless application_id.blank?
                xml.tag! 'n2:InvoiceID', options[:order_id]
                xml.tag! 'n2:OrderDescription', options[:description]
              end
            end
          end
        end

        xml.target!
      end

      def build_setup_request(action, money, options)
        currency_code = options[:currency] || currency(money)
        
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'SetExpressCheckoutReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'SetExpressCheckoutRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'n2:SetExpressCheckoutRequestDetails' do
              if options[:max_amount]
                xml.tag! 'n2:MaxAmount', localized_amount(options[:max_amount], currency_code), 'currencyID' => currency_code
              end
              if !options[:allow_note].nil?
                xml.tag! 'n2:AllowNote', options[:allow_note] ? '1' : '0'
              end
              xml.tag! 'n2:PaymentDetails' do
                xml.tag! 'n2:OrderTotal', amount(money).to_f.zero? ? localized_amount(100, currency_code) : localized_amount(money, currency_code), 'currencyID' => currency_code
                # All of the values must be included together and add up to the order total
                if [:subtotal, :shipping, :handling, :tax].all? { |o| options.has_key?(o) }
                  xml.tag! 'n2:ItemTotal', localized_amount(options[:subtotal], currency_code), 'currencyID' => currency_code
                  xml.tag! 'n2:ShippingTotal', localized_amount(options[:shipping], currency_code), 'currencyID' => currency_code
                  xml.tag! 'n2:HandlingTotal', localized_amount(options[:handling], currency_code), 'currencyID' => currency_code
                  xml.tag! 'n2:TaxTotal', localized_amount(options[:tax], currency_code), 'currencyID' => currency_code
                end

                xml.tag! 'n2:OrderDescription', options[:description]
                xml.tag! 'n2:InvoiceID', options[:order_id]

                if options[:items]
                  options[:items].each do |item|
                    xml.tag! 'n2:PaymentDetailsItem' do
                      xml.tag! 'n2:Name', item[:name]
                      xml.tag! 'n2:Number', item[:number]
                      xml.tag! 'n2:Quantity', item[:quantity]
                      if item[:amount]
                        xml.tag! 'n2:Amount', localized_amount(item[:amount], currency_code), 'currencyID' => currency_code
                      end
                      xml.tag! 'n2:Description', item[:description]
                      xml.tag! 'n2:ItemURL', item[:url]
                    end
                  end
                end

                xml.tag! 'n2:PaymentAction', action
              end

              add_address(xml, 'n2:Address', options[:shipping_address] || options[:address])
              xml.tag! 'n2:AddressOverride', options[:address_override] ? '1' : '0'
              xml.tag! 'n2:NoShipping', options[:no_shipping] ? '1' : '0'
              xml.tag! 'n2:ReturnURL', options[:return_url]
              xml.tag! 'n2:CancelURL', options[:cancel_return_url]
              xml.tag! 'n2:IPAddress', options[:ip] unless options[:ip].blank?
              xml.tag! 'n2:BuyerEmail', options[:email] unless options[:email].blank?
              
              if options[:billing_agreement]
                xml.tag! 'n2:BillingAgreementDetails' do
                  xml.tag! 'n2:BillingType', options[:billing_agreement][:type]
                  xml.tag! 'n2:BillingAgreementDescription', options[:billing_agreement][:description]
                  xml.tag! 'n2:PaymentType', options[:billing_agreement][:payment_type] || 'InstantOnly'
                end
              end
        
              # Customization of the payment page
              xml.tag! 'n2:PageStyle', options[:page_style] unless options[:page_style].blank?
              xml.tag! 'n2:cpp-header-image', options[:header_image] unless options[:header_image].blank?
              xml.tag! 'n2:cpp-header-back-color', options[:header_background_color] unless options[:header_background_color].blank?
              xml.tag! 'n2:cpp-header-border-color', options[:header_border_color] unless options[:header_border_color].blank?
              xml.tag! 'n2:cpp-payflow-color', options[:background_color] unless options[:background_color].blank?
              
              if options[:allow_guest_checkout]
                xml.tag! 'n2:SolutionType', 'Sole'
                xml.tag! 'n2:LandingPage', 'Billing'
              end
              
              xml.tag! 'n2:LocaleCode', options[:locale] unless options[:locale].blank?
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
