require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class S5Gateway < Gateway
      self.test_url = 'https://test.ctpe.io/payment/ctpe'
      self.live_url = 'https://ctpe.io/payment/ctpe'

      self.supported_countries = ['DK']
      self.default_currency = 'EUR'
      self.supported_cardtypes = [:visa, :master, :maestro]

      self.homepage_url = 'http://www.s5.dk/'
      self.display_name = 'S5'

      SUPPORTED_TRANSACTIONS = {
        'sale'      => 'CC.DB',
        'authonly'  => 'CC.PA',
        'capture'   => 'CC.CP',
        'refund'    => 'CC.RF',
        'void'      => 'CC.RV',
        'store'     => 'CC.RG'
      }

      def initialize(options={})
        requires!(options, :sender, :channel, :login, :password)
        super
      end

      def purchase(money, payment, options={})
        request = build_xml_request do |xml|
          add_identification(xml, options)
          add_payment(xml, money, 'sale', options)
          add_account(xml, payment)
          add_customer(xml, payment, options)
          add_recurrence_mode(xml, options)
        end

        commit(request)
      end

      def refund(money, authorization, options={})
        request = build_xml_request do |xml|
          add_identification(xml, options, authorization)
          add_payment(xml, money, 'refund', options)
        end

        commit(request)
      end

      def authorize(money, payment, options={})
        request = build_xml_request do |xml|
          add_identification(xml, options)
          add_payment(xml, money, 'authonly', options)
          add_account(xml, payment)
          add_customer(xml, payment, options)
          add_recurrence_mode(xml, options)
        end

        commit(request)
      end

      def capture(money, authorization, options={})
        request = build_xml_request do |xml|
          add_identification(xml, options, authorization)
          add_payment(xml, money, 'capture', options)
        end

        commit(request)
      end

      def void(authorization, options={})
        request = build_xml_request do |xml|
          add_identification(xml, options, authorization)
          add_payment(xml, nil, 'void', options)
        end

        commit(request)
      end

      def store(payment, options = {})
        request = build_xml_request do |xml|
          xml.Payment(code: SUPPORTED_TRANSACTIONS["store"])
          add_account(xml, payment)
          add_customer(xml, payment, options)
          add_recurrence_mode(xml, options)
        end

        commit(request)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end


      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((pwd=).+?(/>))i, '\1[FILTERED]\2').
          gsub(%r((<Number>).+?(</Number>))i, '\1[FILTERED]\2').
          gsub(%r((<Verification>).+?(</Verification>))i, '\1[FILTERED]\2')
      end

      private

      def add_identification(xml, options, authorization = nil)
        xml.Identification do
          xml.TransactionID options[:order_id] if options[:order_id]
          xml.ReferenceID authorization if authorization
        end
      end

      def add_payment(xml, money, action, options)
        xml.Payment(code: SUPPORTED_TRANSACTIONS[action]) do
          xml.Memo         "return_code=#{options[:memo]}" if options[:memo]
          xml.Presentation do
            xml.Amount     amount(money)
            xml.Currency   options[:currency] || currency(money)
            xml.Usage      options[:description]
          end
        end
      end

      def add_account(xml, payment_method)
        if !payment_method.respond_to?(:number)
          xml.Account(registration: payment_method)
        else
          xml.Account do
            xml.Number        payment_method.number
            xml.Holder        "#{payment_method.first_name} #{payment_method.last_name}"
            xml.Brand         payment_method.brand
            xml.Expiry(year: payment_method.year, month: payment_method.month)
            xml.Verification  payment_method.verification_value
          end
        end
      end

      def add_customer(xml, creditcard, options)
        return unless creditcard.respond_to?(:number)
        address = options[:billing_address]
        xml.Customer do
          xml.Contact do
            xml.Email      options[:email]
            xml.Ip         options[:ip]
            xml.Phone      address[:phone] if address
          end
          add_address(xml, address)
          xml.Name do
            xml.Given      creditcard.first_name
            xml.Family     creditcard.last_name
            xml.Company    options[:company]
          end
        end
      end

      def add_address(xml, address)
        return unless address

        xml.Address do
          xml.Street     "#{address[:address1]} #{address[:address2]}"
          xml.Zip        address[:zip]
          xml.City       address[:city]
          xml.State      address[:state]
          xml.Country    address[:country]
        end
      end

      def add_recurrence_mode(xml, options)
        if options[:recurring] == true
          xml.Recurrence(mode: "REPEATED")
        else
          xml.Recurrence(mode: "INITIAL")
        end
      end

      def parse(body)
        results  = {}
        xml = Nokogiri::XML(body)
        resp = xml.xpath("//Response/Transaction/Identification")
        resp.children.each do |element|
          results[element.name.downcase.to_sym] = element.text
        end
        resp = xml.xpath("//Response/Transaction/Processing")
        resp.children.each do |element|
          results[element.name.downcase.to_sym] = element.text
        end
        results
      end

      def commit(xml)
        url = (test? ? test_url : live_url)
        headers = {
          'Content-Type' => 'application/x-www-form-urlencoded;charset=UTF-8'
        }

        response = parse(ssl_post(url, post_data(xml), headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
        response[:result] == 'ACK'
      end

      def message_from(response)
        response[:return]
      end

      def authorization_from(response)
        response[:uniqueid]
      end

      def post_data(xml)
        "load=#{xml}"
      end

      def build_xml_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.Request(version: '1.0') do
            xml.Header do
              xml.Security(sender: @options[:sender])
            end
            xml.Transaction(mode: @options[:mode] || 'LIVE', channel: @options[:channel]) do
              xml.User(login: @options[:login], pwd: @options[:password])
              yield(xml)
            end
          end
        end

        builder.to_xml
      end
    end
  end
end
