require 'active_merchant/billing/gateways/worldnet/worldnet_api.rb'
require 'test_helper'


module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
        class WorldnetGateway < Gateway
         
          #self.test_url = 'https://example.com/test'
          #self.live_url = 'https://example.com/live'
    
          #self.supported_countries = ['US']
          self.default_currency = 'USD'
          self.supported_cardtypes = [:visa, :master, :american_express, :discover]
    
          #self.homepage_url = 'http://www.example.net/'
          #self.display_name = 'New Gateway'
    
          STANDARD_ERROR_CODE_MAPPING = {}
          
          attr_accessor :type,:orderId,:refUniq,:terminalid,:amount,:sharedsecret,:refundamount,:cardnumber,:expiryyear,:expirymonth,:expirydate,:cardType
          
            
          def initialize(options={})
               
               @@terminalid = options[:terminalid].to_s
               @@sharedsecret = options[:sharedsecret].to_s
              super
          end
         
          def purchase(money, creditcard, options={})
               post = {}
               @@description = options[:description]
               @@orderId = options[:order_id]
               @@amount =  money.to_s 
               @@cardnumber = creditcard.number
               @@cardType = "#{creditcard.brand}".upcase
               @@cardHoldername = creditcard.name
               @@dttime = creditcard.expiry_date.expiration
               @@expiryyear = "#{@@dttime.year}".to_s
               @@expirymonth = "#{@@dttime.month}".to_s
               commit('sale', post)
          end
          
         
          
          def authorize(money, creditcard, options={})
              
               post = {}
               @@description = options[:description]
               @@orderId = options[:order_id]
               @@amount =  money.to_s 
               @@cardnumber = creditcard.number
               @@cardType = "#{creditcard.brand}".upcase
               @@cardHoldername = creditcard.name
               @@dttime = creditcard.expiry_date.expiration
               @@expiryyear = "#{@@dttime.year}".to_s
               @@expirymonth = "#{@@dttime.month}".to_s
              
               commit('authonly', post)
          end
            
         def capture(money, authorization, options={})
              post = {}
              commit('capture', post)
         end
         
          def refund(money, authorization, options={})
              post = {}
              @@refundamount = money.to_s
              commit('refund', post)
          end
          def void(money, authorization, options={})
              post = {}
              commit('void', post)
          end
          
          def url(testAccount, gateway)
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
                 @serverUrl =  @serverUrl + '/merchant/xmlpayment'
            return @serverUrl
          end 
          

           def carddate()
                 @@expiryyear = "#{@@expiryyear}"[2,4]
               
               if @@expirymonth.length == 1
                    @@expirymonth = "0" + @@expirymonth
               else
                  @@expirymonth
               end
                 @@expirydate = "#{@@expirymonth}#{@@expiryyear}"
             
           return @@expirydate
         end
         
          def parseXML(data)
              response = {}
      
              xml = REXML::Document.new(data)
              root = REXML::XPath.first(xml, "*")
      
              if root.nil?
                response[:message] = data.to_s.strip
              else
                  root.elements.to_a.each do |node|
                  response[node.name.underscore.to_sym] = node.text
                end
              end
      
              response
          end
            
           
           
           def commit(action, options)
                @@type = action
                url = url(true, 'worldnet')
                worldnetresponse = parseXML(ssl_post(url, post_data()))
                
                @@refUniq = worldnetresponse[:uniqueref]
                Response.new(
                          success_from(worldnetresponse),
                          message_from(worldnetresponse), 
                          worldnetresponse,
                          :authorization => authorization_from(worldnetresponse)
                           )
           end
           
          def GetRequestHash(plainString)       
              digest = Digest::MD5.hexdigest(plainString)
             return digest
          end
          
          #Verify Hash Value If generated hash value does not match with response hash value abort the execution
           
          def verifyHash(hashresponse)
               @@datetime = hashresponse[:datetime]
               @@responsecode = hashresponse[:responsecode]
               @@responsetext = hashresponse[:responsetext]
               
               if hashresponse[:bankreponsecode]!=nil
                    @@bankResponseCode = hashresponse[:bankreponsecode]
               else 
                    @@bankResponseCode = ""
               end
               case @@type 
                 when 'sale' 
                      @@hash = GetRequestHash(@@terminalid + @@refUniq + @@amount + @@datetime + @@responsecode + @@responsetext + @@bankResponseCode + @@sharedsecret)
                 when 'authonly' 
                      @@hash = GetRequestHash(@@terminalid + @@refUniq + @@amount + @@datetime + @@responsecode + @@responsetext + @@bankResponseCode + @@sharedsecret)
                 when 'capture'
                      @@hash = GetRequestHash(@@responsecode + @@responsetext + @@refUniq + @@datetime + @@sharedsecret)
                 when 'refund'
                      @@hash = GetRequestHash(@@terminalid + @@refUniq + @@refundamount + @@datetime + @@responsecode + @@responsetext + @@sharedsecret) 
                 when 'void'
                      @@hash = GetRequestHash(@@terminalid + @@refUniq + @@amount + @@datetime + @@responsecode + @@responsetext + @@sharedsecret)     
                 
              end
          return @@hash
          end
            
          
           def authorization_from(response)
              @@hashvalue = verifyHash(response)
              
              if @@hashvalue == response[:hash]
                  return response[:uniqueref]
              else 
               abort("ERROR: HASH VALUE DOES NOT MATCH")    
              end 
              
              
              
                  
          end

          def success_from(response)
            case response[:responsecode]
            when "A"
              true
            else
              false
            end
          end

          def message_from(response)
                response[:responsetext]
          end
          
                  
          
          def post_data()
           
             if @@type == 'sale' || @@type == 'authonly' 
                  @@CardExpiry = carddate()
                  authrequest = XmlAuthRequest.new              
                  authrequest.XmlAuthRequest(@@terminalid,@@orderId,"EUR",@@amount,@@cardnumber,@@cardType)
                  if @@type == 'authonly'
                     authrequest.SetAutoReady("N")
                  end
                  authrequest.SetDescription(@@description)
                  authrequest.SetNonSecureCardCardInfo(@@CardExpiry, @@cardHoldername)
                  authrequest.SetHash(@@sharedsecret) 
                  worldnetAuthrequest = authrequest.GenerateXml()
                   
                    
            elsif @@type == 'capture'
                 
                  transUpdaterequest = XmlTransactionUpdateRequest.new
                  transUpdaterequest.XmlTransactionUpdateRequest(@@terminalid,@@orderId,"CardHolder Payment","PENDING","READY")
                  transUpdaterequest.SetUniqueRef(@@refUniq)
                  transUpdaterequest.SetAuthCode("475318")
                  transUpdaterequest.SetHash(@@sharedsecret) 
                  transUpdaterequest = transUpdaterequest.GenerateXml()
                  
                  transUpdaterequest
            else 
                 refundrequest = XmlRefundRequest.new
                 if @@type == 'refund'
                  refundrequest.XmlRefundRequest(@@terminalid,@@orderId,@@refundamount,"CardHolder Payment","Reason")
                 else
                  refundrequest.XmlRefundRequest(@@terminalid,@@orderId,@@amount,"CardHolder Payment","Reason") 
                 end
                 refundrequest.SetUniqueRef(@@refUniq)
                 refundrequest.SetHash(@@sharedsecret)
                 worldnetRefundrequest = refundrequest.GenerateXml()
                 
                 worldnetRefundrequest
             end
          end
          
          
    
          def error_code_from(response)
            unless success_from(response)
              # TODO: lookup error code for this response
            end
          end
          
        end
  end   
end
