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

      def verify(money, creditcard_or_billing_id, options = {})
        parameters = {
           :Amount => amount(money),
        }
        add_order_details(parameters, options)
        add_customer_data(parameters, options)
        add_payment_source(parameters, creditcard_or_billing_id)
        add_addresses(parameters, options)
        commit(:post, url+"#{work_flow_id}/verify", xmlbody.verify_xml(parameters), headers)
      end

      def authorize(money, creditcard_or_billing_id, options = {})
        parameters = {
          :Amount => amount(money),
        }
        add_order_details(parameters, options)
        add_customer_data(parameters, options)
        add_payment_source(parameters, creditcard_or_billing_id)
        add_addresses(parameters, options)
        commit(:post, url+"#{work_flow_id}", xmlbody.authorize_xml(parameters), headers)
      end

         
      def purchase(money, creditcard_or_billing_id, options = {})
        parameters = {
          :Amount => amount(money),
        }
        add_order_details(parameters, options)
        add_customer_data(parameters, options)
        add_payment_source(parameters, creditcard_or_billing_id)
        add_addresses(parameters, options)
        commit(:post, url+"#{work_flow_id}", xmlbody.purchase_xml(parameters), headers)
      end

      def capture(money, authorization, options = {})
        parameters = {
          :Amount => amount(money),
          :TransactionId => authorization,
        }
        commit(:put, url+"#{work_flow_id}/#{parameters[:TransactionId]}", xmlbody.capture_xml(parameters), headers)
      end

      def void(authorization, options = {})
        parameters = {
          :TransactionId => authorization,
        }
        commit(:put, url+"#{work_flow_id}/#{parameters[:TransactionId]}", xmlbody.void_xml(parameters), headers)
      end

      def refund(money, authorization, options = {})
        parameters = {
          :Amount => amount(money),
          :TransactionId => authorization,
        }
        commit(:post, url+"#{work_flow_id}", xmlbody.refund_xml(parameters), headers) 
      end  

      private

        def xmlbody
          Velocity::VelocityXmlCreator.new(application_profile_id,merchant_profile_id)
        end

        def encode_token(str)
          Base64.strict_encode64(str.gsub(/"/, '').concat(":"))
        end

        def headers()
          {"Authorization" => "Basic #{sign_on}"}
        end

        def test?
          Base.test?
        end

        def sign_on()
          encode_token(ssl_get(test? ? SIGNON_TEST_URL : SIGNON_LIVE_URL,{"Content-Type" => "application/json", "Authorization" => "Basic #{encode_token(identity_token)}" }))
        end

        def url
          test? ? self.test_url : self.live_url
        end

        def add_payment_source(params, source)
          if source.is_a?(String)
             add_billing_id(params, source)
          else
             add_creditcard(params, source)
          end
        end

        def add_order_details(params, options)
          params[:OrderNumber]   = options[:OrderNumber] unless options[:OrderNumber].blank?
          params[:EntryMode]     = options[:EntryMode] unless options[:EntryMode].blank?
          params[:IndustryType]  = options[:IndustryType] unless options[:IndustryType].blank?
          params[:InvoiceNumber] = options[:InvoiceNumber] unless options[:InvoiceNumber].blank?
          params[:Track1Data]    = options[:Track1Data] unless options[:Track1Data].blank?
          params[:Track2Data]    = options[:Track2Data] unless options[:Track2Data].blank?
        end

        def add_customer_data(params, options)
          params[:Email] = options[:Email] unless options[:Email].blank?
          params[:Phone] = options[:Phone] unless options[:Phone].blank?
        end

        def add_creditcard(params, creditcard)
          params[:CardholderName] = creditcard.name
          params[:CardType]       = creditcard.brand.capitalize
          params[:PAN]            = creditcard.number
          params[:Expire]         = expdate(creditcard)
          params[:CVData]         = creditcard.verification_value if creditcard.verification_value?
        end

        def add_billing_id(params, billingid)
            params[:PaymentAccountDataToken] = options[:PaymentAccountDataToken] unless options[:PaymentAccountDataToken].blank?
        end

        def add_addresses(params, options)
          address = options[:address]
          if address
            params[:Street]     = address[:Street] unless address[:Street].blank?
            params[:Street1]    = address[:Street1] unless address[:Street1].blank?
            params[:City]       = address[:City] unless address[:City].blank?
            params[:PostalCode] = address[:PostalCode] unless address[:PostalCode].blank?
            params[:CountryCode]= address[:CountryCode] unless address[:CountryCode].blank?
          end
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
