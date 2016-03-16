require "nokogiri"
require "digest/md5"
require 'net/http'
require 'active_merchant/billing/response'
#require 'rack'
#require 'rack/server'
#require 'uri'
#require 'activemerchant'
#Copyright 2006-2014 WorldNet TPS Ltd.

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
  
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
  
   class Request
      def GetRequestHash(plainString)
        digest = Digest::MD5.hexdigest(plainString)
        return digest
      end

      def GetFormattedDate()
        time = Time.new
        return time.strftime("%d-%m-%Y:%H:%M:%S:000")
      end

      def SendRequestToGateway(requestString, testAccount, gateway)

        @serverUrl = 'https://'

        if testAccount == true
          @serverUrl = @serverUrl + 'test'
        end

        case gateway.downcase
        when 'worldnet'
          @serverUrl = @serverUrl + 'payments.worldnettps.com'
        when 'cashflows'
          @serverUrl = @serverUrl + 'cashflows.worldnettps.com'
        when 'payius'
          @serverUrl = @serverUrl + 'payments.payius.com'
        when 'pago'
          @serverUrl =  @serverUrl + 'payments.pagotechnology.com'
        when 'globalone'
          @serverUrl = @serverUrl + 'payments.globalone.me'

        end

        @XMLSchemaFile = @serverUrl + '/merchant/gateway.xsd'
        @serverUrl =  @serverUrl + '/merchant/xmlpayment'
        @requestXML =  Nokogiri::XML(requestString)

        if defined?(@requestXML)
          ##Validating
          @schemaValidate = Nokogiri::XML::Schema(Net::HTTP.get(URI.parse(@XMLSchemaFile)))
          @schemaValidate.validate(@requestXML).each do |error|
            puts "#{error.line} :: #{error.message}"
          end
        #   @requestXML = nil #unset variable
        end

        uri = URI.parse(@serverUrl)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Post.new(uri.request_uri)
        request.content_type = "text/xml"
        request.body = requestString

        begin
          response = http.request(request)

        rescue Exception => e
          print e.message
        end
        return response.body

      end

    end

