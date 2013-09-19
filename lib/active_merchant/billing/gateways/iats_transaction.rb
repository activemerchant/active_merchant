# encoding: utf-8
require 'net/http'
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IatsTransactionGateway < Gateway

      # listing of reject codes
      # https://www.iatspayments.com/english/help/rejects.html
      #
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master]
      self.supported_countries = %w(  US UK AU CA FI DK FR DE IT HK GR IE TR
                                      CH SE ES SG PT NO NL JP NZ)
      self.default_currency = 'USD'
      # The homepage URL of the gateway
      self.homepage_url = 'http://iatspayments.com'
      # The name of the gateway
      self.display_name = 'IATS'

      UK_HOST = 'www.uk.iatspayments.com'
      NA_HOST = 'www.iatspayments.com'

      PROCESS_URL = '/NetGate/ProcessLink.asmx'

      def initialize(options = {})
        requires!(options, :login, :password, :region)
        @region = options[:region]
        @login = options[:login]
        @password = options[:password]
        super
      end

      # in options require zip_code
      # optional data in options :customer_ip_address,
      # :cvv2, :first_name, :last_name, :address, :city, :state
      def purchase(money, creditcard, options = {})
        if creditcard.expired?
          mess = "Credit Card is expired #{creditcard.inspect}"
          raise ArgumentError.new(mess)
        end
        if options[:zip_code].nil?
          mess = "Require zip code in options #{options.inspect}"
          raise ArgumentError.new(mess)
        end
        hash = {
          agent_code: @login,
          password: @password,
          total: money,
          mop: creditcard.brand,
          zip_code: options[:zip_code],
          credit_card_num: creditcard.number,
          credit_card_expiry: "#{creditcard.month}/#{creditcard.year}"
        }
        process_credit_card_v1(hash)
      end

      def authorize(money, creditcard, options = {})
        raise NotImplementedError.new
      end

      def capture(money, identification, options = {})
        raise NotImplementedError.new
      end

      def void(identification, options = {})
        raise NotImplementedError.new
      end

      # options require money with symbol -
      # identification is transaction_id
      # optional data in options :customer_ip_address,
      # :invoice_num,
      def refund(identification, options = {})
        hash = {
          agent_code: @login,
          password: @password,
          total: options[:total],
          transaction_id: identification
        }
        process_credit_card_refund_with_transaction_id_v1(hash)
      end

      def credit(money, identification, options = {})
        raise NotImplementedError.new
      end

      def current_host
        if @region == 'uk'
          UK_HOST
        else
          NA_HOST
        end
      end

      private

      # ProcessCreditCardRefundWithTransactionIdV1
      def process_credit_card_refund_with_transaction_id_v1(hash)
        data = create_xml_for_refund(hash)
        soap_post('ProcessCreditCardRefundWithTransactionIdV1', data)
      end

      def soap_options
        {
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:soap12' => 'http://www.w3.org/2003/05/soap-envelope'
        }
      end

      def create_xml_for_refund(hash)
        builder = Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
          xml.__send__('soap12:Envelope', soap_options) do
            xml.__send__('soap12:Body') do
              xml.ProcessCreditCardRefundWithTransactionIdV1(
                xmlns: 'https://www.iatspayments.com/NetGate/') do
                xml.agentCode hash[:agent_code]
                xml.password hash[:password]
                xml.customerIPAddress hash[:customer_ip_address]
                xml.transactionId hash[:transaction_id]
                xml.total hash[:total]
              end
            end
          end
        end
        builder.to_xml
      end

      # ProcessCrediCardV1
      def process_credit_card_v1(hash)
        builder = Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
          xml.__send__('soap12:Envelope', soap_options) do
            xml.__send__('soap12:Body') do
              xml.ProcessCreditCardV1(
                xmlns: 'https://www.iatspayments.com/NetGate/') do
                xml.agentCode hash[:agent_code]
                xml.password hash[:password]
                xml.customerIPAddress hash[:customer_ip_address]
                xml.invoiceNum hash[:invoice_num]
                xml.creditCardNum hash[:credit_card_num]
                xml.creditCardExpiry hash[:credit_card_expiry]
                xml.cvv2 hash[:cvv2]
                xml.mop hash[:mop]
                xml.firstName hash[:first_name]
                xml.lastName hash[:last_name]
                xml.address hash[:address]
                xml.city hash[:city]
                xml.state hash[:state]
                xml.zipCode hash[:zip_code]
                xml.total hash[:total]
              end
            end
          end
        end
        data = builder.to_xml
        soap_post('ProcessCreditCardV1', data)
      end

      def soap_post(method, data)
        site = current_host + PROCESS_URL
        req = Net::HTTP::Post.new('https://' + site)
        req.body = data
        req.content_type = 'application/soap+xml; charset=utf-8'
        res = Net::HTTP.start(current_host,
                              443,
                              use_ssl: true) do |http|
          http.request(req)
        end
        Nokogiri::XML(res.body)
      end

      def make_headers(data, soap_call)
        {
          'Content-Type' => 'application/soap+xml; charset=utf-8',
          'Host' => current_host,
          'Content-Length' => data.size.to_s
        }
      end

    end
  end
end
