module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class HeartlandGateway < Gateway
      TEST_URL = 'https://testing.heartlandpaymentservices.net/BillingDataManagement/v3/BillingDataManagementService.svc'
      LIVE_URL = 'https://heartlandpaymentservices.net/BillingDataManagement/v3/BillingDataManagementService.svc'
          
      # visa, master, american_express, discover
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.homepage_url = 'http://www.heartlandpaymentservices.com'
      self.display_name = 'Heartland'
      self.money_format = :dollars


      # gateway_id maps to MerchantName in the request
      # payee_id maps to BillType in the request
      # if you pass in :applicant_name, :property_address, :property_unit_number those will be passed into the ID1-4 columns.
      # ID1 is required so a default value of "Generic Application" will be inserted if no value is given.
      def initialize(options = {}) 
        requires!(options, :login, :password, :gateway_id, :payee_id)
        @options = options
        @options[:property_address] = 'Generic Application' if @options[:property_address].blank?
        super
      end  


      # Should run against the test servers or not?
      def test?
        @options[:test] || Base.gateway_mode == :test
      end

      
      def authorize(money, creditcard, options = {})
        raise 'Hearland does not support authorize'
      end

      
      def auth_reversal(money, identification, options = {})
        raise 'Hearland does not support authorize'
      end


      # Capture an authorization that has previously been requested
      def capture(money, authorization, options = {})
        raise 'Hearland does not support authorize'
      end


      # Purchase is an auth followed by a capture
      # You must supply an order_id in the options hash  
      def purchase(money, creditcard, options = {})
        # requires!(options, :email)
        setup_address_hash(options)
        soap = build_request money, creditcard, options[:billing_address], options
        commit soap
      end

      
      def void(identification, options = {})
        raise 'not currently supported'
      end


      def refund(money, identification, options = {})
        raise 'not currently supported'
      end
      
      
      def credit(money, identification, options = {})
        raise 'not currently supported'
      end
      
      
      private                       
      
      
      # Create all address hash key value pairs so that we still function if we were only provided with one or two of them 
      def setup_address_hash(options)
        options[:billing_address] = options[:billing_address] || options[:address] || {}
        options[:shipping_address] = options[:shipping_address] || {}
      end


      # Where we actually build the full SOAP request using builder
      def build_request(money, creditcard, address, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! 's:Envelope', {'xmlns:s' => 'http://schemas.xmlsoap.org/soap/envelope/'} do
          xml.tag! 's:Body' do
            xml.tag! 'MakeBlindPayment', {'xmlns' => "https://test.heartlandpaymentservices.net/BillingDataManagement/v3/BillingDataManagementService"} do
              xml.tag! 'MakeE3PaymentRequest', {'xmlns:a' => "http://schemas.datacontract.org/2004/07/BDMS.NewModel", 'xmlns:i' => "http://www.w3.org/2001/XMLSchema-instance"} do
                xml.tag! 'a:Credential' do
                  xml.tag! 'a:ApplicationID', 13
                  xml.tag! 'a:Password', @options[:password]
                  xml.tag! 'a:UserName', @options[:login]
                  xml.tag! 'a:MerchantName', @options[:gateway_id]
                end
                xml.tag! 'a:ACHAccountsToCharge', {'i:nil' => "true"}
                xml.tag! 'a:BillTransactions' do
                  xml.tag! 'a:BillTransaction' do
                    xml.tag! 'a:BillType', @options[:payee_id]
                    xml.tag! 'a:ID1', @options[:property_address].to_s.gsub(/[^A-Za-z0-9\.# ]/, '')[0..49]
                    xml.tag! 'a:ID2', @options[:property_unit].to_s.gsub(/[^A-Za-z0-9\.# ]/, '')[0..49]
                    xml.tag! 'a:ID3', @options[:applicant_name].to_s.gsub(/[^A-Za-z0-9\.# ]/, '')[0..49]
                    xml.tag! 'a:ID4', @options[:payment_id].to_s.gsub(/[^A-Za-z0-9\.# ]/, '')[0..49]
                    xml.tag! 'a:AmountToApplyToBill', amount(money)
                    xml.tag! 'a:CustomerEnteredElement1', {'i:nil' => "true"}
                    xml.tag! 'a:CustomerEnteredElement2', {'i:nil' => "true"}
                    xml.tag! 'a:CustomerEnteredElement3', {'i:nil' => "true"}
                    xml.tag! 'a:CustomerEnteredElement4', {'i:nil' => "true"}
                    xml.tag! 'a:CustomerEnteredElement5', {'i:nil' => "true"}
                    xml.tag! 'a:CustomerEnteredElement6', {'i:nil' => "true"}
                    xml.tag! 'a:CustomerEnteredElement7', {'i:nil' => "true"}
                    xml.tag! 'a:CustomerEnteredElement8', {'i:nil' => "true"}
                    xml.tag! 'a:CustomerEnteredElement9', {'i:nil' => "true"}
                  end
                end
                xml.tag! 'a:ClearTextCreditCardsToCharge' do
                  xml.tag! 'a:ClearTextCardToCharge' do
                    xml.tag! 'a:Amount', amount(money)
                    xml.tag! 'a:CardProcessingMethod', 'Credit'
                    xml.tag! 'a:ExpectedFeeAmount', '0.00'
                    xml.tag! 'a:ClearTextCreditCard', {'xmlns:b' => "http://schemas.datacontract.org/2004/07/POSGateway.Wrapper"} do
                      xml.tag! 'b:CardHolderData', {'i:nil' => "true"}
                      xml.tag! 'b:CardNumber', creditcard.number
                      xml.tag! 'b:ExpirationMonth', creditcard.month
                      xml.tag! 'b:ExpirationYear', format(creditcard.year, :four_digits)
                      xml.tag! 'b:VerificationCode', creditcard.verification_value
                    end
                  end
                end
                xml.tag! 'a:E3CreditCardsToCharge', {'i:nil' => "true"}
                xml.tag! 'a:E3DebitCardsWithPINToCharge', {'i:nil' => "true"}
                xml.tag! 'a:IncludeReceiptInResponse', false
                xml.tag! 'a:TokensToCharge', {'i:nil' => "true"}                
                xml.tag! 'a:Transaction' do
                  xml.tag! 'a:Amount', amount(money)
                  xml.tag! 'a:FeeAmount', '0.00'
                  xml.tag! 'a:MerchantInvoiceNumber', {'i:nil' => "true"}
                  xml.tag! 'a:MerchantPONumber', {'i:nil' => "true"}
                  xml.tag! 'a:MerchantTransactionDescription', {'i:nil' => "true"}
                  xml.tag! 'a:MerchantTransactionID', {'i:nil' => "true"}
                  xml.tag! 'a:PayorAddress', address[:address1]
                  xml.tag! 'a:PayorCity', address[:city]
                  xml.tag! 'a:PayorCountry', 'US'
                  xml.tag! 'a:PayorEmailAddress', nil
                  xml.tag! 'a:PayorFirstName', creditcard.first_name
                  xml.tag! 'a:PayorLastName', creditcard.last_name 
                  xml.tag! 'a:PayorMiddleName', nil
                  xml.tag! 'a:PayorPhoneNumber', nil
                  xml.tag! 'a:PayorPostalCode', address[:zip]
                  xml.tag! 'a:PayorState', address[:state]
                  xml.tag! 'a:ReferenceTransactionID', {'i:nil' => "true"}
                  xml.tag! 'a:TransactionDate', '0001-01-01T00:00:00'                    
                end
              end
            end
          end
        end
        xml = xml.target!
        
        # useful for testing         
        # f = File.new('test-bill-type', 'w')
        # f << xml
        # f.close
        
        return xml
      end
      
      
      def commit(request)
        url = test? ? TEST_URL : LIVE_URL
        response = parse(ssl_post(url, request, 
          'Content-Type' => 'text/xml; charset=utf-8', 
          'SOAPAction' => 'https://test.heartlandpaymentservices.net/BillingDataManagement/v3/BillingDataManagementService/IBillingDataManagementService/MakeBlindPayment'
        ))
        Response.new(response[:success], response[:message], response, 
          :test => test?, 
          :authorization => response[:authorization],
        )
      end
      
      
      # Parse the SOAP response
      def parse(xml)
        response = {success: false}
        xml = REXML::Document.new(xml)
        if node = REXML::XPath.first(xml, "//a:isSuccessful")
          response[:success] = node.text =~ /true/i ? true : false
        end
        if response[:success]
          if node = REXML::XPath.first(xml, "//a:Transaction_ID")
            response[:authorization] = node.text
          end
        else  
          if node = REXML::XPath.first(xml, "//a:MessageDescription")
            response[:message] = node.text
          end
        end
        return response
      end     
      
      
   end 
 end 
end