#  Used for processing XML Authorisations through the WorldNet TPS XML Gateway.
#  Basic request is configured on initialisation and optional fields can be configured.
    class XmlAuthRequest < Request

      @@terminalId
      @@orderId
      @@currency
      @@amount
      @@cardNumber
      @@dateTime
      @@hash
      @@autoReady
      @@description
      @@email
      @@cardNumber
      @@trackData
      @@cardType
      @@cardExpiryrequest
      @@cardHolderName
      @@cvv
      @@issueNo
      @@address1
      @@address2
      @@postCode
      @@cardCurrency
      @@cardAmount
      @@conversionRate
      @@terminalType
      @@transactionType
      @@avsOnly
      @@mpiRef
      @@mobileNumber
      @@deviceId
      @@phone
      @@country
      @@ipAddress
      @@multicur
      @@foreignCurInfoSet
      def Amount()
        return @@amount
      end

      @@terminalType = "2"
      @@transactionType = "7"
      @@multicur = false
      @@foreignCurInfoSet = false

      #  Creates the standard request less optional parameters for processing an XML Transaction
      #  through the WorldNetTPS XML Gateway
      #
      #  @param terminalId Terminal ID provided by WorldNet TPS
      #  @param orderId A unique merchant identifier. Alpha numeric and max size 12 chars.
      #  @param currency ISO 4217 3 Digit Currency Code, e.g. EUR / USD / GBP
      #  @param amount Transaction Amount, Double formatted to 2 decimal places.
      #  @param description Transaction Description
      #  @param email Cardholder e-mail
      #  @param cardNumber A valid Card Number that passes the Luhn Check.
      #  @param cardType
      #  Card Type (Accepted Card Types must be configured in the Merchant Selfcare System.)
      #
      #  Accepted Values :
      #
      #  VISA
      #  MASTERCARD
      #  LASER
      #  SWITCH
      #  SOLO
      #  AMEX
      #  DINERS
      #  MAESTROrequest
      #  DELTA
      #  ELECTRON
      #

      def XmlAuthRequest(terminalId,
        orderId,
        currency,
        amount,
        cardNumber,
        cardType)

        @@dateTime = GetFormattedDate()

        @@terminalId = terminalId
        @@orderId = orderId
        @@currency = currency
        @@amount = amount
        @@cardNumber = cardNumber
        @@cardType = cardType
      end

      #  Setter for Auto Ready Value
      #
      #  @param autoReady
      #  Auto Ready is an optional parameter and defines if the transaction should be settled automatically.
      #
      #  Accepted Values :
      #
      #  Y   -   Transaction will be settled in next batch
      #  N   -   Transaction will not be settled until user changes state in Merchant Selfcare Section

      def SetAutoReady(autoReady)
        @@autoReady = autoReady
      end

      #  Setter for Email Address Value
      #
      #  @param email Alpha-numeric field.

      def SetEmail(email)
        @@email = email
      end

      #  Setter for Email Address ValuorderIde
      #
      #  @param email Alpha-numeric field.

      def SetDescription(description)
        @@description = description

      end
      #  Setter for Card Expiry and Card Holder Name values
      #  These are mandatory for non-SecureCard transactions
      #
      #  @param cardExpiry Card Expiry formatted MMYY
      #  @param cardHolderName Card Holder Name

      def SetNonSecureCardCardInfo(cardExpiry, cardHolderName)
        @@cardExpiry = cardExpiry
        @@cardHolderName = cardHolderName
      end

      #  Setter for Card Verification Value
      #
      #  @param cvv Numeric field with a max of 4 characters.

      def SetCvv(cvv)
        @@cvv = cvv
      end

      #  Setter for Issue No
      #
      #  @param issueNo Numeric field with a max of 3 characters.

      def SetIssueNo(issueNo)
        @@issueNo = issueNo

      end

      #  Setter for Address Verification Values
      #
      #  @param address1 First Line of address - Max size 20
      #  @param address2 Second Line of address - Max size 20
      #  @param postCode Postcode - Max size 9

      def SetAvs(address1, address2, postCode)

        @@address1 = address1
        @@address2 = address2
        @@postCode = postCode
      end
      #  Setter for Foreign Currency Information
      #AvsOnly("Y"
      #  @param cardCurrency ISO 4217 3 Digit Currency Code, e.g. EUR / USD / GBP
      #  @param cardAmount (Amount X Conversion rate) Formatted to two decimal places
      #  @param conversionRate Converstion rate supplied in rate response

      def SetForeignCurrencyInformation(cardCurrency, cardAmount, conversionRate)

        @@cardCurrency = cardCurrency
        @@cardAmount = cardAmount
        @@conversionRate = conversionRate

        @@foreignCurInfoSet = true
      end

      #  Setter for AVS only flag
      #
      #  @param avsOnly Only perform an AVS check, do not store as a transaction. Possible values: "Y", "N"

      def SetAvsOnly(avsOnly)
        @@avsOnly = avsOnly
      end

      #  Setter for MPI Reference code
      #
      #  @param mpiRef MPI Reference code supplied by WorldNet TPS MPI redirect

      def SetMpiRef(mpiRef)

        @@mpiRef = mpiRef
      end
      #  Setter for Mobile Number
      #
      #  @param mobileNumber Mobile Number of cardholder. If sent an SMS receipt will be sent to them

      def SetMobileNumber(mobileNumber)

        @@mobileNumber = mobileNumber

      end
      #  Setter for Device ID
      #
      #  @param deviceId Device ID to identify this source to the XML gateway

      def SetDeviceId(deviceId)
        @@deviceId = deviceId
      end
      #  Setter for Phone number
      #
      #  @param phone Phone number of cardholder

      def SetPhone(phone)
        @@phone = phone

      end
      #  Setter for the cardholders IP address
      #
      #  @param ipAddress IP Address of the cardholder

      def SetIPAddress(ipAddress)
        @@ipAddress = ipAddress
      end

      #  Setter for Country
      #get "paypal_express/purchase"
      #  @parAvsOnly("Y"am country Cardholders Country

      def SetCountry(country)
        @@country = country
      end
      #  Setter for multi-currency value
      #  This is required to be set for multi-currency terminals because the Hash is calculated differently.

      def SetMultiCur()
        @@multicur = true
      end
      #  Setter to flag transaction as a Mail Order. If not set the transaction defaults to eCommerce

      def SetMotoTrans()

        @@terminalType = "1"
        @@transactionType = "4"

      end
      #  Setter to flag transaction as a Mail Order. If not set the transaction defaults to eCommerceGenerateXml

      def SetTrackData(trackData)

        @@terminalType = "3"
        @@transactionType = "0"
        @@cardNumber = ""
        @@trackData = trackData
      end

      #  Setter for hash value
      #AvsOnly("Y"
      #  @param sharedSecret
      #  Shared secret either supplied by WorldNet TPS or configured under
      #  Terminal Settings in the Merchant Selfcare System.

      def SetHash(sharedSecret)

        if @@multicur == true
          @@hash = GetRequestHash(@@terminalId + @@orderId + @@currency + @@amount + @@dateTime + sharedSecret)
        else
          @@hash = GetRequestHash(@@terminalId + @@orderId + @@amount + @@dateTime + sharedSecret)
        end
      end

      #  (Old) Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
      #
      #  @param sharedSecret
      #  Shared secret either supplied by WorldNet TPS or configured under
      #  Terminal Settings in the Merchant Selfcare System.
      #
      #  @param testAccount
      #  Boolean value defining Mode
      #  true - This is a test account
      #  false - Production mode, all transactions will be processed by Issuer.
      #
      #  @return XmlAuthResponse containing an error or the parsed payment response.

      def ProcessRequest(sharedSecret, testAccount)

        return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")

      end

      def ProcessRequestToGateway(sharedSecret, testAccount, gateway)
        SetHash(sharedSecret)
        responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
        response = XmlAuthResponse.new
        return response.XmlAuthResponse(responseString)

      end

      def GenerateXml()

        @requestXML = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                 xml.PAYMENT{
                 xml.ORDERID @@orderId
                 xml.TERMINALID @@terminalId
                 xml.AMOUNT @@amount
                 xml.DATETIME @@dateTime
                     if defined?(@@trackData)
                        xml.TRACKDATA @@trackData
                     else
                        xml.CARDNUMBER @@cardNumber
                     end
                        xml.CARDTYPE @@cardType

                     if defined?(@@cardExpiry)&& defined?(@@cardHolderName) && defined?(@@trackData).nil?
                        xml.CARDEXPIRY @@cardExpiry
                        xml.CARDHOLDERNAME @@cardHolderName
                     end

                        xml.HASH @@hash
                        xml.CURRENCY @@currency

                      if @@foreignCurInfoSet == true
                        xml.FOREIGNCURRENCYINFORMATION{
                        xml.CARDCURRENCY @@cardCurrency
                        xml.CARDAMOUNT @@cardAmount
                        xml.CONVERSIONRATE @@conversionRate
                         }
                      end
                        xml.TERMINALTYPE @@terminalType
                        xml.TRANSACTIONTYPE @@transactionType

                     if defined?(@@autoReady)
                        xml.AUTOREADY @@autoReady
                     end
                     
                     if defined?(@@email)
                        xml.EMAIL @@email
                     end
                     if defined?(@@cvv)
                        xml.CVV @@cvv
                     end
                     if defined?(@@issueNo)
                        xml.ISSUENO @@issueNo
                     end
                     if defined?(@@address1)
                        xml.ADDRESS1 @@address1
                     end
                     if defined?(@@address2)
                        xml.ADDRESS2 @@address2
                      end
                     if defined?(@@postCode)
                        xml.POSTCODE @@postCode
                     end
                     if defined?(@@avsOnly)
                        xml.AVSONLY @@avsOnly
                     end
                     if defined?(@@description)
                        xml.DESCRIPTION @@description
                     end
                     if defined?(@@mpiRef)
                        xml.MPIREF @@mpiRef
                     end
                     if defined?(@@mobileNumber)
                        xml.MOBILENUMBER @@mobileNumber
                     end
                     if defined?(@@deviceId)
                        xml.DEVICEID @@deviceId
                     end
                     if defined?(@@phone)
                        xml.PHONE @@phone
                     end
                     if defined?(@@country)
                        xml.COUNTRY @@country
                     end
                     if defined?(@@ipAddress)
                        xml.IPADDRESS @@ipAddress
                     end

                  }
                     end# end of loop

        return @requestXML.to_xml

      end

    end
         #  Used for processing XML Refund Authorisations through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation. There are no coptional fields.
         
     class XmlRefundRequest < Request

      @@terminalId
      @@orderId
      @@amount
      @@dateTime
      @@hash
      @@autoReady
      @@operator
      @@uniqueRef
      @@reason
      def  Amount()
        return @@amount
      end

      #  Creates the refund request for processing an XML Transaction
      #  through the WorldNetTPS XML Gateway
      #
      #  @param terminalId Terminal ID provided by WorldNet TPS
      #  @param orderId A unique merchant identifier. Alpha numeric and max size 12 chars.
      #  @param currency ISO 4217 3 Digit Currency Code, e.g. EUR / USD / GBP
      #  @param amount Transaction Amount, Double formatted to 2 decimal places.
      #  @param operator An identifier for who executed this transaction
      #  @param reason The reason for the refund

      def XmlRefundRequest(terminalId,
        orderId,
        amount,
        operator,
        reason)

        @@dateTime = GetFormattedDate()
        @@amount = amount
        @@terminalId = terminalId
        @@orderId = orderId
        @@operator = operator
        @@reason = reason

      end
      #  Setter for UniqueRef

      #
      #  @param uniqueRef
      #  Unique Reference of transaction returned from gateway in authorisation response

      def SetUniqueRef(uniqueRef)

        @@uniqueRef = uniqueRef
        @@orderId = ""
      end

      #  Setter for Auto Ready Value
      #  @param autoReady
      #  Auto Ready is an optional parameter and defines if the transaction should be settled automatically.
      #
      #  Accepted Values :

      #
      #  Y   -   Transaction will be settled in next batch
      #  N   -   Transaction will not be settled until user changes state in Merchant Selfcare Section

      def SetAutoReady(autoReady)

        @@autoReady = autoReady
      end

      #  Setter for hash value
      #
      #  @param sharedSecret
      #  Shared secret either supplied by WorldNet TPS or configured under
      #  Terminal Settings in the Merchant Selfcare System.

      def SetHash(sharedSecret)

        if defined?(@@uniqueRef)
          @@hash = GetRequestHash(@@terminalId + @@uniqueRef + @@amount + @@dateTime + sharedSecret)
        else
          @@hash = GetRequestHash(@@terminalId + @@orderId + @@amount + @@dateTime + sharedSecret)
        end
      end
      #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
      #
      #  @param sharedSecret
      #  Shared secret either supplied by WorldNet TPS or configured under
      #  Terminal Settings in the Merchant Selfcare System.
      #
      #  @param testAccount
      #  Boolean value defining Mode
      #  true - This is a test account
      #  false - Production mode, all transactions will be processed by Issuer.
      #
      #  @return XmlRefundResponse containing an error or the parsed refund response.

      def ProcessRequest(sharedSecret, testAccount)

        return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")

      end

      def ProcessRequestToGateway(sharedSecret, testAccount, gateway)

        SetHash(sharedSecret)
        responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)

        response =  XmlRefundResponse.new
        return response.XmlRefundResponse(responseString)

      end

      def GenerateXml()
        @requestXML = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|

                  xml.REFUND{

                  if defined?(@@uniqueRef)
                    xml.UNIQUEREF @@uniqueRef
                  else
                    xml.ORDERID @@orderId
                  end
                    xml.TERMINALID @@terminalId
                    xml.AMOUNT @@amount
                    xml.DATETIME @@dateTime
                    xml.HASH @@hash
                    xml.OPERATOR @@operator
                    xml.REASON @@reason

                    if defined?(autoReady)
                    xml.AUTOREADY @@autoReady
                    end
                 }
                 end#end of loop
        return @requestXML.to_xml
      end
    end
        
        #
         #  Used for processing XML Pre-Authorisations through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
         #
     class XmlPreAuthRequest < Request
        
        @@terminalId
        @@orderId
        @@currency
        @@amount
        @@dateTime
        @@hash
        @@description
        @@email
        @@cardNumber
        @@cardType
        @@cardExpiry
        @@cardHolderName
        @@cvv
        @@issueNo
        @@address1
        @@address2
        @@postCode
        @@cardCurrency
        @@cardAmount
        @@conversionRate
        @@terminalType
        @@transactionType
        @@avsOnly
        @@mpiRef
        @@mobileNumber
        @@deviceId
        @@phone
        @@country
        @@ipAddress
        @@multicur
        @@foreignCurInfoSet
        
        @@terminalType = "2"
        @@transactionType = "7"
        @@multicur = false
        @@foreignCurInfoSet = false
            
            def  Amount()
                return @@amount
            end
           
            
             #  Creates the pre-auth request less optional parameters for processing an XML Transaction
             #  through the WorldNetTPS XML Gateway
             #
             #  @param terminalId Terminal ID provided by WorldNet TPS
             #  @param orderId A unique merchant identifier. Alpha numeric and max size 12 chars.
             #  @param currency ISO 4217 3 Digit Currency Code, e.g. EUR / USD / GBP
             #  @param amount Transaction Amount, Double formatted to 2 decimal places.
             #  @param description Transaction Description
             #  @param email Cardholder e-mail
             #  @param cardNumber A valid Card Number that passes the Luhn Check.
             #  @param cardType
             #  Card Type (Accepted Card Types must be configured in the Merchant Selfcare System.)
             #
             #  Accepted Values :
             #
             #  VISA
             #  MASTERCARD
             #  LASER
             #  SWITCH
             #  SOLO
             #  AMEX
             #  DINERS
             #  MAESTRO
             #  DELTA
             #  ELECTRON
             #
             #  @param cardExpiry Card Expiry formatted MMYY
             #  @param cardHolderName Card Holder Name
             
            def  XmlPreAuthRequest(terminalId,
                orderId,
                currency,
                amount,
                cardNumber,
                cardType)
             
                @@dateTime = GetFormattedDate()
        
                @@terminalId = terminalId
                @@orderId = orderId
                @@currency = currency
                @@amount = amount
                @@cardNumber = cardNumber
                @@cardType = cardType
            end
             
             #  Setter for Card Verification Value
             #
             #  @param cvv Numeric field with a max of 4 characters.
             
            def  SetCvv(cvv)
             
                @@cvv = cvv
            end
        
             
             #  Setter for Email Address Value
             #
             #  @param email Alpha-numeric field.
             
            def  SetEmail(email)
             
               @@email = email
            end
             
             #  Setter for Email Address Value
             #
             #  @param email Alpha-numeric field.
             
            def  SetDescription(description)
             
              @@description = description
            end
             
             #  Setter for Card Expiry and Card Holder Name values
             #  These are mandatory for non-SecureCard transactions
             #
             #  @param email Alpha-numeric field.
             
            def  SetNonSecureCardCardInfo(cardExpiry, cardHolderName)
             
                @@cardExpiry = cardExpiry
                @@cardHolderName = cardHolderName
            end
             
             #  Setter for Issue No
             #
             #  @param issueNo Numeric field with a max of 3 characters.
             
            def  SetIssueNo(issueNo)
             
                @@issueNo = issueNo
           end
        
             
             #  Setter for Address Verification Values
             #
             #  @param address1 First Line of address - Max size 20
             #  @param address2 Second Line of address - Max size 20
             #  @param postCode Postcode - Max size 9
             
            def  SetAvs(address1, address2, postCode)
             
                @@address1 = address1
                @@address2 = address2
                @@postCode = postCode
            end
             
             #  Setter for Foreign Currency Information
             #
             #  @param cardCurrency ISO 4217 3 Digit Currency Code, e.g. EUR / USD / GBP
             #  @param cardAmount (Amount X Conversion rate) Formatted to two decimal places
             #  @param conversionRate Converstion rate supplied in rate response
             
            def  SetForeignCurrencyInformation(cardCurrency, cardAmount, conversionRate)
               @@cardCurrency = cardCurrency
               @@cardAmount = cardAmount
               @@conversionRate = conversionRate
        
                @@foreignCurInfoSet = true
            end
             
             #  Setter for the cardholders IP address
             #
             #  @param ipAddress IP Address of the cardholder
             
            def  SetIPAddress(ipAddress)
             
                @@ipAddress = ipAddress
            end
             
             #  Setter for Multicurrency value
             
            def  SetMultiCur()
            
                @@multicur = true
            end
             
             #  Setter to flag transaction as a Mail Order. If not set the transaction defaults to eCommerce
             
            def  SetMotoTrans()
            
                @@terminalType = "1"
                @@transactionType = "4"
            end
             
             #  Setter for hash value
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             
            def SetHash(sharedSecret)
            
                if @@multicur == true 
                  @@hash = GetRequestHash(@@terminalId + @@orderId + @@currency + @@amount + @@dateTime + sharedSecret)
                  
                else 
                  @@hash = GetRequestHash(@@terminalId + @@orderId + @@amount + @@dateTime + sharedSecret)
                end
            end
             
             #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             #
             #  @param testAccount
             #  Boolean value defining Mode
             #  true - This is a test account
             #  false - Production mode, all transactions will be processed by Issuer.
             #
             #  @return XmlPreAuthResponse containing an error or the parsed payment response.
             
            def  ProcessRequest(sharedSecret, testAccount)
             
                return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
            end
        
            def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
             
                SetHash(sharedSecret)
                responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
                response = XmlPreAuthResponse.new         
                return response.XmlPreAuthResponse(responseString)
            end
        
            def  GenerateXml()
              @requestXML = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                  xml.PREAUTH{
                  xml.ORDERID @@orderId
                  xml.TERMINALID @@terminalId
                  xml.AMOUNT @@amount
                  xml.DATETIME @@dateTime
                  xml.CARDNUMBER @@cardNumber
                  xml.CARDTYPE @@cardType
                
               if defined?(@@cardExpiry) && defined?(@@cardHolderName) 
                  xml.CARDEXPIRY @@cardExpiry
                  xml.CARDHOLDERNAME @@cardHolderName
               end
        
                  xml.HASH @@hash
                  xml.CURRENCY @@currency
                  
                if @@foreignCurInfoSet == true
                
                   xml.FOREIGNCURRENCYINFORMATION {
                   xmlL.CARDCURRENCY @@cardCurrency
                   xml.CARDAMOUNT @@cardAmount
                   xml.CONVERSIONRATE @@conversionRate
                    }
                  
                end  
                   xml.TERMINALTYPE @@terminalType
                   xml.TRANSACTIONTYPE @@transactionType
                                
                  
                if defined?(email)        
                   xml.EMAIL @@email
                end             
                   
                if defined?(cvv)
                   xml.CVV @@cvv
                end
               
                if defined?(issueNo)
                   xml.ISSUENO @@issueNo
                end
                
                if defined?(postCode)
                    xml.POSTCODE @@postCode
                end
                if defined?(address1)
                   xml.ADDRESS1 @@address1
                end
                if defined?(address2)
                   xml.ADDRESS2 @@address2
                end
                if defined?(description)        
                   xml.DESCRIPTION @@description
                end
                if defined?(ipAddress)
                   xml.IPADDRESS @@ipAddress
               end
              } 
                       end  #end of loop
            return @requestXML.to_xml
          end
            
      end
        
         ##
         #  Used for processing XML PreAuthorisation Completions through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
         ##
         
         
    class XmlPreAuthCompletionRequest < Request

          @@terminalId
          @@orderId
          @@uniqueRef
          @@amount
          @@dateTime
          @@hash
          @@description
          @@cvv
          @@cardCurrency
          @@cardAmount
          @@conversionRate
          @@multicur
          @@foreignCurInfoSet
          @@multicur = false
          @@foreignCurInfoSet = false
          
          def  Amount()
            return @@amount
          end
    
          #  Creates the standard request less optional parameters for processing an XML Transaction
          #  through the WorldNetTPS XML Gateway
          #
          #  @param terminalId Terminal ID provided by WorldNet TPS
          #  @param orderId A unique merchant identifier. Alpha numeric and max size 12 chars.
          #  @param currency ISO 4217 3 Digit Currency Code, e.g. EUR / USD / GBP
          #  @param amount Transaction Amount, Double formatted to 2 decimal places.
          #  @param description Transaction Description
          #  @param email Cardholder e-mail
          #  @param cardNumber A valid Card Number that passes the Luhn Check.
          #  @param cardType
          #  Card Type (Accepted Card Types must be configured in the Merchant Selfcare System.)
          #
          #  Accepted Values :
          #
          #  VISA
          #  MASTERCARD
          #  LASER
          #  SWITCH
          #  SOLO
          #  AMEX
          #  DINERS
          #  MAESTRO
          #  DELTA
          #  ELECTRON
          #
          #  @param cardExpiry Card Expiry formatted MMYY
          #  @param cardHolderName Card Holder Name
    
          def  XmlPreAuthCompletionRequest(terminalId,
            orderId,
            amount)
    
            @@dateTime = GetFormattedDate()
            @@terminalId = terminalId
            @@orderId = orderId
            @@amount = amount
          end
    
          #  Setter for UniqueRef
    
          #
          #  @param uniqueRef
          #  Unique Reference of transaction returned from gateway in authorisation response
    
          def  SetUniqueRef(uniqueRef)
            @@uniqueRef = uniqueRef
            @@orderId = ""
          end
    
          #  Setter for Card Verification Value
          #
          #  @param cvv Numeric field with a max of 4 characters.
    
          def SetCvv(cvv)
            @@cvv = cvv
          end
    
          #  Setter for transaction description
          #
          #  @param cvv Discretionary text value
    
          def  SetDescription(description)
            @@description = description
          end
    
          #  Setter for Foreign Currency Information
          #
          #  @param cardCurrency ISO 4217 3 Digit Currency Code, e.g. EUR / USD / GBP
          #  @param cardAmount (Amount X Conversion rate) Formatted to two decimal places
          #  @param conversionRate Converstion rate supplied in rate response
    
          def  SetForeignCurrencyInformation(cardCurrency, cardAmount, conversionRate)
    
            @@cardCurrency = cardCurrency
            @@cardAmount = cardAmount
            @@conversionRate = conversionRate
    
            @@foreignCurInfoSet = true
          end
    
          #  Setter for hash value
          #
          #  @param sharedSecret
          #  Shared secret either supplied by WorldNet TPS or configured under
          #  Terminal Settings in the Merchant Selfcare System.
    
          def  SetHash(sharedSecret)
    
            if defined?(@@uniqueRef)
                @@hash = GetRequestHash(@@terminalId + @@uniqueRef + @@amount + @@dateTime + sharedSecret)
            else
                @@hash = GetRequestHash(@@terminalId + @@orderId + @@amount + @@dateTime + sharedSecret)
            end
          end
    
          #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
          #
          #  @param sharedSecret
          #  Shared secret either supplied by WorldNet TPS or configured under
          #  Terminal Settings in the Merchant Selfcare System.
          #
          #  @param testAccount
          #  Boolean value defining Mode
          #  true - This is a test account
          #  false - Production mode, all transactions will be processed by Issuer.
          #
          #  @return XmlPreAuthCompletionResponse containing an error or the parsed payment response.
    
          def  ProcessRequest(sharedSecret, testAccount)
    
               return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
          end
    
          def ProcessRequestToGateway(sharedSecret, testAccount, gateway)
    
              SetHash(sharedSecret)
              responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
              response = XmlPreAuthCompletionResponse.new
      
              return response.XmlPreAuthCompletionResponse(responseString)
          end
    
          def  GenerateXml()
    
              @requestXML = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                      xml.PREAUTHCOMPLETION {
                     
                if defined?(@@uniqueRef)
                      xml.UNIQUEREF @@uniqueRef
                else
                      xml.ORDERID @@orderId
                end
      
                      xml.TERMINALID @@terminalId
                      xml.AMOUNT @@amount
      
                 if @@foreignCurInfoSet == true
                      xml.FOREIGNCURRENCYINFORMATION {
                      xml.CARDCURRENCY @@cardCurrency
                      xml.CARDAMOUNT  @@cardAmount
                      xml.CONVERSIONRATE @@conversionRate
                     }
      
                 end
                 
                 if defined?(description)
                      xml.DESCRIPTION @@description
                 end
                      xml.DATETIME @@dateTime
      
                 if defined?(cvv)
                      xml.CVV @@cvv
                 end
                      xml.HASH @@hash
      
              }
           end # end of loop
              return @requestXML.to_xml
      
          end
    end
        
         #  Used for processing XML Rate Request through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
         ##
     class XmlRateRequest < Request

              @@terminalId
              @@cardBin
              @@baseAmount
              @@hash
              @@dateTime
        
              #  Creates the rate request for processing an XML Transaction
              #  through the WorldNetTPS XML Gateway
              #
              #  @param terminalId Terminal ID provided by WorldNet TPS
              #  @param cardBin First 6 digits of the card number
              def  XmlRateRequest(terminalId,
                cardBin)
        
                @@dateTime = GetFormattedDate()
                @@terminalId = terminalId
                @@cardBin = cardBin
              end
        
              #  Setter for Card Verification Value
              #
              #  @param cvv Numeric field with a max of 4 characters.
        
              def  SetBaseAmount(baseAmount)
                @@baseAmount = baseAmount
              end
        
              #  Setter for hash value
              #
              #  @param sharedSecret
              #  Shared secret either supplied by WorldNet TPS or configured under
              #  Terminal Settings in the Merchant Selfcare System.
        
              def  SetHash(sharedSecret)
                @@hash = GetRequestHash(@@terminalId + @@cardBin + @@dateTime + sharedSecret)
              end
              #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
              #
              #  @param sharedSecret
              #  Shared secret either supplied by WorldNet TPS or configured under
              #  Terminal Settings in the Merchant Selfcare System.
              #
              #  @param testAccount
              #  Boolean value defining Mode
              #  true - This is a test account
              #  false - Production mode, all transactions will be processed by Issuer.
              #
              #  @return XmlRateResponse containing an error or the parsed response.
        
              def  ProcessRequest(sharedSecret, testAccount)
        
                return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
              end
        
              def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
        
                SetHash(sharedSecret)
                responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
                response = XmlRateResponse.new
                return response.XmlRateResponse(responseString)
              end
        
              def  GenerateXml()
        
                @requestXML = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                        xml.GETCARDCURRENCYRATE {
                           xml.TERMINALID @@terminalId
                           xml.CARDBIN @@cardBin
                           xml.DATETIME @@dateTime
        
                      if defined?(baseAmount)
                            xml.BASEAMOUNT @@baseAmount
                      end
                            xml.HASH @@hash
        
                }
                end#end of loop
                return @requestXML.to_xml
              end
       end
        
        
         #  Used for processing XML SecureCard Registrations through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
         
       class XmlSecureCardRegRequest < Request
          
           @@terminalId
      @@dateTime
      @@hash
      @@cvv
      @@merchantRef
      @@cardNumber
      @@cardExpiry
      @@cardHolderName
      @@issueNo
      @@dontCheckSecurity

      #  Creates the SecureCard Registration/Update request for processing
      #  through the WorldNetTPS XML Gateway
      #
      #  @param merchantRef A unique card identifier. Alpha numeric and max size 48 chars.
      #  @param terminalId Terminal ID provided by WorldNet TPS
      #  @param cardNumber A valid Card Number that passes the Luhn Check.
      #  @param cardType
      #  Card Type (Accepted Card Types must be configured in the Merchant Selfcare System.)
      #
      #  Accepted Values :

      #
      #  VISA
      #  MASTERCARD
      #  LASER
      #  SWITCH
      #  SOLO
      #  AMEX
      #  DINERS

      #  MAESTRO
      #  DELTA
      #  ELECTRON
      #
      #  @param cardExpiry Card Expiry formatted MMYY
      #  @param cardHolderName Card Holder Name

      def  XmlSecureCardRegRequest(merchantRef,
          terminalId,
          cardNumber,
          cardExpiry,
          cardType,
          cardHolderName)
  
          @@dateTime = GetFormattedDate()
  
          @@merchantRef = merchantRef
          @@terminalId = terminalId
          @@cardNumber = cardNumber
          @@cardExpiry = cardExpiry
          @@cardType = cardType
          @@cardHolderName = cardHolderName
      end

      #  Setter for dontCheckSecurity setting
      #
      #  @param dontCheckSecurity can be either "Y" or "N".

      def  SetDontCheckSecurity(dontCheckSecurity)

          @@dontCheckSecurity = dontCheckSecurity
      end

      #  Setter for Card Verification Value
      #
      #  @param cvv Numeric field with a max of 4 characters.

      def  SetCvv(cvv)

          @@cvv = cvv
      end

      #  Setter for Issue No
      #
      #  @param issueNo Numeric field with a max of 3 characters.

      def  SetIssueNo(issueNo)
          @@issueNo = issueNo
      end

      #  Setter for hash value
      #
      #  @param sharedSecret
      #  Shared secret either supplied by WorldNet TPS or configured under
      #  Terminal Settings in the Merchant Selfcare System.

      def  SetHash(sharedSecret)

          @@hash = GetRequestHash(@@terminalId + @@merchantRef + @@dateTime + @@cardNumber + @@cardExpiry + @@cardType + @@cardHolderName + sharedSecret)
      end

      #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
      #
      #  @param sharedSecret
      #  Shared secret either supplied by WorldNet TPS or configured under
      #  Terminal Settings in the Merchant Selfcare System.
      #
      #  @param testAccount
      #  Boolean value defining Mode
      #  true - This is a test account
      #  false - Production mode, all transactions will be processed by Issuer.
      #
      #  @return XmlSecureCardRegResponse containing an error or the parsed payment response.

      def  ProcessRequest(sharedSecret, testAccount)
            return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
      end

      def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
    
            SetHash(sharedSecret)
            responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
            response = XmlSecureCardRegResponse.new
            return response.XmlSecureCardRegResponse(responseString)
      end

      def  GenerateXml()

        @requestXML = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                xml.SECURECARDREGISTRATION {

                xml.MERCHANTREF @@merchantRef
                xml.TERMINALID @@terminalId
                xml.DATETIME @@dateTime
                xml.CARDNUMBER @@cardNumber
                xml.CARDEXPIRY @@cardExpiry
                xml.CARDTYPE @@cardType
                xml.CARDHOLDERNAME @@cardHolderName
                xml.HASH @@hash

                if defined?(dontCheckSecurity)
                  xml.DONTCHECKSECURITY @@dontCheckSecurity
                end
                if defined?(@@cvv)
                  xml.CVV @@cvv
                end
                if defined?(@@issueNo)
                  xml.ISSUENO @@issueNo
                end
                }
        end#end of loop
        return @requestXML.to_xml##Need to change
      end
   end
        ##
         #  Used for processing XML SecureCard Update Request through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
         ##
     class XmlSecureCardUpdRequest < Request

          @@terminalId
          @@dateTime
          @@hash
          @@cvv
          @@merchantRef
          @@cardNumber
          @@cardExpiry
          @@cardHolderName
          @@issueNo
          @@dontCheckSecurity
    
          #  Creates the SecureCard Registration/Update request for processing
          #  through the WorldNetTPS XML Gateway
          #
          #  @param merchantRef A unique card identifier. Alpha numeric and max size 48 chars.
          #  @param terminalId Terminal ID provided by WorldNet TPS
          #  @param cardNumber A valid Card Number that passes the Luhn Check.
          #  @param cardType
          #  Card Type (Accepted Card Types must be configured in the Merchant Selfcare System.)
          #
          #  Accepted Values :
          #
          #  VISA
          #  MASTERCARD
          #  LASER
          #  SWITCH
          #  SOLO
          #  AMEX
          #  DINERS
          #  MAESTRO
          #  DELTA
          #  ELECTRON
          #
          #  @param cardExpiry Card Expiry formatted MMYY
          #  @param cardHolderName Card Holder Name
          
          def  XmlSecureCardUpdRequest(merchantRef,
              terminalId,
              cardNumber,
              cardExpiry,
              cardType,
              cardHolderName)
      
              @@dateTime = GetFormattedDate()
              @@merchantRef = merchantRef
              @@terminalId = terminalId
              @@cardNumber = cardNumber
              @@cardExpiry = cardExpiry
              @@cardType = cardType
              @@cardHolderName = cardHolderName
          end
    
          #  Setter for dontCheckSecurity setting
          #
          #  @param dontCheckSecurity can be either "Y" or "N".
    
          def  SetDontCheckSecurity(dontCheckSecurity)
              @@dontCheckSecurity = dontCheckSecurity
          end
    
          #  Setter for Card Verification Value
          #
          #  @param cvv Numeric field with a max of 4 characters.
    
          def  SetCvv(cvv)
             @@cvv = cvv
          end
    
          #  Setter for Issue No
          #
          #  @param issueNo Numeric field with a max of 3 characters.
    
          def  SetIssueNo(issueNo)
             @@issueNo = issueNo
          end
    
          #  Setter for hash value
          #
          #  @param sharedSecret
          #  Shared secret either supplied by WorldNet TPS or configured under
          #  Terminal Settings in the Merchant Selfcare System.
    
          def  SetHash(sharedSecret)
              @@hash = GetRequestHash(@@terminalId + @@merchantRef + @@dateTime + @@cardNumber + @@cardExpiry + @@cardType + @@cardHolderName + sharedSecret)
          end
    
          #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
          #
          #  @param sharedSecret
          #  Shared secret either supplied by WorldNet TPS or configured under
          #  Terminal Settings in the Merchant Selfcare System.
          #
          #  @param testAccount
          #  Boolean value defining Mode
          #  true - This is a test account
          #  false - Production mode, all transactions will be processed by Issuer.
          #
          #  @return XmlSecureCardRegResponse containing an error or the parsed payment response.
    
          def  ProcessRequest(sharedSecret, testAccount)
             return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
          end
    
          def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
              SetHash(sharedSecret)
              responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
              response =  XmlSecureCardUpdResponse.new
              return response.XmlSecureCardUpdResponse(responseString)
          end
    
          def  GenerateXml()
    
            @requestXML = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
               xml.SECURECARDUPDATE {
                    xml.MERCHANTREF @@merchantRef
                    xml.TERMINALID @@terminalId
                    xml.DATETIME @@dateTime
                    xml.CARDNUMBER @@cardNumber
                    xml.CARDEXPIRY @@cardExpiry
                    xml.CARDTYPE @@cardType
                    xml.CARDHOLDERNAME @@cardHolderName
                    xml.HASH @@hash
               if defined?(@@dontCheckSecurity)
                    xml.DONTCHECKSECURITY @@dontCheckSecurity
               end
               if defined?(cvv)
                     xml.CVV @@cvv
               end
               if defined?(issueNo)
                     xml.ISSUENO @@issueNo
               end
            }
         end#end of loop
            return @requestXML.to_xml
         end
    end

        
         #  Used for processing XML SecureCard deletion through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
         
    class XmlSecureCardDelRequest < Request

          @@terminalId
          @@dateTime
          @@hash
          @@merchantRef
          @@secureCardCardRef
    
          #  Creates the SecureCard searche request for processing
          #  through the WorldNetTPS XML Gateway
          #
          #  @param merchantRef A unique card identifier. Alpha numeric and max size 48 chars.
          #  @param terminalId Terminal ID provided by WorldNet TPS
          def  XmlSecureCardDelRequest(merchantRef,
            terminalId,
            secureCardCardRef)
    
            @@dateTime = GetFormattedDate()
            @@merchantRef = merchantRef
            @@terminalId = terminalId
            @@secureCardCardRef = secureCardCardRef
          end
    
          #  Setter for hash value
          #
          #  @param sharedSecret
          #  Shared secret either supplied by WorldNet TPS or configured under
          #  Terminal Settings in the Merchant Selfcare System.
    
          def  SetHash(sharedSecret)
    
            @@hash = GetRequestHash(@@terminalId + @@merchantRef + @@dateTime + @@secureCardCardRef + sharedSecret)
          end
    
          #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
          #
          #  @param sharedSecret
          #  Shared secret either supplied by WorldNet TPS or configured under
          #  Terminal Settings in the Merchant Selfcare System.
          #
          #  @param testAccount
          #  Boolean value defining Mode
          #  true - This is a test account
          #  false - Production mode, all transactions will be processed by Issuer.
          #
          #  @return XmlSecureCardRegResponse containing an error or the parsed payment response.
    
          def  ProcessRequest(sharedSecret, testAccount)
    
            return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
          end
    
          def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
    
              SetHash(sharedSecret)
              responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
              response = XmlSecureCardDelResponse.new
              return response.XmlSecureCardDelResponse(responseString)
          end
    
          def  GenerateXml()
    
            @requestXML =  Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                xml.SECURECARDREMOVAL {
                    xml.MERCHANTREF @@merchantRef
                    xml.CARDREFERENCE @@secureCardCardRef
                    xml.TERMINALID @@terminalId
                    xml.DATETIME @@dateTime
                    xml.HASH @@hash
    
                    }
                  end#end of the loop
            return @requestXML.to_xml
          end
    end

         #  Used for processing XML SecureCard searching through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
         
     class XmlSecureCardSearchRequest < Request
              @@terminalId
              @@dateTime
              @@hash
              @@merchantRef
               
               #  Creates the SecureCard searche request for processing
               #  through the WorldNetTPS XML Gateway
               #
               #  @param merchantRef A unique card identifier. Alpha numeric and max size 48 chars.
               #  @param terminalId Terminal ID provided by WorldNet TPS
               
              def  XmlSecureCardSearchRequest(merchantRef,
                  terminalId)
               
                  @@dateTime = GetFormattedDate()
          
                  @@merchantRef = merchantRef
                  @@terminalId = terminalId
              end
               
               #  Setter for hash value
               #
               #  @param sharedSecret
               #  Shared secret either supplied by WorldNet TPS or configured under
               #  Terminal Settings in the Merchant Selfcare System.
               
              def  SetHash(sharedSecret)
               
                  @@hash = GetRequestHash(@@terminalId + @@merchantRef + @@dateTime + sharedSecret)
              end
               
               #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
               #
               #  @param sharedSecret
               #  Shared secret either supplied by WorldNet TPS or configured under
               #  Terminal Settings in the Merchant Selfcare System.
               #
               #  @param testAccount
               #  Boolean value defining Mode
               #  true - This is a test account
               #  false - Production mode, all transactions will be processed by Issuer.
               #
               #  @return XmlSecureCardRegResponse containing an error or the parsed payment response.
               
              def  ProcessRequest(sharedSecret, testAccount)
                 return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
              end
          
              def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
               
                  SetHash(sharedSecret)
                  responseString =SendRequestToGateway(GenerateXml(), testAccount, gateway)
                  response = XmlSecureCardSearchResponse.new
                  return response.XmlSecureCardSearchResponse(responseString)
              end
          
              def  GenerateXml()
                  
                  @requestXML =  Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                      xml.SECURECARDSEARCH {
                         xml.MERCHANTREF @@merchantRef
                         xml.TERMINALID @@terminalId
                         xml.DATETIME @@dateTime
                         xml.HASH @@hash
                        }
               end
                  return @requestXML.to_xml
              end
        end
         #  Used for processing XML Stored Subscription Registration Request through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
        
        class XmlStoredSubscriptionRegRequest < Request
          
          @@terminalId
          @@dateTime
          @@hash
          @@merchantRef
          @@name
          @@description
          @@periodType
          @@length
          @@recurringAmount
          @@initialAmount
          @@type
          @@onUpdate
          @@onDelete
            
             #  Creates the SecureCard Registration/Update request for processing
             #  through the WorldNetTPS XML Gateway
             #
             #  @param merchantRef A unique subscription identifier. Alpha numeric and max size 48 chars.
             #  @param terminalId Terminal ID provided by WorldNet TPS
             #  @param secureCardMerchantRef A valid, registered SecureCard Merchant Reference.
             #  @param name Name of the subscription
             #  @param description Card Holder Name
             
            def  XmlStoredSubscriptionRegRequest(merchantRef,
                terminalId,
                name,
                description,
                periodType,
                length,
                currency,
                recurringAmount,
                initialAmount,
                type,
                onUpdate,
                onDelete)
             
                @@dateTime = GetFormattedDate()
        
        
                @@merchantRef = merchantRef
                @@terminalId = terminalId
        
                @@name = name
                @@description = description
                @@periodType = periodType
                @@length = length
                @@currency = currency
                @@recurringAmount = recurringAmount
                @@initialAmount = initialAmount
                @@type = type
                @@onUpdate = onUpdate
                @@onDelete = onDelete
            end
             
             #  Setter for hash value
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             
            def  SetHash(sharedSecret)
                @@hash = GetRequestHash(@@terminalId + @@merchantRef + @@dateTime + @@type + @@name + @@periodType + @@currency + @@recurringAmount + @@initialAmount + @@length + sharedSecret)
            end
             
             #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             #
             #  @param testAccount
             #  Boolean value defining Mode
             #  true - This is a test account
             #  false - Production mode, all transactions will be processed by Issuer.
             #
             #  @return XmlSecureCardRegResponse containing an error or the parsed payment response.
             
            def  ProcessRequest(sharedSecret, testAccount)
            
                return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
            end
        
            def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
            
                SetHash(sharedSecret)
                responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
                response = XmlStoredSubscriptionRegResponse.new
                return response.XmlStoredSubscriptionRegResponse(responseString)
            end
        
            def  GenerateXml()
            
                  @requestXML =  Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                  xml.ADDSTOREDSUBSCRIPTION {
                    xml.MERCHANTREF @@merchantRef
                    xml.TERMINALID @@terminalId
                    xml.DATETIME @@dateTime
                    xml.NAME @@name
                    xml.DESCRIPTION @@description
                    xml.PERIODTYPE @@periodType
                    xml.LENGTH @@length
                    xml.CURRENCY @@currency
                  
                  
                 if @@type!= "AUTOMATIC (WITHOUT AMOUNTS)"
                    xml.RECURRINGAMOUNT @@recurringAmount
                    xml.INITIALAMOUNT @@initialAmount
                 end
                  
                    xml.TYPE @@type
                    xml.ONUPDATE @@onUpdate
                    xml.ONDELETE @@onDelete
                    xml.HASH @@hash
             }
             end
                return @requestXML.to_xml
            end
        end
        ##
         #  Used for processing XML Stored Subscription Update requestthrough the WorldNet TPS XML Gateway.
         #  Basic request is configured on initialisation and optional fields can be configured.
         #
        
    class XmlStoredSubscriptionUpdRequest < Request
          
           @@terminalId
           @@dateTime
           @@hash
           @@merchantRef
           @@name
           @@description
           @@periodType
           @@length
           @@recurringAmount
           @@initialAmount
           @@type
           @@onUpdate
           @@onDelete
           @@currency
            
             #  Creates the SecureCard Registration/Update request for processing
             #  through the WorldNetTPS XML Gateway
             #
             #  @param merchantRef A unique subscription identifier. Alpha numeric and max size 48 chars.
             #  @param terminalId Terminal ID provided by WorldNet TPS
             #  @param secureCardMerchantRef A valid, registered SecureCard Merchant Reference.
             #  @param name Name of the subscription
             #  @param description Card Holder Name
             
            def  XmlStoredSubscriptionUpdRequest(merchantRef,
                terminalId,
                name,
                description,
                periodType,
                length,
                currency,
                recurringAmount,
                initialAmount,
                type,
                onUpdate,
                onDelete)
             
                @@dateTime = GetFormattedDate()
        
                @@merchantRef = merchantRef
                @@terminalId = terminalId
        
                @@name = name
                @@description = description
                @@periodType = periodType
                @@length = length
                @@currency = currency
                @@recurringAmount = recurringAmount
                @@initialAmount = initialAmount
                @@type = type
                @@onUpdate = onUpdate
                @@onDelete = onDelete
            end
             
             #  Setter for hash value
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             
            def  SetHash(sharedSecret)
             
                @@hash = GetRequestHash(@@terminalId + @@merchantRef + @@dateTime + @@type + @@name + @@periodType + @@currency + @@recurringAmount + @@initialAmount + @@length + sharedSecret)
            end
             
             #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             #
             #  @param testAccount
             #  Boolean value defining Mode
             #  true - This is a test account
             #  false - Production mode, all transactions will be processed by Issuer.
             #
             #  @return XmlSecureCardRegResponse containing an error or the parsed payment response.
             
            def  ProcessRequest(sharedSecret, testAccount)
             
                return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
            end
        
            def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
             
                SetHash(sharedSecret)
                responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
                response = XmlStoredSubscriptionUpdResponse.new
                return response.XmlStoredSubscriptionUpdResponse(responseString)
             end
        
            def  GenerateXml()
                @requestXML =  Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                xml.UPDATESTOREDSUBSCRIPTION {
                    xml.MERCHANTREF @@merchantRef
                    xml.TERMINALID @@terminalId
                    xml.DATETIME @@dateTime
                    xml.NAME @@name
                    xml.DESCRIPTION @@description
                    xml.PERIODTYPE @@periodType
                    xml.LENGTH @@length
                    xml.CURRENCY @@currency
                
                if @@type!= "AUTOMATIC (WITHOUT AMOUNTS)"
                    xml.RECURRINGAMOUNT @@recurringAmount
                    xml.INITIALAMOUNT @@initialAmount
                end
                    xml.TYPE @@type
                    xml.ONUPDATE @@onUpdate
                    xml.ONDELETE @@onDelete
                    xml.HASH @@hash
                }
              end #end of loop
          return @requestXML.to_xml
      end
    end
        
         #  Used for processing XML Stored Subscription Delete Request through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
         
    class XmlStoredSubscriptionDelRequest < Request
         
            @@terminalId
            @@dateTime
            @@hash
            @@merchantRef
            
            
            
             #  Creates the SecureCard Registration/Update request for processing
             #  through the WorldNetTPS XML Gateway
             #
             #  @param merchantRef A unique subscription identifier. Alpha numeric and max size 48 chars.
             #  @param terminalId Terminal ID provided by WorldNet TPS
             
            def  XmlStoredSubscriptionDelRequest(merchantRef,
                terminalId)
             
                @@dateTime = GetFormattedDate()
        
                @@merchantRef = merchantRef
                @@terminalId = terminalId
            end
             
             #  Setter for hash value
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             
            def  SetHash(sharedSecret)
             
                @@hash = GetRequestHash(@@terminalId + @@merchantRef + @@dateTime + sharedSecret)
            end
             
             #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             #
             #  @param testAccount
             #  Boolean value defining Mode
             #  true - This is a test account
             #  false - Production mode, all transactions will be processed by Issuer.
             #
             #  @return XmlSecureCardRegResponse containing an error or the parsed payment response.
             
            def  ProcessRequest(sharedSecret, testAccount)
             
                return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
            end
        
            def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
             
                SetHash(sharedSecret)
                responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
                response = XmlStoredSubscriptionDelResponse.new
                return response.XmlStoredSubscriptionDelResponse(responseString)
            end
        
            def  GenerateXml()
             
                @requestXML =  Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                    xml.DELETESTOREDSUBSCRIPTION {
                        xml.MERCHANTREF @@merchantRef
                        xml.TERMINALID @@terminalId
                        xml.DATETIME @@dateTime
                        xml.HASH @@hash
                  }
                end #end of loop
                return @requestXML.to_xml
            end
        end
        
        
         ##
         # Used for processing XML Subscription Registrations  through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
         ##
    class XmlSubscriptionRegRequest < Request
          
          @@terminalId 
          @@dateTime
          @@hash
          @@merchantRef
          @@name
          @@description
          @@periodType
          @@length
          @@recurringAmount
          @@initialAmount
          @@type
          @@onUpdate
          @@onDelete
          @@currency
          @@startDate
          @@endDate
          @@storedSubscriptionRef
          @@secureCardMerchantRef
          @@eDCCDecision
          @@newStoredSubscription = false
        
            def  SetNewStoredSubscriptionValues(name,
                description,
                periodType,
                length,
                currency,
                recurringAmount,
                initialAmount,
                type,
                onUpdate,
                onDelete)
             
                @@name = name
                @@description = description
                @@periodType = periodType
                @@length = length
                @@currency = currency
                @@recurringAmount = recurringAmount
                @@initialAmount = initialAmount
                @@type = type
                @@onUpdate = onUpdate
                @@onDelete = onDelete
        
                @@newStoredSubscription = true
            end
            
            def  SetSubscriptionAmounts(recurringAmount,
                initialAmount)
             
                @@recurringAmount = recurringAmount
                @@initialAmount = initialAmount
            end
             
             #  Setter for end date
             #
             #  @param endDate End Date of subscription
             
            def  SetEndDate(endDate)
             
                @@endDate = endDate
            end
             
             #  Setter for when the cardholder has accepted the eDCC offering
             #
             #  @param eDCCDecision eDCC decision ("Y" or "N")
             
            def  EDCCDecision(eDCCDecision)
            
                @@eDCCDecision = eDCCDecision
            end
            
             #  Creates the SecureCard Registration/Update request for processing
             #  through the WorldNetTPS XML Gateway
             #
             #  @param merchantRef A unique subscription identifier. Alpha numeric and max size 48 chars.
             #  @param terminalId Terminal ID provided by WorldNet TPS
        
             #  @param storedSubscriptionRef Name of the Stored subscription under which this subscription should run
             #  @param secureCardMerchantRef A valid, registered SecureCard Merchant Reference.
             #  @param startDate Card Holder Name
             
            def  XmlSubscriptionRegRequest(merchantRef,
                terminalId,
                storedSubscriptionRef,
                secureCardMerchantRef,
                startDate)
            
                @@dateTime = GetFormattedDate()
        
                @@storedSubscriptionRef = storedSubscriptionRef
                @@secureCardMerchantRef = secureCardMerchantRef
                @@merchantRef = merchantRef
                @@terminalId = terminalId
                @@startDate = startDate
            end
             
             #  Setter for hash value
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             
            def  SetHash(sharedSecret)
             
                if @@newStoredSubscription == true 
                  @@hash = GetRequestHash(@@terminalId + @@merchantRef + @@secureCardMerchantRef + @@dateTime + @@startDate + sharedSecret)
               else 
                  @@hash = GetRequestHash(@@terminalId + @@merchantRef + @@storedSubscriptionRef + @@secureCardMerchantRef + @@dateTime + @@startDate + sharedSecret)
               end
            end
             
             #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             #
             #  @param testAccount
             #  Boolean value defining Mode
             #  true - This is a test account
             #  false - Production mode, all transactions will be processed by Issuer.
             #
             #  @return XmlSecureCardRegResponse containing an error or the parsed payment response.
             
            def  ProcessRequest(sharedSecret, testAccount)
            
                return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
            end
        
            def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
            
                SetHash(sharedSecret)
                responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
                response =  XmlSubscriptionRegResponse.new
                return response.XmlSubscriptionRegResponse(responseString)
            end
        
            def  GenerateXml()
                @requestXML =  Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                      xml.ADDSUBSCRIPTION {
                          xml.MERCHANTREF @@merchantRef
                          xml.TERMINALID @@terminalId
                   if @@newStoredSubscription!= true
                          xml.STOREDSUBSCRIPTIONREF @@storedSubscriptionRef
                   end
                          xml.SECURECARDMERCHANTREF @@secureCardMerchantRef
                          xml.DATETIME @@dateTime
                    
                   if defined?(@@recurringAmount) && defined?(@@recurringAmount) && @@newStoredSubscription!= true
                  
                          xml.RECURRINGAMOUNT @@recurringAmount
                          xml.INITIALAMOUNT @@initialAmount  
                   end
                 
                          xml.STARTDATE @@startDate
                 
                   if defined?(@@endDate)
                
                          xml.ENDDATE @@endDate
                   end
        
                  if defined?(@@eDCCDecision)
                
                          xml.EDCCDECISION @@eDCCDecision
                  end
                
                if @@newStoredSubscription == true
               
                          xml.NEWSTOREDSUBSCRIPTIONINFO {
                          xml.MERCHANTREF @@merchantRef
                          xml.NAME @@name
                          xml.DESCRIPTION @@description
                          xml.PERIODTYPE @@periodType
                          xml.LENGTH @@length
                          xml.CURRENCY @@currency
                  
               if @@type!= "AUTOMATIC (WITHOUT AMOUNTS)"
                          xml.RECURRINGAMOUNT @@recurringAmount
                          xml.INITIALAMOUNT @@initialAmount
               end
                          xml.TYPE @@type
                          xml.ONUPDATE @@onUpdate
                          xml.ONDELETE @@onDelete
                  
                       }
                          xml.HASH @@hash
                         end
                     }
                     end
              return @requestXML.to_xml
           end
     end
        
        
         #  Used for processing XML Subscription Update through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
         
     class XmlSubscriptionUpdRequest < Request
        
            @@terminalId
            @@dateTime
            @@hash
            @@merchantRef
            @@name
            @@description
            @@periodType
            @@length
            @@recurringAmount
            @@eDCCDecision
            @@secureCardMerchantRef
            @@startDate
            @@endDate
            @@type
          
             #  Setter for subscription name
             #
             #  @param name Subscription name
             
            def  SetSubName(name)
            
                @@name = name
            end
             
             #  Setter for subscription description
             #
             #  @param description Subscription description
             
            def  SetDescription(description)
            
                @@description = description
            end
             ##
             #  Setter for subscription period type
             #
             #  @param periodType Subscription period type
             #
            def  SetPeriodType(periodType)
            
                @@periodType = periodType
            end
             ##
             #  Setter for subscription length
             #
             #  @param length Subscription length
             #
            def  SetLength(length)
            
                @@length = length
            end
             
             #  Setter for subscription recurring amount
             #
             #  @param recurringAmount Subscription recurring amount
             
            def  SetRecurringAmount(recurringAmount)
            
                @@recurringAmount = recurringAmount
            end
             ##
             #  Setter for stored subscription type
             #
             #  @param endDate Stored subscription type
             #
            def  SetSubType(type)
            
                @@type = type
            end
             ##
             #  Setter for stored subscription start date
             #
             #  @param startDate Stored subscription start date
             #
            def  SetStartDate(startDate)
                 @@startDate = startDate
            end
             ##
             #  Setter for stored subscription end date
             #
             #  @param endDate Stored subscription end date
             #
            def  SetEndDate(endDate)
                   @@endDate = endDate
            end
             ##
             #  Setter for when the cardholder has accepted the eDCC offering
             #
             #  @param eDCCDecision eDCC decision ("Y" or "N")
             #
            def  EDCCDecision(eDCCDecision)
            
                @@eDCCDecision = eDCCDecision
            end
            ##
             #  Creates the SecureCard Update request for processing
             #  through the WorldNetTPS XML Gateway
             #
             #  @param merchantRef A unique subscription identifier. Alpha numeric and max size 48 chars.
             #  @param terminalId Terminal ID provided by WorldNet TPS.
             #  @param secureCardMerchantRef Reference to the existing or new SecureCard for the subscription.
             #
            def  XmlSubscriptionUpdRequest(merchantRef,
                terminalId,
                secureCardMerchantRef)
            
                @@dateTime = GetFormattedDate()
        
                @@merchantRef = merchantRef
                @@terminalId = terminalId
                @@secureCardMerchantRef = secureCardMerchantRef
            end
             ##
             #  Setter for hash value
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             #
            def  SetHash(sharedSecret)
                    @@hash = GetRequestHash(@@terminalId + @@merchantRef + @@secureCardMerchantRef + @@dateTime + @@startDate + sharedSecret)
            end
             ##
             #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             #
             #  @param testAccount
             #  Boolean value defining Mode
             #  true - This is a test account
             #  false - Production mode, all transactions will be processed by Issuer.
             #
             #  @return XmlSecureCardRegResponse containing an error or the parsed payment response.
             #
            def  ProcessRequest(sharedSecret, testAccount)
            
               return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
            end
        
            def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
            
                SetHash(sharedSecret)
                responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
                response = XmlSubscriptionUpdResponse.new
                return response.XmlSubscriptionUpdResponse(responseString)
            end
        
            def  GenerateXml()
            
                 @requestXML =  Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                     xml.UPDATESUBSCRIPTION {
                        xml.MERCHANTREF @@merchantRef
                        xml.TERMINALID @@terminalId
                        xml.SECURECARDMERCHANTREF @@secureCardMerchantRef
                        xml.DATETIME @@dateTime
                    if defined?(@@name) 
                        xml.NAME @@name
                    end
        
                    if defined?(@@description)
                        xml.DESCRIPTION @@description
                    end 
               
        
                    if defined?(@@periodType)
                        xml.PERIODTYPE @@periodType
                    end
        
                    if defined?(@@length)
                        xml.LENGTH @@length
                    end
        
                    if defined?(@@recurringAmount)
                        xml.RECURRINGAMOUNT @@recurringAmount
                    end     
        
                    if defined?(@@type)
                        xml.TYPE @@type
                    end     
                   
                    if defined?(@@startDate)
                        xml.STARTDATE @@startDate
                    end
        
                    if defined?(@@endDate)
                        xml.ENDDATE @@endDate
                    end
        
                    if defined?(@@eDCCDecision)
                        xml.EDCCDECISION @@eDCCDecision
                    end
                        xml.HASH @@hash
                }
                    end
                return @requestXML.to_xml
            end
      end
        
         #  Used for processing XML Subscription Deletion through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
         
    class XmlSubscriptionDelRequest < Request
          
          @@terminalId
          @@dateTime
          @@hash
          @@merchantRef
        
            ##
             #  Creates the SecureCard Registration/Update request for processing
             #  through the WorldNetTPS XML Gateway
             #
             #  @param merchantRef A unique subscription identifier. Alpha numeric and max size 48 chars.
             #  @param terminalId Terminal ID provided by WorldNet TPS
             #
            def  XmlSubscriptionDelRequest(merchantRef,
                terminalId)
            
               @@dateTime = GetFormattedDate()
        
                @@merchantRef = merchantRef
                @@terminalId = terminalId
            end
             ##
             #  Setter for hash value
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             #
            def  SetHash(sharedSecret)
                @@hash = GetRequestHash(@@terminalId + @@merchantRef + @@dateTime + sharedSecret)
            end
             ##
             #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             #
             #  @param testAccount
             #  Boolean value defining Mode
             #  true - This is a test account
             #  false - Production mode, all transactions will be processed by Issuer.
             #
             #  @return XmlSecureCardRegResponse containing an error or the parsed payment response.
             #
            def  ProcessRequest(sharedSecret, testAccount)
            
                return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
            end
        
            def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
            
                SetHash(sharedSecret)
                responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
                response = XmlSubscriptionDelResponse.new
                return response.XmlSubscriptionDelResponse(responseString)
            end
        
            def  GenerateXml()
              
                @requestXML =  Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
                  xml.DELETESUBSCRIPTION {
                
                xml.MERCHANTREF @@merchantRef
                xml.TERMINALID @@terminalId
                xml.DATETIME @@dateTime
                xml.HASH @@hash
                }
                end
                return @requestXML.to_xml
            end
        end
        
        
         #  Used for processing XML Subscription Payment through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
        
        class XmlSubscriptionPaymentRequest < Request
          
          @@terminalId
          @@dateTime
          @@hash
          @@orderId
          @@subscriptionRefe
          @@amount
          @@cardCurrency
          @@cardAmount
          @@conversionRate
          @@email
          @@foreignCurInfoSet
          @@foreignCurInfoSet = false
        
             ##
             #  Setter for Email Address Value
             #
             #  @param email Alpha-numeric field.
             #
            def  SetEmail(email)
             @@email = email
            end
             ##
             #  Setter for Foreign Currency Information
             #
             #  @param cardCurrency ISO 4217 3 Digit Currency Code, e.g. EUR / USD / GBP
             #  @param cardAmount (Amount X Conversion rate) Formatted to two decimal places
             #  @param conversionRate Converstion rate supplied in rate response
             #
            def  SetForeignCurrencyInformation(cardCurrency, cardAmount, conversionRate)
            
                @@cardCurrency = cardCurrency
                @@cardAmount = cardAmount
                @@conversionRate = conversionRate
        
                @@foreignCurInfoSet = true
            end
        
            def  XmlSubscriptionPaymentRequest(terminalId,
                orderId,
                amount,
                subscriptionRef)
            
                @@dateTime = GetFormattedDate()
        
                @@terminalId = terminalId
                @@orderId = orderId
                @@amount = amount
                @@subscriptionRef = subscriptionRef
            end
             ##
             #  Setter for hash value
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             #
            def  SetHash(sharedSecret)
            
                @@hash = GetRequestHash(@@terminalId + @@orderId + @@subscriptionRef + @@amount + @@dateTime + sharedSecret)
            end
             ##
             #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
             #
             #  @param testAccount
             #  Boolean value defining Mode
             #  true - This is a test account
             #  false - Production mode, all transactions will be processed by Issuer.
             #
             #  @return XmlSecureCardRegResponse containing an error or the parsed payment response.
             #
            def  ProcessRequest(sharedSecret, testAccount)
            
                return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
            end
        
            def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
           
                SetHash(sharedSecret)
                responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
                response = XmlSubscriptionPaymentResponse.new
                return response.XmlSubscriptionPaymentResponse(responseString)
           end
        
            def  GenerateXml()
           
                @requestXML =  Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
                xml.SUBSCRIPTIONPAYMENT {
                
                xml.ORDERID @@orderId
                xml.TERMINALID @@terminalId
                xml.AMOUNT @@amount
                xml.SUBSCRIPTIONREF @@subscriptionRef
        
        
                if @@foreignCurInfoSet == true
                 
                xml.FOREIGNCURRENCYINFORMATION {
                xml.CARDCURRENCY @@cardCurrency
                xml.CARDAMOUNT @@cardAmount
                xml.CONVERSIONRATE @@conversionRate
                }
               end 
                if defined?(@@email)
                 xml.EMAIL @@email
                end
        
                xml.DATETIME @@dateTime
                xml.HASH @@hash
              }
              end
                return @requestXML.to_xml
            end
        end
        
        
         #  Used for processing XML Unreferenced Refund through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
         #
        class XmlUnreferencedRefundRequest < Request
        
           @@terminalId
           @@dateTime
           @@hash
           @@orderId
           @@secureCardMerchantRef
           @@amount
           @@email
           @@autoReady
           @@operator
           @@description   
            
             #  Creates the SecureCard Registration/Update request for processing
             #  through the WorldNetTPS XML Gateway
             #
             #  @param merchantRef A unique subscription identifier. Alpha numeric and max size 48 chars.
        
             #  @param terminalId Terminal ID provided by WorldNet TPS
             #
            def  XmlUnreferencedRefundRequest(orderId,
                terminalId,
                secureCardMerchantRef,
                amount,
                operator)
            
               @@dateTime = GetFormattedDate()
        
                @@orderId = orderId
                @@terminalId = terminalId
                @@secureCardMerchantRef = secureCardMerchantRef
                @@amount = amount
                @@operator = operator
            end
             ##
        
             #  Setter for Transaction Description
             #
             #  @param email Alpha-numeric field.
             #
            def  SetDescription(description)
              @@description = description
            end
             ##
             #  Setter for Email Address Value
        
             #
             #  @param email Alpha-numeric field.
             #
            def  SetEmail(email)
              @@email = email
            end
             ##
             #  Setter for Auto Ready Value
             #
             #  @param autoReady
        
             #  Auto Ready is an optional parameter and defines if the transaction should be settled automatically.
             #
             #  Accepted Values :
             #
             #  Y   -   Transaction will be settled in next batch
             #  N   -   Transaction will not be settled until user changes state in Merchant Selfcare Section
        
             #
            def  SetAutoReady(autoReady)
              @@autoReady = autoReady
            end
             ##
             #  Setter for hash value
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
        
             #
            def  SetHash(sharedSecret)
              @@hash = GetRequestHash(@@terminalId + @@orderId + @@amount + @@dateTime + sharedSecret)
            end
             ##
             #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
             #
             #  @param sharedSecret
             #  Shared secret either supplied by WorldNet TPS or configured under
             #  Terminal Settings in the Merchant Selfcare System.
        
             #
             #  @param testAccount
             #  Boolean value defining Mode
             #  true - This is a test account
             #  false - Production mode, all transactions will be processed by Issuer.
        
             #
             #  @return XmlSecureCardRegResponse containing an error or the parsed payment response.
             #
            def  ProcessRequest(sharedSecret, testAccount)
              return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
            end
        
            def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
                SetHash(sharedSecret)
                responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
                response = XmlUnreferencedRefundResponse.new
                return response.XmlUnreferencedRefundResponse(responseString)
            end
        
          def  GenerateXml()
                @requestXML =  Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                    xml.UNREFERENCEDREFUND {
                       xml.ORDERID @@orderId
                       xml.TERMINALID @@terminalId
                       xml.CARDREFERENCE @@secureCardMerchantRef
                       xml.AMOUNT @@amount
                
                   if defined?(@@email)
                       xml.EMAIL @@email
                   end
                
                   if defined?(@@autoReady)        
                      xml.AUTOREADY @@autoReady
                   end
                      xml.DATETIME @@dateTime
                      xml.HASH @@hash
                      xml.OPERATOR @@operator
                
                  if defined?(@@description)
                     xml.DESCRIPTION @@description
                  end
               }
                  end
             return @requestXML.to_xml
          end
    end
        
         #  Used for processing XML VoiceId through the WorldNet TPS XML Gateway.
         #
         #  Basic request is configured on initialisation and optional fields can be configured.
    class XmlVoiceIDRequest < Request
        
               @@terminalId
               @@dateTime
               @@hash
               @@orderId
               @@mobileNumber
               @@amount
               @@email
               @@currency
               @@description
               
              
                @@amount = ""
                @@currency = ""
                 ##
                 #  Creates the SecureCard Registration/Update request for processing
                 #  through the WorldNetTPS XML Gateway
                 #
                 #  @param merchantRef A unique subscription identifier. Alpha numeric and max size 48 chars.
            
                 #  @param terminalId Terminal ID provided by WorldNet TPS
                 #
                def  XmlVoiceIDRequest(orderId,
                    terminalId,
                    mobileNumber,
                    email)
                
                    @@dateTime = GetFormattedDate()
            
                    @@orderId = orderId
                    @@terminalId = terminalId
                    @@mobileNumber = mobileNumber
                    @@email = email
                end
                 ##
            
                 #  Setter for Transaction Description
                 #
                 #  @param email Alpha-numeric field.
                 #
                def  SetVoicePayInformation(amount, currency)
                    @@amount = amount
                    @@currency = currency
                end
                 ##
                 #  Setter for Email Address Value
                 #
                 #  @param email Alpha-numeric field.
                 #
                def  SetDescription(description)
                   @@description = description
               end
                 ##
                 #  Setter for hash value
                 #
                 #  @param sharedSecret
                 #  Shared secret either supplied by WorldNet TPS or configured under
                 #  Terminal Settings in the Merchant Selfcare System.
            
                 #
                def  SetHash(sharedSecret)
                 @@hash = GetRequestHash(@@terminalId + @@orderId + @@dateTime + @@mobileNumber + @@email + @@currency + @@amount + sharedSecret)
                end
                 ##
                 #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
                 #
                 #  @param sharedSecret
                 #  Shared secret either supplied by WorldNet TPS or configured under
                 #  Terminal Settings in the Merchant Selfcare System.
            
                 #
                 #  @param testAccount
                 #  Boolean value defining Mode
                 #  true - This is a test account
                 #  false - Production mode, all transactions will be processed by Issuer.
            
                 #
                 #  @return XmlSecureCardRegResponse containing an error or the parsed payment response.
                 #
                def  ProcessRequest(sharedSecret, testAccount)
                 return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
                end
            
                def  ProcessRequestToGateway(sharedSecret, testAccount, gateway)
                
                    SetHash(sharedSecret)
                    responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway)
                    response = XmlVoiceIDResponse.new
                    return response.XmlVoiceIDResponse(responseString)
                end
            
                def  GenerateXml()
                
                   @requestXML =  Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
                    xml.VOICEIDREQUEST {
                            
                    xml.ORDERID @@orderId
                    xml.TERMINALID @@terminalId
                    xml.DATETIME @@dateTime
                    xml.MOBILENUMBER @@mobileNumber
                    xml.EMAIL @@email
                            
                   if @@amount!= "" && @@currency!= ""
                    
                    xml.VOICEIDPAYMENT {
                    xml.AMOUNT @@amount
                    xml.CURRENCY @@currency
                    }
                   end
                   
                    xml.HASH @@hash
                   
                   if defined?(@@description) 
                     xml.DESCRIPTION @@description         
                   end
            }
            end
                    return @requestXML.to_xml
                end
    end
        
    class XmlTransactionUpdateRequest < Request

          @@terminalId
          @@orderId    
          @@dateTime
          @@hash
          @@operator
          @@uniqueRef
          @@authCode
          @@fromStatus
          @@toStatus 
          
           #  Creates the TransactionUpdate request for processing an XML Transaction
           #  through the WorldNetTPS XML Gateway
           #  @param terminalId Terminal ID provided by WorldNet TPS
           #  @param orderId A unique merchant identifier. Alpha numeric and max size 12 chars.
           #  @param operator An identifier for who executed this transaction
          
           
          def XmlTransactionUpdateRequest(terminalId,
              orderId,
              operator,fromStatus,toStatus)
          
             @@dateTime = GetFormattedDate()
             @@terminalId = terminalId
             @@orderId = orderId
             @@operator = operator
             @@fromStatus = fromStatus
             @@toStatus = toStatus
             
          
           end
           #  Setter for UniqueRef
      
           #
           #  @param uniqueRef
           #  Unique Reference of transaction returned from gateway in authorisation response
           
          def SetUniqueRef(uniqueRef)
                
              @@uniqueRef = uniqueRef
          end
           
           #  Setter for AuthCodeValue
           #  AuthCode is an optional parameter and defines if the transaction should be settled automatically.
           #  The approval code of of the referral. Only required if changing a REFERRAL to PENDING or READY.
           
          def SetAuthCode(authCode)    
              @@authCode = authCode
          end
           
           #  Setter for hash value
           #
           #  @param sharedSecret
           #  Shared secret either supplied by WorldNet TPS or configured under
           #  Terminal Settings in the Merchant Selfcare System.
           
          def SetHash(sharedSecret)    
              if defined?(@@authCode)
                 @@hash = GetRequestHash(@@terminalId + @@uniqueRef + @@operator + @@fromStatus + @@toStatus + @@authCode + @@dateTime + sharedSecret)
              else 
                 @@hash = GetRequestHash(@@terminalId + @@uniqueRef + @@operator + @@fromStatus + @@toStatus + @@dateTime + sharedSecret)
              end
         end
           #  Method to process transaction and return parsed response from the WorldNet TPS XML Gateway
           #
           #  @param sharedSecret
           #  Shared secret either supplied by WorldNet TPS or configured under
           #  Terminal Settings in the Merchant Selfcare System.
           #
           #  @param testAccount
           #  Boolean value defining Mode
           #  true - This is a test account
           #  false - Production mode, all transactions will be processed by Issuer.
           #
           #  @return XmlRefundResponse containing an error or the parsed refund response.
           
          def ProcessRequest(sharedSecret, testAccount)
          
              return ProcessRequestToGateway(sharedSecret, testAccount, "worldnet")
              
          end
          
          def ProcessRequestToGateway(sharedSecret, testAccount, gateway)    
              SetHash(sharedSecret)
              responseString = SendRequestToGateway(GenerateXml(), testAccount, gateway) 
              puts  responseString      
              response =  XmlTransactionUpdateResponse.new
              return response.XmlTransactionUpdateResponse(responseString)
              
          end
          def GenerateXml()
              @requestXML = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
              xml.TRANSACTIONUPDATE{
                  xml.UNIQUEREF @@uniqueRef
                  xml.TERMINALID @@terminalId
                  xml.OPERATOR @@operator
                  xml.FROMSTATUS @@fromStatus
                  xml.TOSTATUS @@toStatus
               if defined?(@@authCode)
                  xml.APPROVALCODE @@authCode
               end
                  xml.DATETIME @@dateTime
                  xml.HASH @@hash
                }
               end#end of loop
                 return @requestXML.to_xml
         end
    end
        
        
        
        
          ##
          #  Holder class for parsed Authorization response. If there was an error there will be an error string 
          #  otherwise all values will be populated with the parsed payment response values.
          #  
          #  IsError should be checked before accessing any fields.
          #  
          #  ErrorString will contain the error if one occurred.
          #
    class XmlAuthResponse  
        
              @@isError = false
              @@errorString
              @@errorCode
              @@responseCode
              @@bankResponseCode
              @@responseText
              @@approvalCode
              @@authorizedAmount
              @@dateTime
              @@avsResponse
              @@cvvResponse
              @@uniqueRef 
              @@hash
              
              
              def  IsError()
                 return @@isError
              end
              
              def  ErrorString()
                  return @@errorString
              end
              def  ErrorCode()
                if defined?(@@errorCode)
                   return @@errorCode
                else
                   return ""
                end
              end
                
              def  ResponseCode()
                  return @@responseCode
              end
              def  BankResponseCode()
                  return @@bankResponseCode
              end
              def  ResponseText()
                  return @@responseText
              end
              
              def  ApprovalCode()
                  return @@approvalCode
              end
              def  AuthorizedAmount()
                  return @@authorizedAmount
              end
              def  DateTime()
                  return @@dateTime
              end
              def  AvsResponse()
                return @@avsResponse
              end
              def  CvvResponse()
                return @@cvvResponse
              end
              def  UniqueRef()
                  return @@uniqueRef
              end
              def  Hash()
                 return @@hash
              end
          
              def  XmlAuthResponse(responseXml)
                  doc =  Nokogiri::XML(responseXml)
                    
               begin 
                    if doc.at("/ERROR")
                         @@isError = true
                         @@errorString = doc.at("/ERROR/ERRORSTRING").text
                         if doc.at("/ERROR/ERRORCODE")
                           @@errorCode = doc.at("/ERROR/ERRORCODE").text
                         end
                      
                    elsif doc.at("PAYMENTRESPONSE")
                         doc.xpath('//PAYMENTRESPONSE').children.each do |node| 
                         if node.name.match(/UNIQUEREF/)
                            @@uniqueRef = node.text
                         end
                         if node.name.match(/RESPONSECODE/)
                            @@responseCode = node.text
                         end  
                         if node.name.match(/RESPONSETEXT/)
                            @@responseText = node.text
                         end  
                         if node.name.match(/BANKRESPONSECODE/)
                            @@bankResponseCode = node.text
                         end
                         if node.name.match(/APPROVALCODE/)
                            @@approvalCode = node.text
                         end 
                         if node.name.match(/AUTHORIZEDAMOUNT/)
                            @@authorizedAmount = node.text
                         end 
                         if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                         end
                         if node.name.match(/AVSRESPONSE/)
                            @@avsResponse = node.text
                         end
                         if node.name.match(/CVVRESPONSE/)
                            @@cvvResponse = node.text
                         end
                         if node.name.match(/HASH/)
                            @@hash = node.text
                         end
                                         
                              end#end of loop
                    else
                           raise "Invalid Response"
                    end
                 
               
                   
               rescue Exception => e
                   @@isError = true
                   @@errorString = e.message
                   
               end       
               return self
             end
        end
          ##
          #  Holder class for parsed Refund response. If there was an error there will be an error string
          #  otherwise all values will be populated with the parsed payment response values.
          #
          #  IsError should be checked before accessing any fields.
          #
          #  ErrorString will contain the error if one occurred.
          ##
     class XmlRefundResponse
        
            @@isError = false
            @@errorString
            @@errorCode
            @@responseCode
            @@responseText
            @@approvalCode
            @@dateTime
            @@avsResponse
            @@uniqueRef 
            @@hash
            @@orderId
            
            def  IsError()
              return @@isError
            end
            
            
            def  ErrorString()
              return @@errorString
            end
            def  ErrorCode()
              return @@errorCode
            end
        
            
            def  ResponseCode()
              return @@responseCode
            end
            
            
            def  ResponseText()
               return @@responseText
            end
            
            
            def  OrderId()
               return @@orderId
            end
            
            
            def  DateTime()
               return @@dateTime
            end
            
            
            def  UniqueRef()
             return @@uniqueRef
            end
            
            
            def  Hash()
              return @@hash
            end
        
            def  XmlRefundResponse(responseXml)
                doc =  Nokogiri::XML(responseXml)
                 
                begin 
                    if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                       
                    elsif doc.at("REFUNDRESPONSE")
                    
                        doc.xpath('//REFUNDRESPONSE').children.each do |node| 
                        
                          if node.name.match(/RESPONSECODE/)
                            @@responseCode = node.text
                          end  
                         
                          if node.name.match(/RESPONSETEXT/)
                            @@responseText = node.text
                          end  
                          if node.name.match(/UNIQUEREF/)
                            @@uniqueRef = node.text
                          end
                          if node.name.match(/ORDERID/)
                            @@orderId = node.text
                          end 
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end   #end of the loop
                    else
                         raise "Invalid Response"
            end
                   
                rescue Exception => e
                     @@isError = true
                     @@errorString = e.message
                
                end
            return self
        end
     end
        
         #  Holder class for parsed Pre Authorization response. If there was an error there will be an error string
          #  otherwise all values will be populated with the parsed payment response values.
          #
          #  IsError should be checked before accessing any fields.
          #
          #  ErrorString will contain the error if one occurred.
          
     class XmlPreAuthResponse
           @@isError
           @@errorString
           @@errorCode
           @@responseCode
           @@responseText
           @@approvalCode
           @@dateTime
           @@avsResponse
           @@uniqueRef
           @@hash
           
            @@isError = false
            
            def  IsError()
              return @@isError
            end
        
            
            def  ErrorString()
              return @@errorString
           end
        
          
            def  ResponseCode()
              return @@responseCode
            end
        
          
            def  ResponseText()
              return @@responseText
            end
        
           
            def  ApprovalCode()
                return @@approvalCode
            end
        
         
            def  DateTime()
             return @@dateTime
            end
        
            
            def  AvsResponse()
             return @@avsResponse
            end
        
            
            def  CvvResponse()
              return @@cvvResponse
            end
        
            
            def  UniqueRef()
             return @@uniqueRef
            end
        
          
            def  Hash()
              return @@hash
            end
        
            def  XmlPreAuthResponse(responseXml)
            
                doc =  Nokogiri::XML(responseXml)
                
             begin 
                  if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                    
                       elsif doc.at("PREAUTHRESPONSE")
                    
                        doc.xpath('//PREAUTHRESPONSE').children.each do |node| 
                        
                          if node.name.match(/UNIQUEREF/)
                            @@uniqueRef = node.text
                          end
                          if node.name.match(/RESPONSECODE/)
                            @@responseCode = node.text
                          end  
                          if node.name.match(/RESPONSETEXT/)
                            @@responseText = node.text
                          end  
                          if node.name.match(/APPROVALCODE/)
                            @@approvalCode = node.text
                          end 
                          if node.name.match(/AUTHORIZEDAMOUNT/)
                            @@authorizedAmount = node.text
                          end 
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          if node.name.match(/AVSRESPONSE/)
                            @@avsResponse = node.text
                          end
                          if node.name.match(/CVVRESPONSE/)
                            @@cvvResponse = node.text
                          end
                          if node.name.match(/HASH/)
                            
                            @@hash = node.text
                          end
                        end#end of the loop
                    
                    else
                         raise "Invalid Response"
                    end
                  
               rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
               end
               
               return self
            end
      end
         ##
          #  Holder class for parsed Pre Authorization completion response. If there was an error there will be an error string 
          #  otherwise all values will be populated with the parsed payment response values.
          #  
          #  IsError should be checked before accessing any fields.
          #  
          #  ErrorString will contain the error if one occurred.
          #
        
    class XmlPreAuthCompletionResponse
             @@isError
             @@errorString
             @@errorCode
             @@responseCode
             @@responseText
             @@approvalCode
             @@dateTime
             @@avsResponse
             @@uniqueRef
             @@hash
             @@isError = false
             
            
            def  IsError()
               return @@isError
            end
        
           
            def  ErrorString()
              return @@errorString
            end
            
            def  ErrorCode()
              return @@errorCode
            end
           
            def  ResponseCode()
              return @@responseCode
            end
           
            def  ResponseText()
              return @@responseText
            end
            
            def  ApprovalCode()
               return @@approvalCode
            end
        
           
            def  DateTime()
              return @@dateTime
            end
        
            
            def  AvsResponse()
                 return @@avsResponse
            end
        
           
            def  CvvResponse()
               return @@cvvResponse
            end
            
         
            def  UniqueRef()
              return @@uniqueRef
            end
        
           
            def  Hash()
                return @@hash
            end
        
            def  XmlPreAuthCompletionResponse(responseXml)
            
                doc =  Nokogiri::XML(responseXml)
                
            begin 
                     if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                    
                     elsif doc.at("PREAUTHCOMPLETIONRESPONSE")
                    
                        doc.xpath('//PREAUTHCOMPLETIONRESPONSE').children.each do |node| 
          
                        
                          if node.name.match(/UNIQUEREF/)
                            @@uniqueRef = node.text
                          end
                          if node.name.match(/RESPONSECODE/)
                            @@responseCode = node.text
                          end  
                          if node.name.match(/RESPONSETEXT/)
                            @@responseText = node.text
                          end  
                          if node.name.match(/APPROVALCODE/)
                            @@approvalCode = node.text
                          end 
                          if node.name.match(/AUTHORIZEDAMOUNT/)
                            @@authorizedAmount = node.text
                          end 
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          if node.name.match(/AVSRESPONSE/)
                            @@avsResponse = node.text
                          end
                          if node.name.match(/CVVRESPONSE/)
                            @@cvvResponse = node.text
                          end
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end#end of the loop
                    
                    else
                         raise "Invalid Response"
                    end
                 rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
               end
               return self
           end
     end
        
        #  Holder class for parsed Rate response. If there was an error there will be an error string
          #  otherwise all values will be populated with the parsed payment response values.
          #
          #  IsError should be checked before accessing any fields.
          #
          #  ErrorString will contain the error if one occurred.
          #
     class XmlRateResponse
           @@isError
           @@errorString
           @@errorCode
           @@terminalCurrency
           @@cardCurrency
           @@conversionRate
           @@foreignAmount
           @@dateTime
           @@hash
           
           @@isError = false
            
            def  IsError()
              return @@isError
            end
         
            def  ErrorString()
              return @@errorString
            end
            
            def  ErrorCode()
              return @@errorCode
            end
        
            
            def TerminalCurrency()
               return @@terminalCurrency
            end
        
           
            def  CardCurrency()
              return @@cardCurrency
            end
        
         
            def  ConversionRate()
                return @@conversionRate
            end
            
            def  ForeignAmount()
               return @@foreignAmount
            end
           
            def  DateTime()
               return @@dateTime
            end
        
            
            def  Hash()
              return @@hash
            end
        
            def  XmlRateResponse(responseXml)
                 doc =  Nokogiri::XML(responseXml)
            begin 
                    if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                        
                         elsif (doc.at("CARDCURRENCYRATERESPONSE"))
                             doc.xpath('//CARDCURRENCYRATERESPONSE').children.each do |node| 
                             
                          if node.name.match(/TERMINALCURRENCY/)
                            @@terminalCurrency = node.text
                          end
                          if node.name.match(/CARDCURRENCY/)
                            @@cardCurrency = node.text
                          end  
                          if node.name.match(/CONVERSIONRATE/)
                            @@CONVERSIONRATE = node.text
                          end  
                          if node.name.match(/FOREIGNAMOUNT/)
                            @@foreignAmount = node.text
                          end 
                          if node.name.match(/AUTHORIZEDAMOUNT/)
                           @@authorizedAmount = node.text
                          end 
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end#end of the loop
                    
                    else
                         raise "Invalid Response"
                    end
                   
               rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
            end
            return self
            end
      end
