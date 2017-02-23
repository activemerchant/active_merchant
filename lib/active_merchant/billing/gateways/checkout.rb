require 'rubygems'
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CheckoutGateway < Gateway
      self.default_currency = 'USD'
      self.money_format = :cents

      self.supported_countries = ['AD', 'AT', 'BE', 'BG', 'CH', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FO', 'FI', 'FR', 'GB', 'GI', 'GL', 'GR', 'HR', 'HU', 'IE', 'IS', 'IL', 'IT', 'LI', 'LT', 'LU', 'LV', 'MC', 'MT', 'NL', 'NO', 'PL', 'PT', 'RO', 'SE', 'SI', 'SM', 'SK', 'SJ', 'TR', 'VA']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      self.homepage_url = 'https://www.checkout.com/'
      self.display_name = 'Checkout.com'

      self.live_url = 'https://api.checkout.com/Process/gateway.aspx'

      ACTIONS = {
        'purchase' => '1',
        'authorize' => '4',
        'capture' => '5',
        'refund' => '2',
        'void_purchase' => '3',
        'void_authorize' => '9',
        'void_capture' => '7'
      }

      def initialize(options = {})
        requires!(options, :merchant_id, :password)
        super
      end

      def purchase(amount, payment_method, options)
        commit('purchase', amount, options) do |xml|
          add_credentials(xml, options)
          add_invoice(xml, amount, options)
          add_track_id(xml, options[:order_id] || generate_unique_id)
          add_payment_method(xml, payment_method)
          add_billing_info(xml, options)
          add_shipping_info(xml, options)
          add_user_defined_fields(xml, options)
          add_other_fields(xml, options)
        end
      end

      def authorize(amount, payment_method, options)
        commit('authorize', amount, options) do |xml|
          add_credentials(xml, options)
          add_invoice(xml, amount, options)
          add_track_id(xml, options[:order_id] || generate_unique_id)
          add_payment_method(xml, payment_method)
          add_billing_info(xml, options)
          add_shipping_info(xml, options)
          add_user_defined_fields(xml, options)
          add_other_fields(xml, options)
        end
      end

      def capture(amount, authorization, options = {})
        commit('capture', amount, options) do |xml|
          add_credentials(xml, options)
          add_reference(xml, authorization)
          add_invoice(xml, amount, options)
          add_user_defined_fields(xml, options)
          add_other_fields(xml, options)
        end
      end

      def void(authorization, options = {})
        _, _, orig_action, amount, currency = split_authorization(authorization)
        commit("void_#{orig_action}") do |xml|
          add_credentials(xml, options)
          add_invoice(xml, amount.to_i, options.merge(currency: currency))
          add_reference(xml, authorization)
        end
      end

      def refund(amount, authorization, options = {})
        commit('refund') do |xml|
          add_credentials(xml, options)
          add_invoice(xml, amount.to_i, options)
          add_reference(xml, authorization)
        end
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      def add_credentials(xml, options)
        xml.merchantid_ @options[:merchant_id]
        xml.password_ @options[:password]
      end

      def add_invoice(xml, amount, options)
        xml.bill_amount_ amount(amount)
        xml.bill_currencycode_ options[:currency] || currency(amount)
      end

      def add_payment_method(xml, payment_method)
        xml.bill_cardholder_ payment_method.name
        xml.bill_cc_ payment_method.number
        xml.bill_expmonth_ format(payment_method.month, :two_digits)
        xml.bill_expyear_ format(payment_method.year, :four_digits)
        if payment_method.verification_value?
          xml.bill_cvv2_ payment_method.verification_value
        end
      end

      def add_billing_info(xml, options)
        if options[:billing_address]
          xml.bill_address_ options[:billing_address][:address1]
          xml.bill_city_    options[:billing_address][:city]
          xml.bill_state_   options[:billing_address][:state]
          xml.bill_postal_  options[:billing_address][:zip]
          xml.bill_country_ options[:billing_address][:country]
          xml.bill_phone_   options[:billing_address][:phone]
        end
      end

      def add_shipping_info(xml, options)
        if options[:shipping_address]
          xml.ship_address_   options[:shipping_address][:address1]
          xml.ship_address2_  options[:shipping_address][:address2]
          xml.ship_city_    options[:shipping_address][:city]
          xml.ship_state_   options[:shipping_address][:state]
          xml.ship_postal_  options[:shipping_address][:zip]
          xml.ship_country_   options[:shipping_address][:country]
          xml.ship_phone_   options[:shipping_address][:phone]
        end
      end

      def add_user_defined_fields(xml, options)
        xml.udf1_ options[:udf1]
        xml.udf2_ options[:udf2]
        xml.udf3_ options[:udf3]
        xml.udf4_ options[:udf4]
        xml.udf5_ options[:udf5]
      end

      def add_other_fields(xml, options)
        xml.bill_email_   options[:email]
        xml.bill_customerip_ options[:ip]
        xml.merchantcustomerid_ options[:customer]
        xml.descriptor_name options[:descriptor_name]
        xml.descriptor_city options[:descriptor_city]
      end

      def add_reference(xml, authorization)
        transid, trackid, _, _, _ = split_authorization(authorization)
        xml.transid transid
        add_track_id(xml, trackid)
      end

      def add_track_id(xml, trackid)
        xml.trackid(trackid) if trackid
      end

      def commit(action, amount=nil, options={}, &builder)
        response = parse_xml(ssl_post(live_url, build_xml(action, &builder)))
        Response.new(
          (response[:responsecode] == "0"),
          (response[:result] || response[:error_text] || "Unknown Response"),
          response,
          authorization: authorization_from(response, action, amount, options),
          test: test?
        )
      end

      def build_xml(action)
        Nokogiri::XML::Builder.new do |xml|
          xml.request do
            xml.action_ ACTIONS[action]
            yield xml
          end
        end.to_xml
      end

      def parse_xml(xml)
        response = {}

        Nokogiri::XML(CGI.unescapeHTML(xml)).xpath("//response").children.each do |node|
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

      def authorization_from(response, action,  amount, options)
        currency = options[:currency] || currency(amount)
        [response[:tranid], response[:trackid], action, amount, currency].join("|")
      end

      def split_authorization(authorization)
        transid, trackid, action, amount, currency = authorization.split("|")
        [transid, trackid, action, amount, currency]
      end
    end
  end
end
