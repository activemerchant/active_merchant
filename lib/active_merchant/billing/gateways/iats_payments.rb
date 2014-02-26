# encoding: utf-8
require 'net/http'
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IatsPaymentsGateway < Gateway
   # listing of reject codes
      # https://www.iatspayments.com/english/help/rejects.html
      #

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :maestro]
      self.supported_countries = %w(  US UK AU CA FI DK FR DE IT HK GR IE TR
                                      CH SE ES SG PT NO NL JP NZ AT BE LU)
      self.default_currency = 'USD'
      # The homepage URL of the gateway
      self.homepage_url = 'http://iatspayments.com'
      # The name of the gateway
      self.display_name = 'IATS'
      
      NA_COUNTRIES = %w( US CA)
      UK_COUNTRIES = %w(UK AU FI DK FR DE IT HK GR IE TR CH SE ES SG PT NO NL JP NZ AT BE LU)

      UK_HOST = 'www.uk.iatspayments.com'
      NA_HOST = 'www.iatspayments.com'

      PROCESS_URL = '/NetGate/ProcessLink.asmx'

      REJECT_MESSAGES = {
        '1' => 'Agent code has not been set up on the authorization system. Please call iATS at 1-888-955-5455.',
        '2' => 'Unable to process transaction. Verify and re-enter credit card information.',
        '3' => 'Invalid Customer Code.',
        '4' => 'Incorrect expiration date.',
        '5' => 'Invalid transaction. Verify and re-enter credit card information.',
        '6' => 'Please have cardholder call the number on the back of the card.',
        '7' => 'Lost or stolen card.',
        '8' => 'Invalid card status.',
        '9' => 'Restricted card status. Usually on corporate cards restricted to specific sales.',
        '10' => 'Error. Please verify and re-enter credit card information.',
        '11' => 'General decline code. Please have client call the number on the back of credit card',
        '12' => 'Incorrect CVV2 or Expiry date',
        '14' => 'The card is over the limit.',
        '15' => 'General decline code. Please have client call the number on the back of credit card',
        '16' => 'Invalid charge card number. Verify and re-enter credit card information.',
        '17' => 'Unable to authorize transaction. Authorizer needs more information for approval.',
        '18' => 'Card not supported by institution.',
        '19' => 'Incorrect CVV2 security code',
        '22' => 'Bank timeout. Bank lines may be down or busy. Re-try transaction later.',
        '23' => 'System error. Re-try transaction later.',
        '24' => 'Charge card expired.',
        '25' => 'Capture card. Reported lost or stolen.',
        '26' => 'Invalid transaction, invalid expiry date. Please confirm and retry transaction.',
        '27' => 'Please have cardholder call the number on the back of the card.',
        '32' => 'Invalid charge card number.',
        '39' => 'Contact IATS 1-888-955-5455.',
        '40' => 'Invalid card number. Card not supported by IATS.',
        '41' => 'Invalid Expiry date.',
        '42' => 'CVV2 required.',
        '43' => 'Incorrect AVS.',
        '45' => 'Credit card name blocked. Call iATS at 1-888-955-5455.',
        '46' => 'Card tumbling. Call iATS at 1-888-955-5455.',
        '47' => 'Name tumbling. Call iATS at 1-888-955-5455.',
        '48' => 'IP blocked. Call iATS at 1-888-955-5455.',
        '49' => 'Velocity 1 – IP block. Call iATS at 1-888-955-5455.',
        '50' => 'Velocity 2 – IP block. Call iATS at 1-888-955-5455.',
        '51' => 'Velocity 3 – IP block. Call iATS at 1-888-955-5455.',
        '52' => 'Credit card BIN country blocked. Call iATS at 1-888-955-5455.',
        '100' => 'DO NOT REPROCESS. Call iATS at 1-888-955-5455.',
        'Timeout' => 'The system has not responded in the time allotted. Call iATS at 1-888-955-5455.'}

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
          total: money,
          mop: creditcard.brand,
          zip_code: options[:zip_code],
          credit_card_num: creditcard.number,
          credit_card_expiry: "#{creditcard.month}/#{creditcard.year}"
        }
        if !options[:cvv2].nil?
	   hash[:cvv2] = options[:cvv2]
	end
	select_region(options)
        res = process_credit_card_v1(hash)
        parse_data(res)
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
	if options[:total].nil?
	  mess = "Please provide the amount"
	  raise ArgumentError.new(mess)
	end
	options[:total] = options[:total].to_f > 0 ? -options[:total].to_f : options[:total].to_f

        hash = {
          total: options[:total],
          transaction_id: identification
        }
	select_region(options)
        res = process_credit_card_refund_with_transaction_id_v1(hash)
        parse_data(res)
      end

      def credit(money, identification, options = {})
        raise NotImplementedError.new
      end

      def select_region(options = {})
	address = options[:billing_address] || options[:address]
	unless address[:country].nil?
	   if NA_COUNTRIES.include?(address[:country])
	    @region = 'na'
	   elsif UK_COUNTRIES.include?(address[:country])
	    @region = 'uk'
	   end
	end
      end

      def current_host
        if @region == 'uk'
          UK_HOST
        else
          NA_HOST
        end
      end

      private

      def parse_data(res)
        success = (res.xpath('//STATUS').text.include?('Success') &&
          res.xpath('//AUTHORIZATIONRESULT').text.include?('OK:'))
        message = res.xpath('//AUTHORIZATIONRESULT').text.chomp
        status_code = message
        if !success
          message = REJECT_MESSAGES[message.gsub('REJECT:', '').gsub(' ', '')]
        end
        transaction_id = res.xpath('//TRANSACTIONID').text.chomp
        Response.new(success, message,
                     { transaction_id: transaction_id,
                       status_code: status_code,
                       xml: res.to_xml
                      })
      end

      # ProcessCrediCardV1
      def process_credit_card_v1(hash)
        data = create_xml_for_process(hash)
        soap_post('ProcessCreditCardV1', data)
      end

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
        xml_start('ProcessCreditCardRefundWithTransactionIdV1') do |xml|
          xml.agentCode @login
          xml.password @password
          xml.customerIPAddress hash[:customer_ip_address]
          xml.transactionId hash[:transaction_id]
          xml.total hash[:total]
        end.to_xml
      end

      def create_xml_for_process(hash)
        xml_start('ProcessCreditCardV1') do |xml|
          xml.agentCode @login
          xml.password @password
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
        end.to_xml
      end

      # root, headers and process name
      def xml_start(process_card, &block)
        Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
          xml.__send__('soap12:Envelope', soap_options) do
            xml.__send__('soap12:Body') do
              xml.__send__(
                process_card,
                xmlns: 'https://www.iatspayments.com/NetGate/',
                &block)
            end
          end
        end
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
    end
  end
end