####
# Base holder class for parsed SecureCard response. If there was an error there will be an error string
# otherwise all values will be populated with the parsed payment response values.
###
          
    class XmlSecureCardResponse
        
            @@isError
            @@errorString
            @@errorCode
            @@merchantRef
            @@cardRef
            @@dateTime
            @@hash
            @@isError = false
            
            
            def  IsError()
              return @@isError
            end
        
            
            def  ErrorString()
               return @@errorString
            end
        
            
            def  ErrorCode()
              return @@errorCode
            end
        
            
            def  MerchantReference()
               return @@merchantRef
            end
        
            
            def  CardReference()
               return @@cardRef
            end
        
            
            def  DateTime()
               return @@dateTime
            end
        
           
            def  Hash()
                 return @@hash
            end
            
    end
        ####
        #  Holder class for parsed SecureCard registration response. 
        ####  
     class XmlSecureCardRegResponse < XmlSecureCardResponse
        
           def  XmlSecureCardRegResponse(responseXml)
            
                doc =  Nokogiri::XML(responseXml)
            begin 
                    if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                       
                       elsif doc.at("SECURECARDREGISTRATIONRESPONSE")
                    
                              doc.xpath('//SECURECARDREGISTRATIONRESPONSE').children.each do |node|
                              
                              if node.name.match(/MERCHANTREF/)
                                @@merchantRef = node.text
                              end
                              if node.name.match(/CARDREFERENCE/)
                                @@cardRef = node.text
                              end  
                              
                              if node.name.match(/DATETIME/)
                                @@dateTime = node.text
                              end
                              if node.name.match(/HASH/)
                                @@hash = node.text
                              end
                            end#end of the loop
                    
                       else
                         raise "Invalid Response"
                       end
                  
                  
            rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
            end
            return self
       end
    end
    
