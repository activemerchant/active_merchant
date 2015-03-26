require 'active_merchant/billing/gateways/payflow/payflow_common_api'
require 'active_merchant/billing/gateways/payflow/payflow_express_response'
require 'active_merchant/billing/gateways/paypal_express_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
      # ==General Parameters
      # The following parameters are supported for #setup_authorization, #setup_purchase, #authorize and #purchase transactions. I've read
      # in the docs that they recommend you pass the exact same parameters to both setup and authorize/purchase.
      #
      # This information was gleaned from a mix of:
      # * PayFlow documentation
      #   * for key value pairs: {Express Checkout for Payflow Pro (PDF)}[https://cms.paypal.com/cms_content/US/en_US/files/developer/PFP_ExpressCheckout_PP.pdf]
      #   * XMLPay: {Payflow Pro XMLPay Developer's Guide (PDF)}[https://cms.paypal.com/cms_content/US/en_US/files/developer/PP_PayflowPro_XMLPay_Guide.pdf]
      # * previous ActiveMerchant code
      # * trial & error
      #
      # The following parameters are currently supported.
      # [<tt>:ip</tt>] (opt) Customer IP Address
      # [<tt>:order_id</tt>] (opt) An order or invoice number. This will be passed through to the Payflow backend at manager.paypal.com, and show up as "Supplier Reference #"
      # [<tt>:description</tt>] (opt) Order description, shown to buyer (after redirected to PayPal). If Order Line Items are used (see below), then the description is suppressed. This will not be passed through to the Payflow backend.
      # [<tt>:billing_address</tt>] (opt) See ActiveMerchant::Billing::Gateway for details
      # [<tt>:shipping_address</tt>] (opt) See ActiveMerchant::Billing::Gateway for details
      # [<tt>:currency</tt>] (req) Currency of transaction, will be set to USD by default for PayFlow Express if not specified
      # [<tt>:email</tt>] (opt) Email of buyer; used to pre-fill PayPal login screen
      # [<tt>:payer_id</tt>] (opt) Unique PayPal buyer account identification number, as returned by details_for request
      # [<tt>:token</tt>] (req for #authorize & #purchase) Token returned by setup transaction
      # [<tt>:no_shipping</tt>] (opt) Boolean for whether or not to display shipping address to buyer
      # [<tt>:address_override</tt>] (opt) Boolean. If true, display shipping address passed by parameters, rather than shipping address on file with PayPal
      # [<tt>:allow_note</tt>] (opt) Boolean for permitting buyer to add note during checkout. Note contents can be retrieved with details_for transaction
      # [<tt>:return_url</tt>] (req) URL to which the buyer’s browser is returned after choosing to pay.
      # [<tt>:cancel_return_url</tt>] (req) URL to which the buyer is returned if the buyer cancels the order.
      # [<tt>:notify_url</tt>] (opt) Your URL for receiving Instant Payment Notification (IPN) about this transaction.
      # [<tt>:comment</tt>] (opt) Comment field which will be reported to Payflow backend (at manager.paypal.com) as Comment1
      # [<tt>:comment2</tt>] (opt) Comment field which will be reported to Payflow backend (at manager.paypal.com) as Comment2
      # [<tt>:discount</tt>] (opt) Total discounts in cents
      #
      # ==Line Items
      # Support for order line items is available, but has to be enabled on the PayFlow backend. This is what I was told by Todd Sieber at Technical Support:
      #
      # <em>You will need to call Payflow Support at 1-888-883-9770, choose option #2.  Request that they update your account in "Pandora" under Product Settings >> PayPal Mark and update the Features Bitmap to 1111111111111112.  This is 15 ones and a two.</em>
      #
      # See here[https://www.x.com/message/206214#206214] for the forum discussion (requires login to {x.com}[https://x.com]
      #
      # [<tt>:items</tt>] (opt) Array of Order Line Items hashes. These are shown to the buyer after redirect to PayPal.
      #
      #
      #
      #                   The following keys are supported for line items:
      #                   [<tt>:name</tt>] Name of line item
      #                   [<tt>:description</tt>] Description of line item
      #                   [<tt>:amount</tt>] Line Item Amount in Cents (as Integer)
      #                   [<tt>:quantity</tt>] Line Item Quantity (default to 1 if left blank)
      #
      # ====Customization of Payment Page
      # [<tt>:page_style</tt>] (opt) Your URL for receiving Instant Payment Notification (IPN) about this transaction.
      # [<tt>:header_image</tt>] (opt) Your URL for receiving Instant Payment Notification (IPN) about this transaction.
      # [<tt>:background_color</tt>] (opt) Your URL for receiving Instant Payment Notification (IPN) about this transaction.
      # ====Additional options for old Checkout Experience, being phased out in 2010 and 2011
      # [<tt>:header_background_color</tt>] (opt) Your URL for receiving Instant Payment Notification (IPN) about this transaction.
      # [<tt>:header_border_color</tt>] (opt) Your URL for receiving Instant Payment Notification (IPN) about this transaction.


    class PayflowExpressGateway < Gateway
      include PayflowCommonAPI
      include PaypalExpressCommon

      self.test_redirect_url = 'https://www.sandbox.paypal.com/cgi-bin/webscr'
      self.homepage_url = 'https://www.paypal.com/cgi-bin/webscr?cmd=xpt/merchant/ExpressCheckoutIntro-outside'
      self.display_name = 'PayPal Express Checkout'

      def authorize(money, options = {})
        requires!(options, :token, :payer_id)
        request = build_sale_or_authorization_request('Authorization', money, options)
        commit(request, options)
      end

      def purchase(money, options = {})
        requires!(options, :token, :payer_id)
        request = build_sale_or_authorization_request('Sale', money, options)
        commit(request, options)
      end

      def refund(money, identification, options = {})
        request = build_reference_request(:credit, money, identification, options)
        commit(request, options)
      end

      def credit(money, identification, options = {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end

      def setup_authorization(money, options = {})
        requires!(options, :return_url, :cancel_return_url)

        request = build_setup_express_sale_or_authorization_request('Authorization', money, options)
        commit(request, options)
      end

      def setup_purchase(money, options = {})
        requires!(options, :return_url, :cancel_return_url)

        request = build_setup_express_sale_or_authorization_request('Sale', money, options)
        commit(request, options)
      end

      def details_for(token)
        request = build_get_express_details_request(token)
        commit(request, options)
      end

      private
      def build_get_express_details_request(token)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'GetExpressCheckout' do
          xml.tag! 'Authorization' do
            xml.tag! 'PayData' do
              xml.tag! 'Tender' do
                xml.tag! 'PayPal' do
                  xml.tag! 'Token', token
                end
              end
            end
          end
        end
        xml.target!
      end

      def build_setup_express_sale_or_authorization_request(action, money, options = {})
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'SetExpressCheckout' do
          xml.tag! action do
            add_pay_data xml, money, options
          end
        end
        xml.target!
      end

      def build_sale_or_authorization_request(action, money, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'DoExpressCheckout' do
          xml.tag! action do
            add_pay_data xml, money, options
          end
        end
        xml.target!
      end

      def add_pay_data(xml, money, options)
        xml.tag! 'PayData' do
          xml.tag! 'Invoice' do
            xml.tag! 'CustIP', options[:ip] unless options[:ip].blank?
            xml.tag! 'InvNum', options[:order_id] unless options[:order_id].blank?
            # Description field will be shown to buyer, unless line items are also being supplied (then only line items are shown).
            xml.tag! 'Description', options[:description] unless options[:description].blank?
            # Comment, Comment2 should make it to the backend at manager.paypal.com, as with Payflow credit card transactions
            # but that doesn't seem to work (yet?). See: https://www.x.com/thread/51908?tstart=0
            xml.tag! 'Comment', options[:comment] unless options[:comment].nil?
            xml.tag!('ExtData', 'Name'=> 'COMMENT2', 'Value'=> options[:comment2]) unless options[:comment2].nil?

            billing_address = options[:billing_address] || options[:address]
            add_address(xml, 'BillTo', billing_address, options) if billing_address
            add_address(xml, 'ShipTo', options[:shipping_address], options) if options[:shipping_address]

            # Note: To get order line-items to show up with Payflow Express, this feature has to be enabled on the backend.
            # Call Support at 888 883 9770, press 2. Then request that they update your account in "Pandora" under Product Settings >> PayPal
            # Mark and update the Features Bitmap to 1111111111111112.  This is 15 ones and a two.
            # See here for the forum discussion: https://www.x.com/message/206214#206214
            items = options[:items] || []
            items.each_with_index do |item, index|
              xml.tag! 'ExtData', 'Name' => "L_DESC#{index}", 'Value' => item[:description]
              xml.tag! 'ExtData', 'Name' => "L_COST#{index}", 'Value' => amount(item[:amount])
              xml.tag! 'ExtData', 'Name' => "L_QTY#{index}", 'Value' => item[:quantity] || '1'
              xml.tag! 'ExtData', 'Name' => "L_NAME#{index}", 'Value' => item[:name]
              # Note: An ItemURL is supported in Paypal Express (different API), but not PayFlow Express, as far as I can tell.
              # L_URLn nor L_ITEMURLn seem to work
            end
            if items.any?
              xml.tag! 'ExtData', 'Name' => 'CURRENCY', 'Value' => options[:currency] || currency(money)
              xml.tag! 'ExtData', 'Name' => "ITEMAMT", 'Value' => amount(options[:subtotal] || money)
            end
            xml.tag! 'DiscountAmt', amount(options[:discount]) if options[:discount]
            xml.tag! 'TotalAmt', amount(money), 'Currency' => options[:currency] || currency(money)

          end

          xml.tag! 'Tender' do
            add_paypal_details(xml, options)
          end
        end
      end

      def add_paypal_details(xml, options)
         xml.tag! 'PayPal' do
          xml.tag! 'EMail', options[:email] unless options[:email].blank?
          xml.tag! 'ReturnURL', options[:return_url] unless options[:return_url].blank?
          xml.tag! 'CancelURL', options[:cancel_return_url] unless options[:cancel_return_url].blank?
          xml.tag! 'NotifyURL', options[:notify_url] unless options[:notify_url].blank?
          xml.tag! 'PayerID', options[:payer_id] unless options[:payer_id].blank?
          xml.tag! 'Token', options[:token] unless options[:token].blank?
          xml.tag! 'NoShipping', options[:no_shipping] ? '1' : '0'
          xml.tag! 'AddressOverride', options[:address_override] ? '1' : '0'
          xml.tag! 'ButtonSource', application_id.to_s.slice(0,32) unless application_id.blank?

          # Customization of the payment page
          xml.tag! 'PageStyle', options[:page_style] unless options[:page_style].blank?
          xml.tag! 'HeaderImage', options[:header_image] unless options[:header_image].blank?
          xml.tag! 'PayflowColor', options[:background_color] unless options[:background_color].blank?
          # Note: HeaderImage and PayflowColor apply to both the new (as of 2010) and the old checkout experience
          # HeaderBackColor and HeaderBorderColor apply only to the old checkout experience which is being phased out.
          xml.tag! 'HeaderBackColor', options[:header_background_color] unless options[:header_background_color].blank?
          xml.tag! 'HeaderBorderColor', options[:header_border_color] unless options[:header_border_color].blank?
          xml.tag! 'ExtData', 'Name' => 'ALLOWNOTE', 'Value' => options[:allow_note]
        end
      end

      def build_response(success, message, response, options = {})
        PayflowExpressResponse.new(success, message, response, options)
      end
    end
  end
end

