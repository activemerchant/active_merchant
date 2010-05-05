module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GarantiGateway < Gateway
      URL = 'https://ccpos.garanti.com.tr/servlet/cc5ApiServer'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US','TR']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'https://ccpos.garanti.com.tr/ccRaporlar/garanti/ccReports'

      # The name of the gateway
      self.display_name = 'Garanti Sanal POS'

      self.default_currency = 'TRL'

      CURRENCY_CODES = {
        'YTL' => 949,
        'TRL' => 949,
        'USD' => 840,
        'EUR' => 978
      }


      def initialize(options = {})
        requires!(options, :login, :password, :client_id)
        @options = options
        super
      end

      def purchase(money, credit_card, options = {})
        commit(money, build_sale_request(money, credit_card, options))
      end

      def authorize(money, credit_card, options = {})
        commit(money, build_authorize_request(money, credit_card, options))
      end

      def capture(money, reference, options = {})
        commit(money, build_capture_request(money,reference,options))
      end

      private

      def build_xml_request(transaction_type,&block)
        xml = Builder::XmlMarkup.new
        xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"

        xml.tag! 'CC5Request' do
          xml.tag! 'Name', @options[:login]
          xml.tag! 'Password', @options[:password]
          xml.tag! 'ClientId', @options[:client_id]
          xml.tag! 'Mode', if test? then 'R' else 'P' end
          xml.tag! 'Type', transaction_type

          if block_given?
            yield xml
          else
            xml.target!
          end
        end
      end

      def build_sale_request(money, credit_card, options)
        build_xml_request('Auth') do |xml|
          add_customer_data(xml,options)
          add_order_data(xml,options)
          add_credit_card(xml, credit_card)
          add_addresses(xml, options)

          xml.tag! 'Total', amount(money)
          xml.tag! 'Currency', currency_code(options[:currency])

          xml.target!
        end
      end

      def build_authorize_request(money, credit_card, options)
         build_xml_request('PreAuth') do |xml|
          add_customer_data(xml,options)
          add_order_data(xml,options)
          add_credit_card(xml, credit_card)
          add_addresses(xml, options)

          xml.tag! 'Total', amount(money)
          xml.tag! 'Currency', currency_code(options[:currency])

          xml.target!

        end
      end

      def build_capture_request(money, reference, options = {})
        build_xml_request('PostAuth') do |xml|
          add_customer_data(xml,options)
          xml.tag! 'OrderId', reference
          xml.tag! 'Total', amount(money)
          xml.tag! 'Currency', currency_code(options[:currency])

          xml.target!
        end
      end

      def build_void_request(reference, options = {})
         build_xml_request('Void') do |xml|
          add_customer_data(xml,options)
          xml.tag! 'OrderId', reference
          xml.tag! 'Total', amount(money)
          xml.tag! 'Currency', currency_code(options[:currency])

          xml.target!
        end
      end

      def build_credit_request(money, reference, options = {})
        build_xml_request('Credit') do |xml|
          add_customer_data(xml,options)
          xml.tag! 'OrderId', reference
          xml.tag! 'Total', amount(money)
          xml.tag! 'Currency', currency_code(options[:currency])

          xml.target!
        end
      end

      def add_customer_data(xml, options)
        xml.tag! 'IPAddress', options[:ip_]
        xml.tag! 'Email', options[:email]
      end

      def add_order_data(xml,options)
        xml.tag! 'OrderId', options[:order_id]
        xml.tag! 'GroupId', nil
        xml.tag! 'TransId', nil
      end

      def add_credit_card(xml, credit_card)
        xml.tag! 'Number', credit_card.number
        xml.tag! 'Expires', [format_exp(credit_card.month),format_exp(credit_card.year)].join('/')
        xml.tag! 'Cvv2Val', credit_card.verification_value
      end

      def format_exp(value)
        format(value, :two_digits)
      end

      def add_addresses(xml,options)
        if billing_address = options[:billing_address] || options[:address]
          xml.tag! 'BillTo' do
            xml.tag! 'Name', billing_address[:name]
            xml.tag! 'Street1', billing_address[:address1]
            xml.tag! 'Street2', billing_address[:address2]
            xml.tag! 'City', billing_address[:city]
            xml.tag! 'StateProv', billing_address[:state]
            xml.tag! 'PostalCode', billing_address[:zip]
            xml.tag! 'Country', billing_address[:country]
            xml.tag! 'Company', billing_address[:company]
            xml.tag! 'TelVoice', billing_address[:phone]
          end
        end

        if shipping_address = options[:shipping_address]
          xml.tag! 'ShipTo' do
            xml.tag! 'Name', shipping_address[:name]
            xml.tag! 'Street1', shipping_address[:address1]
            xml.tag! 'Street2', shipping_address[:address2]
            xml.tag! 'City', shipping_address[:city]
            xml.tag! 'StateProv',shipping_address[:state]
            xml.tag! 'PostalCode',shipping_address[:zip]
            xml.tag! 'Country', shipping_address[:country]
            xml.tag! 'Company', shipping_address[:company]
            xml.tag! 'TelVoice', shipping_address[:phone]
          end
        end
      end

      def currency_code(currency)
        CURRENCY_CODES[currency] || CURRENCY_CODES[default_currency]
      end

      def commit(money,request)
        raw_response = ssl_post(URL,"DATA=" + request)
        response = parse(raw_response)

        success = success?(response)

        Response.new(success,
                     success ? 'Approved' : 'Declined',
                     response,
                     :test => test?,
                     :authorization => response[:order_id])
      end

      def parse(body)
        xml = REXML::Document.new(body)

        response = {}
        xml.root.elements.to_a.each do |node|
          parse_element(response, node)
        end
        response
      end

      def parse_element(response, node)
        if node.has_elements?
          node.elements.each{|element| parse_element(response, element) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def success?(response)
        response[:response] == "Approved"
      end

    end
  end
end