####
 #  Holder class for parsed SecureCard update response. 
####  

     class XmlSecureCardUpdResponse < XmlSecureCardResponse
        
            def  XmlSecureCardUpdResponse(responseXml)
             doc =  Nokogiri::XML(responseXml)
            begin 
                    if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                    
                       elsif doc.at("SECURECARDUPDATERESPONSE")
                    
                            doc.xpath('//SECURECARDUPDATERESPONSE').children.each do |node|
                            
                            if node.name.match(/MERCHANTREF/)
                                @@merchantRef = node.text
                              end
                              if node.name.match(/CARDREFERENCE/)
                                @@XmlSecureCardUpdResponse = node.text
                              end  
                              
                              if node.name.match(/DATETIME/)
                                @@dateTime = node.text
                              end
                              if node.name.match(/HASH/)
                                @@hash = node.text
                              end
                                      end#end of the loop
                    
                        else
                         raise "Invalid Response"
                        end
                   
               rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
            end
                return self
            end
      end
 ###
 #Holder class for parsed SecureCard removal response. 
 ###  
     class XmlSecureCardDelResponse < XmlSecureCardResponse
        
            def  XmlSecureCardDelResponse(responseXml)
                 doc =  Nokogiri::XML(responseXml)
            begin 
                    if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                       
                     elsif doc.at("SECURECARDREMOVALRESPONSE")
                        doc.xpath('//SECURECARDREMOVALRESPONSE').children.each do |node|
                        
                         if node.name.match(/MERCHANTREF/)
                            @@merchantRef = node.text
                          end
                          
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end#end of the loop
                    
                    else
                         raise "Invalid Response"
                    end
                   
               rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
               end
              return self
          end
        end
        
        ###
        #Holder class for parsed SecureCard search response. 
        ###  
       class XmlSecureCardSearchResponse < XmlSecureCardResponse
        
           @@merchantRef
           @@cardRef
           @@cardType
           @@expiry
           @@cardHolderName
           @@hash
            
            
            def  MerchantReference()
              return @@merchantRef
            end
        
            
            def  CardReference()
               return @@cardRef
            end
        
            
            def  CardType()
               return @@cardType
            end
        
           
            def  CardExpiry()
               return @@expiry
            end
        
           
            def  CardHolderName()
               return @@cardHolderName
            end
        
            
            def  Hash()
               return @@hash
            end
        
            def  XmlSecureCardSearchResponse(responseXml)
                 
                 doc =  Nokogiri::XML(responseXml)
            begin 
                    if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                    
                       elsif doc.at("SECURECARDSEARCHRESPONSE")
                       doc.xpath('//SECURECARDSEARCHRESPONSE').children do |xml|
                         
                          if node.name.match(/MERCHANTREF/)
                            @@merchantRef = node.text
                          end
                          
                          if node.name.match(/CARDREFERENCE/)
                            @@cardRef = node.text
                          end
                          if node.name.match(/CARDTYPE/)
                            @@cardType = node.text
                          end
                          if node.name.match(/CARDEXPIRY/)
                            @@expiry = node.text
                          end
                          if node.name.match(/CARDHOLDERNAME/)
                            @@cardHolderName = node.text
                          end
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end#end of the loop
                    
                    else
                         raise "Invalid Response"
                    end
                   
               rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
            end
                return self
            end
       end
        ### 
        #Base holder class for parsed Subscription response. If there was an error there will be an error string
        # otherwise all values will be populated with the parsed payment response values.
        ###  
        class XmlSubscriptionResponse
           @@isError
           @@errorString
           @@errorCode
           @@merchantRef
           @@dateTime
           @@hash
           @@isError = false
           
            def  IsError()
               return @@isError
            end
        
           
            def  ErrorString()
                return @@errorString
            end
            
        
          
            def  ErrorCode()
              return @@errorCode
            end
            
        
           
            def  MerchantReference()
               return @@merchantRef
            end   
            
        
            
            def  DateTime()
              return @@dateTime
            end
            
        
          
            def  Hash()
               return @@hash
            end
        end
        
          #Holder class for parsed Stored Subscription registration response. 
          
        class XmlStoredSubscriptionRegResponse < XmlSubscriptionResponse
        
            def  XmlStoredSubscriptionRegResponse(responseXml)
               
                doc =  Nokogiri::XML(responseXml)
            begin 
                  if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                   
                 
                   
                   elsif doc.at("ADDSTOREDSUBSCRIPTIONRESPONSE")
                       doc.xpath('//ADDSTOREDSUBSCRIPTIONRESPONSE').children.each do |node|
                          if node.name.match(/MERCHANTREF/)
                            @@merchantRef = node.text
                          end
                                      
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end#end of the loop
                    
                    else
                         raise "Invalid Response"
                    end
                   
               rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
               end
              return self
            end
        end
        
          #Holder class for parsed Stored Subscription update response. 
          
       class XmlStoredSubscriptionUpdResponse < XmlSubscriptionResponse
        
            def  XmlStoredSubscriptionUpdResponse(responseXml)
               doc =  Nokogiri::XML(responseXml)
            begin 
                   if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                       
                       elsif doc.at("UPDATESTOREDSUBSCRIPTIONRESPONSE")
                         
                         doc.xpath('//UPDATESTOREDSUBSCRIPTIONRESPONSE').children.each do |node|
                                    
                          if node.name.match(/MERCHANTREF/)
                            @@merchantRef = node.text
                          end
                          
                     
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end#end of the loop
                    
                    else
                         raise "Invalid Response"
                    end
                   
               rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
               end
               return self
            end
        end
        
          #Holder class for parsed Stored Subscription deletion response. 
          
        class XmlStoredSubscriptionDelResponse < XmlSubscriptionResponse
        
            def  XmlStoredSubscriptionDelResponse(responseXml)
            
              
                doc =  Nokogiri::XML(responseXml)
            begin 
                    if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                       
                       elsif doc.at("DELETESTOREDSUBSCRIPTIONRESPONSE")
                           doc.xpath('//DELETESTOREDSUBSCRIPTIONRESPONSE').children.each do |node|
                        
                          if node.name.match(/MERCHANTREF/)
                            @@merchantRef = node.text
                          end
                          
                     
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end#end of the loop
                    
                    else
                         raise "Invalid Response"
                    end
                   
               rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
           end
           return self
           end
        end
          #Holder class for parsed Subscription registration response. 
          
        class XmlSubscriptionRegResponse < XmlSubscriptionResponse
        
            def  XmlSubscriptionRegResponse(responseXml)
            
                
                doc =  Nokogiri::XML(responseXml)
            begin 
                    if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                       
                       elsif doc.at("ADDSUBSCRIPTIONRESPONSE")
                         doc.xpath('//ADDSUBSCRIPTIONRESPONSE').children.each do |node|
                    
                        
                          if node.name.match(/MERCHANTREF/)
                            @@merchantRef = node.text
                          end
                          
                     
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end#end of the loop
                    
                    else
                         raise "Invalid Response"
                    end
                             
            rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
            end
            return self
         end
        
        end
        
        
          #Holder class for parsed Subscription update response. 
          
        class XmlSubscriptionUpdResponse < XmlSubscriptionResponse
        
            def  XmlSubscriptionUpdResponse(responseXml)
            
               
                doc =  Nokogiri::XML(responseXml)
            begin 
                    if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                       
                       elsif doc.at("UPDATESUBSCRIPTIONRESPONSE")
                         doc.xpath('//UPDATESUBSCRIPTIONRESPONSE').children.each do |node|
                        
                          if node.name.match(/MERCHANTREF/)
                            @@merchantRef = node.text
                          end
                          
                     
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end#end of the loop
                    
                    else
                         raise "Invalid Response"
                    end
                   
               rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
           end
           return self
           end
        end
        
          #Holder class for parsed Subscription deletion response. 
         
        class XmlSubscriptionDelResponse < XmlSubscriptionResponse
        
            def  XmlSubscriptionDelResponse(responseXml)
            
                
                doc =  Nokogiri::XML(responseXml)
            begin 
                   if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                       
                       elsif doc.at("DELETESUBSCRIPTIONRESPONSE")
                    
                        doc.xpath('//DELETESUBSCRIPTIONRESPONSE').children.each do |node|
                          if node.name.match(/MERCHANTREF/)
                            @@merchantRef = node.text
                          end
                          
                     
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end#end of the loop
                    
                    else
                         raise "Invalid Response"
                    end
                   
               rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
            end
            return self
            end
        end
         #Holder class for parsed Subscription Payment response. 
          
        class XmlSubscriptionPaymentResponse
            @@isError
            @@errorString
            @@errorCode
            @@responseCode
            @@responseText
            @@approvalCode
            @@dateTime
            @@uniqueRef
            @@hash
            @@isError = false
            
            def  IsError()
            
                return @@isError
            end
            
           
            def  ErrorString()
            
                return @@errorString
            end
        
           
            def  ResponseCode()
            
                return @@responseCode
            end
            
           
            def  ResponseText()
            
                return @@responseText
            end
            
          
            def  ApprovalCode()
            
                return @@approvalCode
            end
            
           
            def  DateTime()
            
                return @@dateTime
            end
            
        
            def  UniqueRef()
            
                return @@uniqueRef
            end
            
        
            def  Hash()
            
                 return @@hash
            end
        
            def  XmlSubscriptionPaymentResponse(responseXml)
            
               
                doc =  Nokogiri::XML(responseXml)
           
                begin 
                     if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                                       
                       elsif doc.at("SUBSCRIPTIONPAYMENTRESPONSE")
                           doc.xpath('//SUBSCRIPTIONPAYMENTRESPONSE').children.each do |node|
                        
                          if node.name.match(/UNIQUEREF/)
                            @@uniqueRef = node.text
                          end
                          if node.name.match(/RESPONSECODE/)
                            @@responseCode = node.text
                          end  
                          if node.name.match(/RESPONSETEXT/)
                            @@responseText = node.text
                          end  
                          if node.name.match(/APPROVALCODE/)
                            @@approvalCode = node.text
                          end 
                          
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end#end of the loop
                    
                    else
                         raise "Invalid Response"
                    end
                   
               rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
           end
           return self
        end
    end
    
      #Holder class for parsed Unreferenced Refund response. 
      
    class XmlUnreferencedRefundResponse
    
        @@isError
        @@errorString
        @@errorCode
        @@responseCode
        @@responseText
        @@orderId
        @@dateTime
        @@uniqueRef
        @@hash
        @@isError = false
       
        
        def  IsError()
        
            return @@isError
        end
        
    
        def  ErrorString()
        
            return @@errorString
        end
    
        
        def  ResponseCode()
        
            return @@responseCode
        end
        
        
        def  ResponseText()
        
            return @@responseText
        end
        
       
        def  OrderId()
        
            return @@orderId
        end
        
        
        def  DateTime()
        
            return @@dateTime
        end
        
      
        def  UniqueRef()
        
            return @@uniqueRef
        end
        
      
        def  Hash()
        
            return @@hash
        end
    
        def  XmlUnreferencedRefundResponse(responseXml)
        
           
            doc =  Nokogiri::XML(responseXml)
       
            begin 
                if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                    
                       
                 elsif doc.at("UNREFERENCEDREFUNDRESPONSE")
                    
                       doc.xpath('//UNREFERENCEDREFUNDRESPONSE').children.each do |node|
                          if node.name.match(/UNIQUEREF/)
                            @@uniqueRef = node.text
                          end
                          if node.name.match(/RESPONSECODE/)
                            @@responseCode = node.text
                          end  
                          if node.name.match(/RESPONSETEXT/)
                            @@responseText = node.text
                          end  
                          if node.name.match(/APPROVALCODE/)
                            @@approvalCode = node.text
                          end 
                          
                          if node.name.match(/DATETIME/)
                             @@dateTime = node.text
                          end
                          
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end#end of the loop
                
                 else
                     raise "Invalid Response"
                 end
               
           rescue Exception => e
             @@isError = true
             @@errorString = e.message
           end
        return self
        end
    end
     #Holder class for parsed VoiceID response. 
      
    class XmlVoiceIDResponse
        @@isError
        @@errorString
        @@errorCode
        @@responseCode
        @@responseText
        @@orderId
        @@dateTime
        @@hash
        @@isError = false
        
        def  IsError()
        
            return @@isError
        end
        
       
        def  ErrorString()
        
            return @@errorString
        end
    
        
        def  ResponseCode()
        
            return @@responseCode
        end
        
       
        def  ResponseText()
        
            return @@responseText
        end
        
       
        def  OrderId()
        
            return @@orderId
        end
        
        
        def  DateTime()
        
            return @@dateTime
        end
        
        
        def  Hash()
        
            return @@hash
        end
    
        def  XmlVoiceIDResponse(responseXml)
        
         
            doc =  Nokogiri::XML(responseXml)
       
            begin 
             if doc.at("/ERROR")
                   @@isError = true
                   @@errorString = doc.at("/ERROR/ERRORSTRING").text
                   if doc.at("/ERROR/ERRORCODE")
                     @@errorCode = doc.at("/ERROR/ERRORCODE").text
                   end
                
                   
                   elsif doc.at("VOICEIDRESPONSE")
                
                    doc.xpath('//VOICEIDRESPONSE').children.each do |node|
                      
                      if node.name.match(/RESPONSECODE/)
                        @@responseCode = node.text
                      end  
                      if node.name.match(/RESPONSETEXT/)
                        @@responseText = node.text
                      end  
                      if node.name.match(/ORDERID/)
                        @@orderId = node.text
                      end 
                      
                      if node.name.match(/DATETIME/)
                        @@dateTime = node.text
                      end
                      
                      if node.name.match(/HASH/)
                        @@hash = node.text
                      end
                    end#end of the loop
                
                else
                     raise "Invalid Response"
                end
               
           rescue Exception => e
             @@isError = true
             @@errorString = e.message
           end
          return self    
        end
     end
     
     
    class XmlTransactionUpdateResponse

            @@isError = false
            @@errorString
            @@errorCode
            @@responseCode
            @@responseText
            @@approvalCode
            @@dateTime
            @@uniqueRef 
            @@hash
            @@orderId
            
            def  IsError()
              return @@isError
            end
            
            
            def  ErrorString()
              return @@errorString
            end
            def  ErrorCode()
              return @@errorCode
            end
        
            
            def  ResponseCode()
              return @@responseCode
            end
            
            
            def  ResponseText()
               return @@responseText
            end
            
            
            def  OrderId()
               return @@orderId
            end
            
            
            def  DateTime()
               return @@dateTime
            end
            
            
            def  UniqueRef()
             return @@uniqueRef
            end
            
            
            def  Hash()
              return @@hash
            end
        
            def  XmlTransactionUpdateResponse(responseXml)
            
                 doc =  Nokogiri::XML(responseXml)
            begin 
                    if doc.at("/ERROR")
                       @@isError = true
                       @@errorString = doc.at("/ERROR/ERRORSTRING").text
                       if doc.at("/ERROR/ERRORCODE")
                         @@errorCode = doc.at("/ERROR/ERRORCODE").text
                       end
                       
                    elsif doc.at("TRANSACTIONUPDATERESPONSE")
                    
                        doc.xpath('//TRANSACTIONUPDATERESPONSE').children.each do |node| 
                        
                          if node.name.match(/RESPONSECODE/)
                            @@responseCode = node.text
                          end  
                         
                          if node.name.match(/RESPONSETEXT/)
                            @@responseText = node.text
                          end  
                          if node.name.match(/UNIQUEREF/)
                            @@uniqueRef = node.text
                          end
                          if node.name.match(/<TERMINALID/)
                            @@orderId = node.text
                          end 
                          
                          if node.name.match(/DATETIME/)
                            @@dateTime = node.text
                          end
                          
                          if node.name.match(/HASH/)
                            @@hash = node.text
                          end
                        end   #end of the loop
                       else
                         raise "Invalid Response"
                    end
                   
            rescue Exception => e
                 @@isError = true
                 @@errorString = e.message
                
            end
            return self
        end
  end
      #For backward compatibility with older class names.
      
    class XmlStandardRequest < XmlAuthRequest 
    end
    class XmlStandardResponse < XmlAuthResponse 
    end
    # XML Functions - For internal use.
  end
end
