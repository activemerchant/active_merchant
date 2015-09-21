require 'nokogiri'
module Velocity
  class VelocityXmlCreator

    def initialize(application_profile_id,merchant_profile_id)
      @application_profile_id = application_profile_id
      @merchant_profile_id = merchant_profile_id
    end

    def application_profile_id
      @application_profile_id
    end
    
    def merchant_profile_id
      @merchant_profile_id
    end
    
   # Create verify xml as per the api format .
   # "params" is collection key-values, in this "params" holds CardData, AVSData, Amount. 
   # It returns xml format in string.

    def verify_xml(params)
        Nokogiri::XML::Builder.new do |xml|
          xml.AuthorizeTransaction('xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance',
           'xmlns' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Rest',
           'i:type' =>"AuthorizeTransaction" ) {
            xml.ApplicationProfileId application_profile_id #'14560'
            xml.MerchantProfileId merchant_profile_id #'PrestaShop Global HC'
            xml.Transaction('xmlns:ns1' => "http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard",
             'i:type' => "ns1:BankcardTransaction" ){
              xml['ns1'].TenderData{
                xml['ns1'].CardData{
                  xml['ns1'].CardType params[:CardType]
                  xml['ns1'].CardholderName params[:CardholderName]
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
                if params[:Amount] != ''
                  xml['ns8'].Amount('xmlns:ns8' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:Amount])
                else
                  xml['ns8'].Amount('xmlns:ns8' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('0.00')
                end
                xml['ns9'].CurrencyCode('xmlns:ns9' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('USD')
                xml['ns10'].TransactionDateTime('xmlns:ns10' =>
                                                "http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('2014-04-03T13:50:16') 
                xml['ns1'].AccountType 'NotSet'
                xml['ns1'].CustomerPresent 'Present'
                xml['ns1'].EmployeeId '11'
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

  # Create Authorize xml as per the api format .
  # "params" is collection key-values, in this "params" holds CardData, AVSData, Amount, P2PETransactionData,PaymentAccountDataToken. 
  # It returns xml format in string.

    def authorize_xml(params)  
        Nokogiri::XML::Builder.new do |xml|
          xml.AuthorizeTransaction('xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance', 
                        'xmlns' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Rest',
                        'i:type' =>"AuthorizeTransaction" ) {
            xml.ApplicationProfileId application_profile_id
            xml.MerchantProfileId merchant_profile_id
            xml.Transaction('xmlns:ns1' => "http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard",
            'i:type' => "ns1:BankcardTransaction" ){
              xml['ns1'].TenderData{
              if !params[:SwipeStatus].nil? && !params[:IdentificationInformation].nil? && !params[:SecurePaymentAccountData].nil? && !params[:EncryptionKeyId].nil?
                #p "Swipe card..maga..."
                 xml['ns5'].SecurePaymentAccountData('xmlns:ns5' =>
                                "http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:SecurePaymentAccountData])
                 xml['ns6'].EncryptionKeyId('xmlns:ns6' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:EncryptionKeyId])
                 xml['ns7'].SwipeStatus('xmlns:ns7' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:SwipeStatus])
                 xml['ns1'].CardSecurityData{
                  xml['ns1'].IdentificationInformation params[:IdentificationInformation]
                 }
                 xml['ns1'].CardData('i:nil' =>"true")
              elsif !params[:SecurePaymentAccountData].nil? && !params[:EncryptionKeyId].nil? 
                 xml['ns5'].SecurePaymentAccountData('xmlns:ns5' =>
                               "http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:SecurePaymentAccountData])
                 xml['ns6'].EncryptionKeyId('xmlns:ns6' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:EncryptionKeyId])
                 xml['ns7'].SwipeStatus('xmlns:ns7' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true") 
                 xml['ns1'].CardSecurityData{
                  xml['ns1'].IdentificationInformation('i:nil' =>"true")
                 }
                 xml['ns1'].CardData('i:nil' =>"true")
                 xml['ns1'].EcommerceSecurityData('i:nil' =>"true")   
              elsif !params[:PaymentAccountDataToken].nil?
                xml['ns4'].PaymentAccountDataToken('xmlns:ns4' =>
                                "http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:PaymentAccountDataToken])
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
                }
                xml['ns1'].EcommerceSecurityData('i:nil' =>"true")             
              end
              }
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
                if params[:Amount] != ''
                  xml['ns8'].Amount('xmlns:ns8' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:Amount])
                else
                  xml['ns8'].Amount('xmlns:ns8' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('0.00')
                end
                xml['ns9'].CurrencyCode('xmlns:ns9' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('USD') 
                xml['ns10'].TransactionDateTime('xmlns:ns10' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('2013-04-03T13:50:16')
                xml['ns11'].CampaignId('xmlns:ns11' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true")
                xml['ns12'].Reference('xmlns:ns12' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('xyt')
                xml['ns1'].AccountType 'NotSet'
                xml['ns1'].ApprovalCode('i:nil' =>"true")
                xml['ns1'].CashBackAmount '0.0'
                xml['ns1'].CustomerPresent 'Present'
                xml['ns1'].EmployeeId '11'
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
            }
          }     
        end.to_xml 
    end

  # Create AuthorizeCapture xml as per the api format .
  # "params" is collection key-values, in this "params" holds CardData, AVSData, Amount, P2PETransactionData,PaymentAccountDataToken. 
  # It returns xml format in string.

    def purchase_xml(params)
        Nokogiri::XML::Builder.new do |xml|
          xml.AuthorizeAndCaptureTransaction('xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance', 
                            'xmlns' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Rest',
                            'i:type' =>"AuthorizeAndCaptureTransaction" ) {
            xml.ApplicationProfileId application_profile_id
            xml.MerchantProfileId merchant_profile_id 
            xml.Transaction('xmlns:ns1' => "http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard", 
                            'i:type' => "ns1:BankcardTransaction" ){
              xml['ns1'].TenderData{
              if !params[:SwipeStatus].nil? && !params[:IdentificationInformation].nil? && !params[:SecurePaymentAccountData].nil? && !params[:EncryptionKeyId].nil?
                #p "Swipe card..maga..."
                 xml['ns5'].SecurePaymentAccountData('xmlns:ns5' =>
                                    "http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:SecurePaymentAccountData])
                 xml['ns6'].EncryptionKeyId('xmlns:ns6' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:EncryptionKeyId])
                 xml['ns7'].SwipeStatus('xmlns:ns7' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:SwipeStatus])
                 xml['ns1'].CardSecurityData{
                  xml['ns1'].IdentificationInformation params[:IdentificationInformation]
                 }
                 xml['ns1'].CardData('i:nil' =>"true")
              elsif !params[:SecurePaymentAccountData].nil? && !params[:EncryptionKeyId].nil? 
                #p "Swipe card..Dukp..."
                 xml['ns5'].SecurePaymentAccountData('xmlns:ns5' =>
                                      "http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:SecurePaymentAccountData])
                 xml['ns6'].EncryptionKeyId('xmlns:ns6' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:EncryptionKeyId])
                 xml['ns7'].SwipeStatus('xmlns:ns7' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true") 
                 xml['ns1'].CardSecurityData{
                  xml['ns1'].IdentificationInformation('i:nil' =>"true")
                 }
                 xml['ns1'].CardData('i:nil' =>"true")
                 xml['ns1'].EcommerceSecurityData('i:nil' =>"true")   
              elsif !params[:PaymentAccountDataToken].nil?
                #p "PaymentAccountDataToken..........."
                xml['ns4'].PaymentAccountDataToken('xmlns:ns4' =>
                                        "http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:PaymentAccountDataToken])
                xml['ns5'].SecurePaymentAccountData('xmlns:ns5' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true")
                xml['ns6'].EncryptionKeyId('xmlns:ns6' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true")
                xml['ns7'].SwipeStatus('xmlns:ns7' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true") 
                xml['ns1'].CardData('i:nil' =>"true")
                xml['ns1'].EcommerceSecurityData('i:nil' =>"true")           
              else 
                #p "without token...."
                xml['ns4'].PaymentAccountDataToken('xmlns:ns4' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions", 'i:nil' =>"true")
                xml['ns5'].SecurePaymentAccountData('xmlns:ns5' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true")
                xml['ns6'].EncryptionKeyId('xmlns:ns6' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true")
                xml['ns7'].SwipeStatus('xmlns:ns7' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true")
                xml['ns1'].CardData{
                  xml['ns1'].CardType params[:CardType]    
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
                }
                xml['ns1'].EcommerceSecurityData('i:nil' =>"true")             
              end
              }
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
                if params[:Amount] != ''
                  xml['ns8'].Amount('xmlns:ns8' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text(params[:Amount])
                else
                  xml['ns8'].Amount('xmlns:ns8' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('0.00')
                end
                xml['ns9'].CurrencyCode('xmlns:ns9' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('USD') 
                xml['ns10'].TransactionDateTime('xmlns:ns10' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('2013-04-03T13:50:16')
                xml['ns11'].CampaignId('xmlns:ns11' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions",'i:nil' =>"true")
                xml['ns12'].Reference('xmlns:ns12' =>"http://schemas.ipcommerce.com/CWS/v2.0/Transactions").text('xyt')
                xml['ns1'].AccountType 'NotSet'
                xml['ns1'].ApprovalCode('i:nil' =>"true")
                xml['ns1'].CashBackAmount '0.0'
                xml['ns1'].CustomerPresent 'Present'
                xml['ns1'].EmployeeId '11'
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
            }
          }     
        end.to_xml  
    end

  # Create Capture xml as per the api format .
  # "params" is collection key-values, in this "params" holds Amount, TransactionId. 
  # It returns xml format in string.

    def capture_xml(params)
        Nokogiri::XML::Builder.new do |xml|
          xml.ChangeTransaction('xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance',
           'xmlns' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Rest',
            'i:type' =>"Capture" ) {
            xml.ApplicationProfileId application_profile_id #'14644'
              xml.DifferenceData('xmlns:d2p1' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions',
                  'xmlns:d2p2' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard', 
                  'xmlns:d2p3' => 'http://schemas.ipcommerce.com/CWS/v2.0/TransactionProcessing',
                  'i:type' => "d2p2:BankcardCapture"){
              xml['d2p1'].TransactionId params[:TransactionId]#'760CBDD65E4642E49A3CD2E2F3257A10'
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

  # Create Undo xml as per the api format .
  # "params" is collection key-values, in this "params" hold TransactionId. 
  # It returns xml format in string.

    def void_xml(params)
        Nokogiri::XML::Builder.new do |xml|
          xml.Undo('xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance', 
              'xmlns' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Rest', 'i:type' =>"Undo" ) {
             xml.ApplicationProfileId application_profile_id 
             xml.BatchIds('xmlns:d2p1' => 'http://schemas.microsoft.com/2003/10/Serialization/Arrays','i:nil' => "true")
             xml.DifferenceData('xmlns:d2p1' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions','i:nil' => "true")
             xml.MerchantProfileId merchant_profile_id 
             xml.TransactionId params[:TransactionId] 
          }
        end.to_xml    
    end

  # Create ReturnById xml as per the api format .
  # "params" is collection key-values, in this "params" holds Amount, TransactionId. 
  # It returns xml format in string.

    def refund_xml(params)
        Nokogiri::XML::Builder.new do |xml|
          xml.ReturnById('xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance',
           'xmlns' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Rest', 'i:type' =>"ReturnById" ) {
            xml.ApplicationProfileId application_profile_id 
            xml.BatchIds('xmlns:d2p1' => 'http://schemas.microsoft.com/2003/10/Serialization/Arrays', 'i:nil' => "true")
            xml.DifferenceData('xmlns:ns1' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions/Bankcard', 'i:type' => "ns1:BankcardReturn"){
              xml['ns2'].TransactionId params[:TransactionId] ,'xmlns:ns2' => 'http://schemas.ipcommerce.com/CWS/v2.0/Transactions'
              if params[:Amount] != ''
                 xml['ns1'].Amount params[:Amount]
              else
                 xml['ns1'].Amount '0.00'
              end
            }
            xml.MerchantProfileId merchant_profile_id
          } 
        end.to_xml
    end
  

  end
end
