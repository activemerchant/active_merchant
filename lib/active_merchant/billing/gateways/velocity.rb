require 'active_merchant/billing/gateways/velocity/velocity_xml_creator'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class VelocityGateway < Gateway

    attr_accessor :identity_token, :work_flow_id, :application_profile_id, :merchant_profile_id

    QTD_LIVE_URL = "https://api.nabcommerce.com/REST/2.0.18/DataServices/TMS/transactionsDetail"
    QTD_TEST_URL = "https://api.cert.nabcommerce.com/REST/2.0.18/DataServices/TMS/transactionsDetail"
    SIGNON_LIVE_URL = "https://api.nabcommerce.com/REST/2.0.18/SvcInfo/token"
    SIGNON_TEST_URL = "https://api.cert.nabcommerce.com/REST/2.0.18/SvcInfo/token"
    self.live_url = 'https://api.nabcommerce.com/REST/2.0.18/'
    self.test_url = 'https://api.cert.nabcommerce.com/REST/2.0.18/Txn/'
    self.money_format = :dollars
    self.supported_cardtypes = [:visa, :master, :discover, :american_express, :diners_club, :jcb, :maestro, :switch, :solo, :laser]
    self.supported_countries = ['US','CA']
    self.homepage_url = 'http://nabvelocity.com'
    self.display_name = 'NAB Velocity'

    
    def initialize(identity_token,work_flow_id,application_profile_id,merchant_profile_id)
      @identity_token = identity_token
      @work_flow_id = work_flow_id
      @application_profile_id = application_profile_id
      @merchant_profile_id = merchant_profile_id
    end

    def verify(params)
      commit(:post, url+"#{work_flow_id}"+"/"+"verify", xmlbody.verify_xml(params), headers("verify"))
    end


    def authorize(params)
      commit(:post, url+"#{work_flow_id}", xmlbody.authorize_xml(params), headers("authorize"))
    end


    def authorize_and_capture(params)
      commit(:post, url+"#{work_flow_id}", xmlbody.authorize_and_capture_xml(params), headers("authorize_and_capture"))
    end

    def capture(params)
      commit(:put, url+"#{work_flow_id}"+"/"+params[:TransactionId].to_s, xmlbody.capture_xml(params), headers("capture"))
    end


    def undo(params)
      commit(:put, url+"#{work_flow_id}"+"/"+params[:TransactionId].to_s, xmlbody.undo_xml(params), headers("undo"))
    end


    def adjust(params)
      commit(:put, url+"#{work_flow_id}"+"/"+params[:TransactionId].to_s, xmlbody.adjust_xml(params), headers("adjust"))
    end


    def return_by_id(params)
      commit(:post, url+"#{work_flow_id}", xmlbody.return_by_id_xml(params), headers("return_by_id")) 
    end  


    def return_unlinked(params)
      commit(:post, url+"#{work_flow_id}", xmlbody.return_unlinked_xml(params), headers("return_unlinked")) 
    end 



   private

   def xmlbody
      Velocity::VelocityXmlCreator.new(application_profile_id,merchant_profile_id)
    end

    def encode_token(str)
      Base64.strict_encode64(str.gsub(/"/, '').concat(":"))
    end

    def headers(action)
       (action == "query_transactions_detail") ? {"Authorization" => "Basic #{signOn}", 'Content-Type' => 'application/json'} : {"Authorization" => "Basic #{signOn}"}
    end

    def test?
      Base.test?
    end

    def signOn()
      encode_token(ssl_get(test? ? SIGNON_TEST_URL : SIGNON_LIVE_URL,{"Content-Type" => "application/json", "Authorization" => "Basic #{encode_token(identity_token)}" }))
    end

    def url
      test? ? self.test_url : self.live_url
    end

    def commit(verb, uri, parameters, header)
      data = ((raw_ssl_request(verb, uri, parameters, header)))
          parsed_data = parse(data.body, data.code)
          success = parsed_data[:status] == "Successful" ? true : false 
        if ["200", "201"].include?(data.code)
          create_response(success, "The Transaction was #{parsed_data[:status]}", parsed_data) 
        elsif ["400", "500", "5000"].include?(data.code)
          create_response(success, parsed_data[:Error], parsed_data)           
        end
    end

    def  create_response(success, message,data)
        Response.new(success, message, data, :authorization => data["transid"], :test => test?)
    end

    def parse(body, code)
      results = {}
      msg = REXML::Document.new(body)
      if msg.elements['ErrorResponse'].nil? &&  !["400", "500", "5000"].include?(code)
        unless msg.elements['BankcardCaptureResponse'].nil?
            results[:status] = REXML::XPath.first(msg, "/BankcardCaptureResponse/Status/text()")
            results[:transction_id] = REXML::XPath.first(msg, "/BankcardCaptureResponse/TransactionId/text()")
            results[:StatusMessage] = REXML::XPath.first(msg, "/BankcardCaptureResponse/StatusMessage/text()")
            results[:OriginatorTransactionId] = REXML::XPath.first(msg, "/BankcardCaptureResponse/OriginatorTransactionId/text()")
            results[:StatusCode] = REXML::XPath.first(msg, "/BankcardCaptureResponse/StatusCode/text()")
            results[:TransactionState] = REXML::XPath.first(msg, "/BankcardCaptureResponse/TransactionState/text()")
        else
            results[:status] = REXML::XPath.first(msg, "/BankcardTransactionResponsePro/Status/text()")
            results[:transction_id] = REXML::XPath.first(msg, "/BankcardTransactionResponsePro/TransactionId/text()")
            results[:StatusMessage] = REXML::XPath.first(msg, "/BankcardTransactionResponsePro/StatusMessage/text()")
            results[:OriginatorTransactionId] = REXML::XPath.first(msg, "/BankcardTransactionResponsePro/OriginatorTransactionId/text()")
            results[:StatusCode] = REXML::XPath.first(msg, "/BankcardTransactionResponsePro/StatusCode/text()")
            results[:TransactionState] = REXML::XPath.first(msg, "/BankcardTransactionResponsePro/TransactionState/text()")
        end
        if results[:status] == "Failure"
           results[:status] = (REXML::XPath.first(msg, "/BankcardCaptureResponse/Status/text()")) || (REXML::XPath.first(msg, "/BankcardTransactionResponsePro/Status/text()"))
           results[:StatusMessage] = (REXML::XPath.first(msg, "/BankcardCaptureResponse/StatusMessage/text()")) || (REXML::XPath.first(msg, "/BankcardTransactionResponsePro/StatusMessage/text()"))
        end
      else
        unless msg.elements['ErrorResponse'].nil?
            results[:ErrorId] = REXML::XPath.first(msg, "/ErrorResponse/ErrorId/text()")
            results[:Operation] = REXML::XPath.first(msg, "/ErrorResponse/Operation/text()")
            results[:Error] = REXML::XPath.first(msg, "/ErrorResponse/Reason/text()")
            if results[:Error] == "Validation Errors Occurred"  
               results[:RuleMessage] = REXML::XPath.first(msg, "/ErrorResponse/ValidationErrors/ValidationError/RuleMessage/text()")
            end
        else 
          results[:Error] = " Bad Request" 
        end
      end
      results
    end
  end
  end
end
