require 'nokogiri'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class VelocityGateway < Gateway

      # TO USE:
      # First, make sure you have everything setup correctly and all of your dependencies in place with:
      #
      #  require 'active_merchant'
      # 
      # If You are using Velocity gateway in Testing mode then you have to use Velocity Test Server
      # 
      #  ActiveMerchant::Billing::Base.mode = :test
      #
      # To finish setting up, create the active_merchant object you will be using, with the Velocity gateway.
      # 
      #  gateway = ActiveMerchant::Billing::VelocityGateway.new(:identity_token => "PHNhbWw6QXNzZXJ0aW9uIE1ham9yVmVyc2lvbj0iMSIgTWlub3JWZXJzaW9uPSIxIiBBc3NlcnRpb25JRD0iXzdlMDhiNzdjLTUzZWEtNDEwZC1hNmJiLTAyYjJmMTAzMzEwYyIgSXNzdWVyPSJJcGNBdXRoZW50aWNhdGlvbiIgSXNzdWVJbnN0YW50PSIyMDE0LTEwLTEwVDIwOjM2OjE4LjM3OVoiIHhtbG5zOnNhbWw9InVybjpvYXNpczpuYW1lczp0YzpTQU1MOjEuMDphc3NlcnRpb24iPjxzYW1sOkNvbmRpdGlvbnMgTm90QmVmb3JlPSIyMDE0LTEwLTEwVDIwOjM2OjE4LjM3OVoiIE5vdE9uT3JBZnRlcj0iMjA0NC0xMC0xMFQyMDozNjoxOC4zNzlaIj48L3NhbWw6Q29uZGl0aW9ucz48c2FtbDpBZHZpY2U+PC9zYW1sOkFkdmljZT48c2FtbDpBdHRyaWJ1dGVTdGF0ZW1lbnQ+PHNhbWw6U3ViamVjdD48c2FtbDpOYW1lSWRlbnRpZmllcj5GRjNCQjZEQzU4MzAwMDAxPC9zYW1sOk5hbWVJZGVudGlmaWVyPjwvc2FtbDpTdWJqZWN0PjxzYW1sOkF0dHJpYnV0ZSBBdHRyaWJ1dGVOYW1lPSJTQUsiIEF0dHJpYnV0ZU5hbWVzcGFjZT0iaHR0cDovL3NjaGVtYXMuaXBjb21tZXJjZS5jb20vSWRlbnRpdHkiPjxzYW1sOkF0dHJpYnV0ZVZhbHVlPkZGM0JCNkRDNTgzMDAwMDE8L3NhbWw6QXR0cmlidXRlVmFsdWU+PC9zYW1sOkF0dHJpYnV0ZT48c2FtbDpBdHRyaWJ1dGUgQXR0cmlidXRlTmFtZT0iU2VyaWFsIiBBdHRyaWJ1dGVOYW1lc3BhY2U9Imh0dHA6Ly9zY2hlbWFzLmlwY29tbWVyY2UuY29tL0lkZW50aXR5Ij48c2FtbDpBdHRyaWJ1dGVWYWx1ZT5iMTVlMTA4MS00ZGY2LTQwMTYtODM3Mi02NzhkYzdmZDQzNTc8L3NhbWw6QXR0cmlidXRlVmFsdWU+PC9zYW1sOkF0dHJpYnV0ZT48c2FtbDpBdHRyaWJ1dGUgQXR0cmlidXRlTmFtZT0ibmFtZSIgQXR0cmlidXRlTmFtZXNwYWNlPSJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy93cy8yMDA1LzA1L2lkZW50aXR5L2NsYWltcyI+PHNhbWw6QXR0cmlidXRlVmFsdWU+RkYzQkI2REM1ODMwMDAwMTwvc2FtbDpBdHRyaWJ1dGVWYWx1ZT48L3NhbWw6QXR0cmlidXRlPjwvc2FtbDpBdHRyaWJ1dGVTdGF0ZW1lbnQ+PFNpZ25hdHVyZSB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC8wOS94bWxkc2lnIyI+PFNpZ25lZEluZm8+PENhbm9uaWNhbGl6YXRpb25NZXRob2QgQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAxLzEwL3htbC1leGMtYzE0biMiPjwvQ2Fub25pY2FsaXphdGlvbk1ldGhvZD48U2lnbmF0dXJlTWV0aG9kIEFsZ29yaXRobT0iaHR0cDovL3d3dy53My5vcmcvMjAwMC8wOS94bWxkc2lnI3JzYS1zaGExIj48L1NpZ25hdHVyZU1ldGhvZD48UmVmZXJlbmNlIFVSST0iI183ZTA4Yjc3Yy01M2VhLTQxMGQtYTZiYi0wMmIyZjEwMzMxMGMiPjxUcmFuc2Zvcm1zPjxUcmFuc2Zvcm0gQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwLzA5L3htbGRzaWcjZW52ZWxvcGVkLXNpZ25hdHVyZSI+PC9UcmFuc2Zvcm0+PFRyYW5zZm9ybSBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvMTAveG1sLWV4Yy1jMTRuIyI+PC9UcmFuc2Zvcm0+PC9UcmFuc2Zvcm1zPjxEaWdlc3RNZXRob2QgQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwLzA5L3htbGRzaWcjc2hhMSI+PC9EaWdlc3RNZXRob2Q+PERpZ2VzdFZhbHVlPnl3NVZxWHlUTUh5NUNjdmRXN01TV2RhMDZMTT08L0RpZ2VzdFZhbHVlPjwvUmVmZXJlbmNlPjwvU2lnbmVkSW5mbz48U2lnbmF0dXJlVmFsdWU+WG9ZcURQaUorYy9IMlRFRjNQMWpQdVBUZ0VDVHp1cFVlRXpESERwMlE2ZW92T2lhN0pkVjI1bzZjTk1vczBTTzRISStSUGRUR3hJUW9xa0paeEtoTzZHcWZ2WHFDa2NNb2JCemxYbW83NUFSWU5jMHdlZ1hiQUVVQVFCcVNmeGwxc3huSlc1ZHZjclpuUytkSThoc2lZZW4vT0VTOUdtZUpsZVd1WUR4U0xmQjZJZnd6dk5LQ0xlS0FXenBkTk9NYmpQTjJyNUJWQUhQZEJ6WmtiSGZwdUlablp1Q2l5OENvaEo1bHU3WGZDbXpHdW96VDVqVE0wU3F6bHlzeUpWWVNSbVFUQW5WMVVGMGovbEx6SU14MVJmdWltWHNXaVk4c2RvQ2IrZXpBcVJnbk5EVSs3NlVYOEZFSEN3Q2c5a0tLSzQwMXdYNXpLd2FPRGJJUFpEYitBPT08L1NpZ25hdHVyZVZhbHVlPjxLZXlJbmZvPjxvOlNlY3VyaXR5VG9rZW5SZWZlcmVuY2UgeG1sbnM6bz0iaHR0cDovL2RvY3Mub2FzaXMtb3Blbi5vcmcvd3NzLzIwMDQvMDEvb2FzaXMtMjAwNDAxLXdzcy13c3NlY3VyaXR5LXNlY2V4dC0xLjAueHNkIj48bzpLZXlJZGVudGlmaWVyIFZhbHVlVHlwZT0iaHR0cDovL2RvY3Mub2FzaXMtb3Blbi5vcmcvd3NzL29hc2lzLXdzcy1zb2FwLW1lc3NhZ2Utc2VjdXJpdHktMS4xI1RodW1icHJpbnRTSEExIj5ZREJlRFNGM0Z4R2dmd3pSLzBwck11OTZoQ2M9PC9vOktleUlkZW50aWZpZXI+PC9vOlNlY3VyaXR5VG9rZW5SZWZlcmVuY2U+PC9LZXlJbmZvPjwvU2lnbmF0dXJlPjwvc2FtbDpBc3NlcnRpb24+", :work_flow_id => "2317000001", :application_profile_id => "14644" , :merchant_profile_id => "PrestaShop Global HC")
      #
      # Next, create a credit card object using a Velocity approved test card.
      #
      #  creditcard = ActiveMerchant::Billing::CreditCard.new(brand: 'visa', verification_value: "123", month:"06", year: '2020', number:'4012888812348882', name: 'John Doe')
      # 
      # Now we are ready to process our transaction

      SIGNON_LIVE_URL = "https://api.nabcommerce.com/REST/2.0.18/SvcInfo/token"
      SIGNON_TEST_URL = "https://api.cert.nabcommerce.com/REST/2.0.18/SvcInfo/token"
      self.live_url = 'https://api.nabcommerce.com/REST/2.0.18/'
      self.test_url = 'https://api.cert.nabcommerce.com/REST/2.0.18/Txn/'
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :discover, :american_express, :diners_club, :jcb, :maestro, :switch, :solo, :laser]
      self.supported_countries = ['US','CA']
      self.homepage_url = 'http://nabvelocity.com'
      self.display_name = 'NAB Velocity'

      def initialize(options = {})
        requires!(options, :identity_token, :work_flow_id, :application_profile_id, :merchant_profile_id)
        super
      end

      def verify(money, creditcard_or_billing_id, options = {})
        parameters = {
           :Amount => amount(money),
        }
        add_order_details(parameters, options)
        add_customer_data(parameters, options)
        add_payment_source(parameters, creditcard_or_billing_id)
        add_addresses(parameters, options)
        commit(:post, url+"#{@options[:work_flow_id]}/verify", build_verify_xml(parameters), headers)
      end

      def authorize(money, creditcard_or_billing_id, options = {})
        parameters = {
          :Amount => amount(money),
        }
        add_order_details(parameters, options)
        add_customer_data(parameters, options)
        add_payment_source(parameters, creditcard_or_billing_id)
        add_addresses(parameters, options)
        commit(:post, url+"#{@options[:work_flow_id]}", build_authorize_xml(parameters), headers)
      end

         
      def purchase(money, creditcard_or_billing_id, options = {})
        parameters = {
          :Amount => amount(money),
        }
        add_order_details(parameters, options)
        add_customer_data(parameters, options)
        add_payment_source(parameters, creditcard_or_billing_id)
        add_addresses(parameters, options)
        commit(:post, url+"#{@options[:work_flow_id]}", build_purchase_xml(parameters), headers)
      end

      def capture(money, authorization, options = {})
        parameters = {
          :Amount => amount(money),
          :TransactionId => authorization,
        }
        commit(:put, url+"#{@options[:work_flow_id]}/#{parameters[:TransactionId]}", build_capture_xml(parameters), headers)
      end

      def void(authorization, options = {})
        parameters = {
          :TransactionId => authorization,
        }
        commit(:put, url+"#{@options[:work_flow_id]}/#{parameters[:TransactionId]}", build_void_xml(parameters), headers)
      end

      def refund(money, authorization, options = {})
        parameters = {
          :Amount => amount(money),
          :TransactionId => authorization,
        }
        commit(:post, url+"#{@options[:work_flow_id]}", build_refund_xml(parameters), headers) 
      end  

      private

        def encode_token(str)
          Base64.strict_encode64(str.gsub(/"/, '').concat(":"))
        end

        def sign_on
          encode_token(ssl_get(test? ? SIGNON_TEST_URL : SIGNON_LIVE_URL,{"Content-Type" => "application/json", "Authorization" => "Basic #{encode_token(@options[:identity_token])}" }))
        end

        def headers
          {"Authorization" => "Basic #{sign_on}"}
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
          params[:CardType]       = creditcard.brand.try(:capitalize)
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

        def create_response(success, message,data)
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

        def build_verify_xml(params)
          Nokogiri::XML::Builder.new do |xml|
            xml.AuthorizeTransaction('xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance','xmlns' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Rest','i:type' =>"AuthorizeTransaction" ) {
              add_merchant_id_and_application_id_to_xml(xml)
              xml.Transaction('xmlns:ns1' => "http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard",'i:type' => "ns1:BankcardTransaction" ){
                xml['ns1'].TenderData{
                  xml['ns1'].CardData{
                    xml['ns1'].CardType params[:CardType]
                    xml['ns1'].CardholderName params[:CardholderName]
                    add_card_details_xml(xml, params)        
                  }
                  xml['ns1'].CardSecurityData{
                    xml['ns1'].AVSData{
                      xml['ns1'].CardholderName('i:nil' =>"true") 
                      xml['ns1'].Street params[:Street]
                      xml['ns1'].City params[:City]
                      xml['ns1'].StateProvince params[:StateProvince]
                      xml['ns1'].PostalCode params[:PostalCode]
                      xml['ns1'].Phone params[:Phone]
                      xml['ns1'].Email params[:Email]
                    }
                    xml['ns1'].CVDataProvided 'Provided'
                    xml['ns1'].CVData params[:CVData]
                    xml['ns1'].KeySerialNumber('i:nil' =>"true")
                    xml['ns1'].PIN('i:nil' =>"true") 
                    xml['ns1'].IdentificationInformation('i:nil' =>"true")
                  }
                  xml['ns1'].EcommerceSecurityData('i:nil' =>"true")
                }
                xml['ns1'].TransactionData{
                  add_transaction_amount_xml(xml, params)
                  add_other_transaction_xml(xml, params)
                  if !params[:Track2Data].nil? || !params[:Track1Data].nil?
                    xml['ns1'].EntryMode params[:EntryMode]
                  else
                    xml['ns1'].EntryMode 'Keyed'
                  end  
                  xml['ns1'].IndustryType params[:IndustryType]
                  xml['ns1'].InvoiceNumber('i:nil' =>"true")
                  xml['ns1'].OrderNumber('i:nil' =>"true")
                  xml['ns1'].TipAmount '0.0'
                }       
              }
            }
          end.to_xml
        end

        def build_authorize_xml(params)  
          Nokogiri::XML::Builder.new do |xml|
            xml.AuthorizeTransaction('xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Rest','i:type' =>"AuthorizeTransaction" ) {
              add_merchant_id_and_application_id_to_xml(xml)
              xml.Transaction('xmlns:ns1' => "http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard",'i:type' => "ns1:BankcardTransaction" ){
                xml['ns1'].TenderData{
                  payment_data_xml(xml,params)
                }
                add_data_xml(xml, params)
              }
            }     
          end.to_xml 
        end

        def build_purchase_xml(params)
          Nokogiri::XML::Builder.new do |xml|
            xml.AuthorizeAndCaptureTransaction('xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Rest','i:type' =>"AuthorizeAndCaptureTransaction" ) {
              add_merchant_id_and_application_id_to_xml(xml)
              xml.Transaction('xmlns:ns1' => "http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard",'i:type' => "ns1:BankcardTransaction" ){
                xml['ns1'].TenderData{
                  payment_data_xml(xml,params)
                }
                add_data_xml(xml, params)
              }
            }     
          end.to_xml  
        end

        def build_capture_xml(params)
          Nokogiri::XML::Builder.new do |xml|
            xml.ChangeTransaction('xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance','xmlns' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Rest','i:type' =>"Capture" ) {
              xml.ApplicationProfileId @options[:application_profile_id] #'14644'
                xml.DifferenceData('xmlns:d2p1' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions','xmlns:d2p2' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard', 'xmlns:d2p3' => 'http://schemas.ipcommerce.com/CWS/v2.0/TransactionProcessing','i:type' => "d2p2:BankcardCapture"){
                xml['d2p1'].TransactionId params[:TransactionId]
                if params[:Amount] != ''
                   xml['d2p2'].Amount params[:Amount]
                else
                   xml['d2p2'].Amount '0.00'
                end 
                xml['d2p2'].TipAmount '0.00' 
              }
            }  
          end.to_xml    
        end

        def build_void_xml(params)
          Nokogiri::XML::Builder.new do |xml|
            xml.Undo('xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Rest', 'i:type' =>"Undo" ) {
              add_merchant_id_and_application_id_to_xml(xml) 
              xml.BatchIds('xmlns:d2p1' => 'http://schemas.microsoft.com/2003/10/Serialization/Arrays','i:nil' => "true")
              xml.DifferenceData('xmlns:d2p1' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions','i:nil' => "true")
              xml.TransactionId params[:TransactionId] 
            }
          end.to_xml    
        end

        def build_refund_xml(params)
          Nokogiri::XML::Builder.new do |xml|
            xml.ReturnById('xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Rest', 'i:type' =>"ReturnById" ) {
              add_merchant_id_and_application_id_to_xml(xml) 
              xml.BatchIds('xmlns:d2p1' => 'http://schemas.microsoft.com/2003/10/Serialization/Arrays', 'i:nil' => "true")
              xml.DifferenceData('xmlns:ns1' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard', 'i:type' => "ns1:BankcardReturn"){
                xml['ns2'].TransactionId params[:TransactionId] ,'xmlns:ns2' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions'
                if params[:Amount] != ''
                   xml['ns1'].Amount params[:Amount]
                else
                   xml['ns1'].Amount '0.00'
                end
              }
            } 
          end.to_xml
        end

        def add_merchant_id_and_application_id_to_xml(xml)
          xml.ApplicationProfileId @options[:application_profile_id] #'14560'
          xml.MerchantProfileId @options[:merchant_profile_id] #'PrestaShop Global HC'
        end

        def add_card_details_xml(xml, params)
          if !params[:Track2Data].nil?
            xml['ns1'].Track2Data params[:Track2Data]
            xml['ns1'].PAN('i:nil' =>"true") 
            xml['ns1'].Expire('i:nil' =>"true")
            xml['ns1'].Track1Data('i:nil' =>"true")
          elsif !params[:Track1Data].nil?
            xml['ns1'].Track1Data params[:Track1Data]
            xml['ns1'].PAN('i:nil' =>"true") 
            xml['ns1'].Expire('i:nil' =>"true")
            xml['ns1'].Track2Data('i:nil' =>"true")
          else
            xml['ns1'].PAN params[:PAN] 
            xml['ns1'].Expire params[:Expire]
            xml['ns1'].Track1Data('i:nil' =>"true")
            xml['ns1'].Track2Data('i:nil' =>"true")
          end
        end

        def add_data_xml(xml, params)
          xml['ns2'].CustomerData('xmlns:ns2' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions"){
            xml['ns2'].BillingData{
              xml['ns2'].Name('i:nil' =>"true")
              xml['ns2'].Address{
                xml['ns2'].Street1 params[:Street1] 
                xml['ns2'].Street2('i:nil' =>"true")
                xml['ns2'].City params[:City] 
                xml['ns2'].StateProvince params[:StateProvince]
                xml['ns2'].PostalCode params[:PostalCode]
                xml['ns2'].CountryCode params[:CountryCode]
              }
              xml['ns2'].BusinessName 'MomCorp'
              xml['ns2'].Phone params[:Phone]
              xml['ns2'].Fax('i:nil' =>"true")
              xml['ns2'].Email params[:Email]
            }
            xml['ns2'].CustomerId 'cust123'
            xml['ns2'].CustomerTaxId('i:nil' =>"true")
            xml['ns2'].ShippingData('i:nil' =>"true")
          }
          xml['ns3'].ReportingData('xmlns:ns3' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions"){
            xml['ns3'].Comment 'a test comment'
            xml['ns3'].Description 'a test description'
            xml['ns3'].Reference '001'
          }
          xml['ns1'].TransactionData{
            add_transaction_amount_xml(xml, params)
            add_other_transaction_xml(xml, params)
            xml['ns11'].CampaignId('xmlns:ns11' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true")
            xml['ns12'].Reference('xmlns:ns12' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('xyt')
            xml['ns1'].ApprovalCode('i:nil' =>"true")
            xml['ns1'].CashBackAmount '0.0'
            xml['ns1'].EntryMode params[:EntryMode]
            xml['ns1'].GoodsType 'NotSet'
            xml['ns1'].IndustryType params[:IndustryType]
            xml['ns1'].InternetTransactionData('i:nil' =>"true")
            xml['ns1'].InvoiceNumber params[:InvoiceNumber]
            xml['ns1'].OrderNumber params[:OrderNumber]
            xml['ns1'].IsPartialShipment 'false'
            xml['ns1'].SignatureCaptured 'false'
            xml['ns1'].FeeAmount '0.0'
            xml['ns1'].TerminalId('i:nil' =>"true")
            xml['ns1'].LaneId('i:nil' =>"true")
            xml['ns1'].TipAmount '0.0'
            xml['ns1'].BatchAssignment('i:nil' =>"true")
            xml['ns1'].PartialApprovalCapable 'NotSet'
            xml['ns1'].ScoreThreshold('i:nil' =>"true")
            xml['ns1'].IsQuasiCash 'false'
          }
        end

        def payment_data_xml(xml,params)
          if !params[:SwipeStatus].nil? && !params[:IdentificationInformation].nil? && !params[:SecurePaymentAccountData].nil? && !params[:EncryptionKeyId].nil?
            xml['ns5'].SecurePaymentAccountData('xmlns:ns5' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:SecurePaymentAccountData])
            xml['ns6'].EncryptionKeyId('xmlns:ns6' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:EncryptionKeyId])
            xml['ns7'].SwipeStatus('xmlns:ns7' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:SwipeStatus])
            xml['ns1'].CardSecurityData{
              xml['ns1'].IdentificationInformation params[:IdentificationInformation]
            }
            xml['ns1'].CardData('i:nil' =>"true")
          elsif !params[:SecurePaymentAccountData].nil? && !params[:EncryptionKeyId].nil? 
            xml['ns5'].SecurePaymentAccountData('xmlns:ns5' => "http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:SecurePaymentAccountData])
            xml['ns6'].EncryptionKeyId('xmlns:ns6' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:EncryptionKeyId])
            xml['ns7'].SwipeStatus('xmlns:ns7' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true") 
            xml['ns1'].CardSecurityData{
              xml['ns1'].IdentificationInformation('i:nil' =>"true")
            }
            xml['ns1'].CardData('i:nil' =>"true")
            xml['ns1'].EcommerceSecurityData('i:nil' =>"true") 
          elsif !params[:PaymentAccountDataToken].nil?
            xml['ns4'].PaymentAccountDataToken('xmlns:ns4' => "http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:PaymentAccountDataToken])
            xml['ns5'].SecurePaymentAccountData('xmlns:ns5' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true")
            xml['ns6'].EncryptionKeyId('xmlns:ns6' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true")
            xml['ns7'].SwipeStatus('xmlns:ns7' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true") 
            xml['ns1'].CardData('i:nil' =>"true")
            xml['ns1'].EcommerceSecurityData('i:nil' =>"true")           
          else 
            xml['ns4'].PaymentAccountDataToken('xmlns:ns4' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions", 'i:nil' =>"true")
            xml['ns5'].SecurePaymentAccountData('xmlns:ns5' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true")
            xml['ns6'].EncryptionKeyId('xmlns:ns6' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true")
            xml['ns7'].SwipeStatus('xmlns:ns7' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true")
            xml['ns1'].CardData{
              xml['ns1'].CardType params[:CardType] 
              add_card_details_xml(xml, params)        
            }
            xml['ns1'].EcommerceSecurityData('i:nil' =>"true")             
          end
        end

        def add_transaction_amount_xml(xml, params)
          if params[:Amount] != ''
            xml['ns8'].Amount('xmlns:ns8' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:Amount])
          else
            xml['ns8'].Amount('xmlns:ns8' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('0.00')
          end
        end

        def add_other_transaction_xml(xml, params)
          xml['ns9'].CurrencyCode('xmlns:ns9' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('USD')
          xml['ns10'].TransactionDateTime('xmlns:ns10' => "http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(Time.current.strftime("%FT%R:%S")) 
          xml['ns1'].AccountType 'NotSet'
          xml['ns1'].CustomerPresent 'Present'
          xml['ns1'].EmployeeId '11'
        end

    end
  end
end
