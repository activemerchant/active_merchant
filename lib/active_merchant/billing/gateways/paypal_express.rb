require 'active_merchant/billing/gateways/paypal/paypal_common_api'
require 'active_merchant/billing/gateways/paypal/paypal_express_response'
require 'active_merchant/billing/gateways/paypal/paypal_recurring_api'
require 'active_merchant/billing/gateways/paypal_express_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalExpressGateway < Gateway
      include PaypalCommonAPI
      include PaypalExpressCommon
      include PaypalRecurringApi

      NON_STANDARD_LOCALE_CODES = {
        'DK' => 'da_DK',
        'IL' => 'he_IL',
        'ID' => 'id_ID',
        'JP' => 'jp_JP',
        'NO' => 'no_NO',
        'BR' => 'pt_BR',
        'RU' => 'ru_RU',
        'SE' => 'sv_SE',
        'TH' => 'th_TH',
        'TR' => 'tr_TR',
        'CN' => 'zh_CN',
        'HK' => 'zh_HK',
        'TW' => 'zh_TW'
      }

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

      def store(token, options = {})
        commit 'CreateBillingAgreement', build_create_billing_agreement_request(token, options)
      end

      def unstore(token, options = {})
        commit 'BAUpdate', build_cancel_billing_agreement_request(token)
      end

      def agreement_details(reference_id, options = {})
        commit 'BAUpdate', build_details_billing_agreement_request(reference_id)
      end

      def authorize_reference_transaction(money, options = {})
        requires!(options, :reference_id, :payment_type, :invoice_id, :description, :ip)

        commit 'DoReferenceTransaction', build_reference_transaction_request('Authorization', money, options)
      end

      def reference_transaction(money, options = {})
        requires!(options, :reference_id)

        commit 'DoReferenceTransaction', build_reference_transaction_request('Sale', money, options)
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
              add_payment_details(xml, money, currency_code, options)
            end
          end
        end

        xml.target!
      end

      def build_setup_request(action, money, options)
        currency_code = options[:currency] || currency(money)
        options[:payment_action] = action
        options[:express_request] = true
        options[:shipping_address] ||= options[:address]

        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'SetExpressCheckoutReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'SetExpressCheckoutRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'n2:SetExpressCheckoutRequestDetails' do
              xml.tag! 'n2:ReturnURL', options[:return_url]
              xml.tag! 'n2:CancelURL', options[:cancel_return_url]
              if options[:max_amount]
                xml.tag! 'n2:MaxAmount', localized_amount(options[:max_amount], currency_code), 'currencyID' => currency_code
              end
              xml.tag! 'n2:ReqBillingAddress', options[:req_billing_address] ? '1' : '0'
              xml.tag! 'n2:NoShipping', options[:no_shipping] ? '1' : '0'
              xml.tag! 'n2:AddressOverride', options[:address_override] ? '1' : '0'
              xml.tag! 'n2:LocaleCode', locale_code(options[:locale]) unless options[:locale].blank?
              xml.tag! 'n2:BrandName', options[:brand_name] unless options[:brand_name].blank?
              # Customization of the payment page
              xml.tag! 'n2:PageStyle', options[:page_style] unless options[:page_style].blank?
              xml.tag! 'n2:cpp-logo-image', options[:logo_image] unless options[:logo_image].blank?
              xml.tag! 'n2:cpp-header-image', options[:header_image] unless options[:header_image].blank?
              xml.tag! 'n2:cpp-header-border-color', options[:header_border_color] unless options[:header_border_color].blank?
              xml.tag! 'n2:cpp-header-back-color', options[:header_background_color] unless options[:header_background_color].blank?
              xml.tag! 'n2:cpp-payflow-color', options[:background_color] unless options[:background_color].blank?
              if options[:allow_guest_checkout]
                xml.tag! 'n2:SolutionType', 'Sole'
                xml.tag! 'n2:LandingPage', options[:landing_page] || 'Billing'
              end
              xml.tag! 'n2:BuyerEmail', options[:email] unless options[:email].blank?

              if options[:billing_agreement]
                xml.tag! 'n2:BillingAgreementDetails' do
                  xml.tag! 'n2:BillingType', options[:billing_agreement][:type]
                  xml.tag! 'n2:BillingAgreementDescription', options[:billing_agreement][:description]
                  xml.tag! 'n2:PaymentType', options[:billing_agreement][:payment_type] || 'InstantOnly'
                end
              end

              if !options[:allow_note].nil?
                xml.tag! 'n2:AllowNote', options[:allow_note] ? '1' : '0'
              end

              if options[:funding_sources]
                xml.tag! 'n2:FundingSourceDetails' do
                  xml.tag! 'n2:UserSelectedFundingSource', options[:funding_sources][:source]
                end
              end

              xml.tag! 'n2:CallbackURL', options[:callback_url] unless options[:callback_url].blank?

              add_payment_details(xml, money, currency_code, options)
              if options[:shipping_options]
                options[:shipping_options].each do |shipping_option|
                  xml.tag! 'n2:FlatRateShippingOptions' do
                    xml.tag! 'n2:ShippingOptionIsDefault', shipping_option[:default]
                    xml.tag! 'n2:ShippingOptionAmount', localized_amount(shipping_option[:amount], currency_code), 'currencyID' => currency_code
                    xml.tag! 'n2:ShippingOptionName', shipping_option[:name]
                  end
                end
              end

              xml.tag! 'n2:CallbackTimeout', options[:callback_timeout] unless options[:callback_timeout].blank?
              xml.tag! 'n2:CallbackVersion', options[:callback_version] unless options[:callback_version].blank?

              if options.has_key?(:allow_buyer_optin)
                xml.tag! 'n2:BuyerEmailOptInEnable', (options[:allow_buyer_optin] ? '1' : '0')
              end
            end
          end
        end

        xml.target!
      end

      def build_create_billing_agreement_request(token, options = {})
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'CreateBillingAgreementReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'CreateBillingAgreementRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'Token', token
          end
        end

        xml.target!
      end

      def build_cancel_billing_agreement_request(token)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'BillAgreementUpdateReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'BAUpdateRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'ReferenceID', token
            xml.tag! 'BillingAgreementStatus', "Canceled"
          end
        end

        xml.target!
      end

      def build_details_billing_agreement_request(reference_id)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'BillAgreementUpdateReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'BAUpdateRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'ReferenceID', reference_id
          end
        end

        xml.target!
      end

      def build_reference_transaction_request(action, money, options)
        currency_code = options[:currency] || currency(money)

        # I am not sure why it's set like this for express gateway
        # but I don't want to break the existing behavior
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'DoReferenceTransactionReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoReferenceTransactionRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'n2:DoReferenceTransactionRequestDetails' do
              xml.tag! 'n2:ReferenceID', options[:reference_id]
              xml.tag! 'n2:PaymentAction', action
              xml.tag! 'n2:PaymentType', options[:payment_type] || 'Any'
              add_payment_details(xml, money, currency_code, options)
              xml.tag! 'n2:IPAddress', options[:ip]
            end
          end
        end

        xml.target!
      end

      def build_response(success, message, response, options = {})
        PaypalExpressResponse.new(success, message, response, options)
      end

      def locale_code(country_code)
        NON_STANDARD_LOCALE_CODES[country_code] || country_code
      end
    end
  end
end
