require 'rubygems'
require 'nokogiri'
require 'net/http'
require 'net/https'
require 'uri'
require 'openssl'
require 'open-uri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CheckoutGateway < Gateway

      class PaymentPostData < PostData
        self.required_fields = [ :OrderReference, :CardNumber, :CardExpiry, :CardHolderName, :CardType, :MerchantID, :MerchantKey, :Amount, :Currency ]
      end

      self.default_currency = 'USD'
      self.money_format = :decimals

      self.supported_countries = ['AR', 'AT', 'BE', 'BR', 'CA', 'CH', 'CL', 'CN', 'CO', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GB', 'HK', 'ID', 'IE', 'IL', 'IN', 'IT', 'JP', 'KR', 'LU', 'MX', 'MY', 'NL', 'NO', 'PA', 'PE', 'PH', 'PL', 'PT', 'RU', 'SE', 'SG', 'TH', 'TR', 'TW', 'US', 'VN', 'ZA']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      self.homepage_url = 'https://www.checkout.com/'
      self.display_name = 'Checkout.com'

      def initialize(options = {})

        if options[:gatewayURL]
          self.live_url = self.test_url = options[:gatewayURL]
        else
          # Set default gateway
          self.live_url = self.test_url = 'https://api.checkout.com/Process/gateway.aspx'
        end

        requires!(options, :MerchantCode, :Password)
        super
      end

      def purchase(money, creditcard, options = {})

        post = PaymentPostData.new

        post[:Action] = 1
        
        add_credentials(post, options)
        add_invoice(post, money, options)
        add_creditcard(post, creditcard)

        # Options
        add_billing_info(post, options)
        add_shipping_info(post, options)
        add_user_defined_fields(post, options)
        add_other_fields(post, options)

        commit(build_xml(post))
      end

      def authorize(money, creditcard, options = {})

        post = PaymentPostData.new
        
        post[:Action] = 4
        
        add_credentials(post, options)
        add_invoice(post, money, options)
        add_creditcard(post, creditcard)

        # Options
        add_billing_info(post, options)
        add_shipping_info(post, options)
        add_user_defined_fields(post, options)
        add_other_fields(post, options)

        commit(build_xml(post))
      end

      def capture(money, authorization, options = {})

        post = PaymentPostData.new
        
        post[:Action] = 5
        post[:transid] = authorization
        
        add_credentials(post, options)
        add_invoice(post, money, options)

        add_other_fields(post, options)

        commit(build_xml_capture(post))
        
      end

      private

      def add_credentials(post, options)

        post[:MerchantID] = @options[:MerchantCode]
        post[:MerchantPwd] = @options[:Password]

      end

      def add_invoice(post, money, options)

        post[:Amount] = amount(money)
        post[:Currency] = options[:currency]
        post[:OrderReference] = options[:order_id]

      end

      def add_creditcard(post, creditcard)

        post[:CardNumber] = creditcard.number
        post[:CardExpiryMonth] = creditcard.month.to_s.rjust(2, '0')
        post[:CardExpiryYear] = creditcard.year
        post[:CardHolderName] = creditcard.name

        if creditcard.verification_value?
          post[:CSC] = creditcard.verification_value
        end

      end

      def add_billing_info(post, options)

        post[:billing_address] =  options[:billing_address]

      end

      def add_shipping_info(post, options)

        post[:shipping_address] =  options[:shipping_address]

      end

      def add_user_defined_fields(post, options)

        post[:udf1] =  options[:udf1]
        post[:udf2] =  options[:udf2]
        post[:udf3] =  options[:udf3]
        post[:udf4] =  options[:udf4]
        post[:udf5] =  options[:udf5]

      end

      def add_other_fields(post, options)

        post[:ip] =  options[:ip]
        post[:email] =  options[:email]
        post[:merchantcustomerid] =  options[:customer]

      end

      def commit(xml_request)

        response_body = ssl_post(URI.parse(live_url), xml_request)

        xml_response = parse_xml(response_body, 'response')

            responsemsg = "Invalid Response"
            responsecode = "9998"
            responsetranid = ""

            if xml_response[:result]
              responsemsg = xml_response[:result]
            else
              responsemsg = xml_response[:error_text]
            end

            if xml_response[:responsecode]
              responsecode = xml_response[:responsecode]
            end

            if xml_response[ :tranid]
              responsetranid = xml_response[:tranid]
            end

            Response.new(responsecode == "0", responsemsg, xml_response,
              :authorization => responsetranid,
              :test => test?
          )

      end

      def build_xml(post)

        builder = Nokogiri::XML::Builder.new do |xml|

        xml.request {
          xml.merchantid_ post[:MerchantID];
          xml.password_ post[:MerchantPwd];
          xml.action_ post[:Action];
          xml.bill_amount_ post[:Amount];
          xml.bill_currencycode_ post[:Currency];
          xml.bill_cardholder_ post[:CardHolderName];
          xml.bill_cc_ post[:CardNumber];
          xml.bill_expmonth_ post[:CardExpiryMonth];
          xml.bill_expyear_ post[:CardExpiryYear];
          xml.bill_cvv2_ post[:CSC];
          xml.trackid_ post[:OrderReference];

          # Options
          # Billing Info
          xml.bill_address_ post[:billing_address][:address1];
          xml.bill_city_    post[:billing_address][:city];
          xml.bill_state_   post[:billing_address][:state];
          xml.bill_postal_  post[:billing_address][:zip];
          xml.bill_country_ post[:billing_address][:country];
          xml.bill_phone_   post[:billing_address][:phone];
          xml.bill_email_   post[:email];

          xml.bill_customerip_ post[:ip];

          # Shipping Info
          xml.ship_address_   post[:shipping_address][:address1];
          xml.ship_address2_  post[:shipping_address][:address2];
          xml.ship_city_    post[:shipping_address][:city];
          xml.ship_state_   post[:shipping_address][:state];
          xml.ship_postal_  post[:shipping_address][:zip];
          xml.ship_country_   post[:shipping_address][:country];
          xml.ship_phone_   post[:shipping_address][:phone];

          # User Defined Fields
          xml.udf1_ post[:udf1];
          xml.udf2_ post[:udf2];
          xml.udf3_ post[:udf3];
          xml.udf4_ post[:udf4];
          xml.udf5_ post[:udf5];

          # Other Fields
          xml.merchantcustomerid_ post[:merchantcustomerid];
        }
        end
        
        builder.to_xml

      end

      def build_xml_capture(post)

        builder = Nokogiri::XML::Builder.new do |xml|

        xml.request {
          xml.merchantid_ post[:MerchantID];
          xml.password_ post[:MerchantPwd];

          xml.action_ post[:Action];

          xml.bill_amount_ post[:Amount];
          xml.bill_currencycode_ post[:Currency];

          xml.trackid_ post[:OrderReference];
          xml.transid_ post[:transid];

          xml.bill_customerip_ post[:ip];

          # Options
          # User Defined Fields
          xml.udf1_ post[:udf1];
          xml.udf2_ post[:udf2];
          xml.udf3_ post[:udf3];
          xml.udf4_ post[:udf4];
          xml.udf5_ post[:udf5];

        }
        end
        
        builder.to_xml
      end

      def amount(money)
        return nil if money.nil?

        cents =  if money.respond_to?(:cents)
            ActiveMerchant.deprecated "Support for Money objects is deprecated and will be removed from a future release of ActiveMerchant. Please use an Integer value in cents"
            money.cents
        else
          money
        end

        if money.is_a?(String)
            raise ArgumentError, 'money amount must be a positive Integer in cents.'
        end

        if self.money_format == :cents
            cents.to_s
        else
            sprintf("%.2f", cents.to_f / 100)
        end
      end

      def parse_xml(xml, parent)

        response = Hash[]

        doc = Nokogiri::XML(CGI.unescapeHTML(xml))

        body = doc.xpath('//'+ parent)


        body.children.each do |node|

          if node.text?
            next
          elsif (node.elements.size == 0)
            response[node.name.downcase.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{node.name.downcase}_#{childnode.name.downcase}"
              response[name.to_sym] = childnode.text
            end
          end
        end

        response

      end
    end
  end
end
