require 'builder'
require 'rexml/document'
require 'cgi'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CentinelBuyerAuthGateway < BuyerAuthGateway
      MESSAGE_VERSION = "1.7"
      TRANSACTION_TYPE = "C"
      
      LIVE_URL = ""
      TEST_URL = "https://centineltest.cardinalcommerce.com/maps/txns.asp"
      
      SUCCESS = "0"
      SUCCESS_MSG = "The request was successful"
      
      self.money_format = :cents
      
      CURRENCIES = {
        "USD" => "840",
        "EUR" => "978",
        "JPY" => "392",
        "CAD" => "124",
        "GBP" => "826"
      }
      
      def initialize(options = {})
        requires!(options, :login, :password, :processor)
        @options = options
        super
      end
      
      def verify_enrollment(amount, credit_card, options = {})
        requires!(options, :currency, :order_id)   
        commit verify_enrollment_request(amount, credit_card, options)
      end
      
      def validate_authentication(pa_res, options = {})
        commit validate_authentication_request(pa_res, options[:transaction_id])
      end
      
      private
      
      def commit(xml)
        response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, "cmpi_msg=#{CGI.escape(xml)}"))
        
        Response.new(successful?(response), message_from(response), response,
          :test => test?,
          :authorization => response["TransactionId"]
        )
      end
      
      def message_from(response)
        successful?(response) ? SUCCESS_MSG : response["ErrorDesc"]
      end
      
      def successful?(response)
        response["ErrorNo"] == SUCCESS
      end
    
      def verify_enrollment_request(money, credit_card, options)
        xml_request("cmpi_lookup") do |xml|
          xml.tag! "Amount", amount(money)
      	  xml.tag! "CurrencyCode", ActiveMerchant::NumericCurrencyCode.lookup(options[:currency])
      	  xml.tag! "OrderNumber", options[:order_id].to_s.slice(0, 50)
      	  xml.tag! "CardNumber", credit_card.number
      	  xml.tag! "CardExpMonth", format_expiry_month(credit_card.month)
      	  xml.tag! "CardExpYear", format_expiry_month(credit_card.year)
        end
      end
      
      def validate_authentication_request(pa_res, reference)
        xml_request("cmpi_authenticate") do |xml|
          xml.tag! "TransactionId", reference
          xml.tag! "PAResPayload", pa_res
        end
      end
      
      def xml_request(action)
        xml = Builder::XmlMarkup.new
        xml.tag! "CardinalMPI" do
          xml.tag! "Version", MESSAGE_VERSION
      	  xml.tag! "MsgType", action
      	  xml.tag! "ProcessorId", @options[:processor]
      	  xml.tag! "MerchantId", @options[:login]
      	  xml.tag! "TransactionPwd", @options[:password]
      	  xml.tag! "TransactionType", TRANSACTION_TYPE
      	  
          yield xml
        end
      end
      
      def parse(data)
        response = {}
        
        xml = REXML::Document.new(data)
        
        xml.root.elements.to_a.each do |element|
          response[element.name] = element.text
        end
        
        response
      end

      def format_expiry_month(month)
        sprintf("%.2i", month)
      end
    
      def format_expiry_year(year)
        sprintf("%.4i", year)
      end
    end
  end
end  