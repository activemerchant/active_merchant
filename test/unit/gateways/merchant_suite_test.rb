require 'test_helper'

class MerchantSuiteTest < Test::Unit::TestCase
  def setup
    @gateway = MerchantSuiteGateway.new(username: 'username', password: 'password', membershipid: 'mid')

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '354901', response.authorization
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '354902', response.authorization
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to merchantsuite-uat.premier.com.au:443...
      opened
      starting SSL for merchantsuite-uat.premier.com.au:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /api/v3/txns HTTP/1.1\r\nContent-Type: application/json; charset=utf-8\r\nAuthorization: YXBpLm1zNzQ5MzYwLml3fE1TNzQ5MzYwOkhBWEpiYjYzPWptMDN+In4=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: merchantsuite-uat.premier.com.au\r\nContent-Length: 814\r\n\r\n"
      <- "{\"TxnReq\":{\"Action\":\"payment\",\"Amount\":1,\"Currency\":\"AUD\",\"CardDetails\":{\"CardHolderName\":\"Longbob Longsen\",\"CardNumber\":\"4987654321098769\",\"ExpiryDate\":\"9900\",\"CVN\":\"123\"},\"Customer\":{\"ContactDetails\":{\"EmailAddress\":\"john.smith@test.com\",\"FaxNumber\":\"\",\"HomePhoneNumber\":\"\",\"MobilePhoneNumber\":\"\",\"WorkPhoneNumber\":\"\"},\"PersonalDetails\":{\"DateOfBirth\":\"\",\"FirstName\":\"John\",\"LastName\":\"Smith\",\"MiddleName\":\"\",\"Salutation\":\"Mr\"},\"CustomerNumber\":\"\",\"ExistingCustomer\":false,\"Address\":{\"AddressLine1\":\"456 My Street\",\"AddressLine2\":\"Apt 1\",\"AddressLine3\":null,\"City\":\"Ottawa\",\"CountryCode\":\"CA\",\"PostCode\":\"K1C2N6\",\"State\":\"ON\"}},\"Reference1\":\"134\",\"InternalNote\":\"\",\"PaymentReason\":\"\",\"TokenisationMode\":0,\"SettlementDate\":\"\",\"Source\":\"\",\"StoreCard\":false,\"SubType\":\"single\",\"TestMode\":true,\"Type\":\"cardpresent\"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: private,no-store,no-cache,must-revalidate,proxy-revalidate\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Set-Cookie: api_sessionid=bgin45jxtwdckydpunzvjqhb; path=/; secure; HttpOnly\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Access-Control-Allow-Headers: Content-Type\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
      -> "Access-Control-Max-Age: 1728000\r\n"
      -> "Date: Thu, 05 Dec 2019 14:44:18 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Content-Length: 1347\r\n"
      -> "Set-Cookie: BIGipServeruat_web_ms_green_443_pool=!ZwqNUCaHd7IHX886xuszhet4e+eMzBkyUGbe87OVwwKcM809WgYfIJJjGeYMjkwWT2npsdXKOaX1ksE=;Path=/;Version=1;Secure;Httponly\r\n"
      -> "Strict-Transport-Security: max-age=15552000; includeSubDomains\r\n"
      -> "Set-Cookie: TS01ced9c1=0183fc8d4281e79ed2f69de4c9562e36e85c67202df89bbce9eb25124daacf6a200a73b3855b232aadda534765a0d21da61ed94e0126486ab16c2e8fd5408d33849b74f04f6eb55ec1291569603701e8af97b613da; Path=/; Secure; HTTPOnly\r\n"
      -> "\r\n"
      reading 1347 bytes...
      -> "{\"APIResponse\":{\"ResponseCode\":0,\"ResponseText\":\"Success\"},\"TxnResp\":{\"Action\":\"payment\",\"Agent\":null,\"Amount\":1,\"AmountOriginal\":1,\"AmountSurcharge\":0,\"Authentication3DSResponse\":null,\"AuthoriseID\":null,\"BankAccountDetails\":null,\"BankResponseCode\":null,\"CVNResult\":{\"CVNResultCode\":null},\"CardDetails\":{\"CardHolderName\":\"Longbob Longsen\",\"Category\":\"ATM\",\"ExpiryDate\":\"9900\",\"Issuer\":null,\"IssuerCountryCode\":\"BGR\",\"Localisation\":\"international\",\"MaskedCardNumber\":\"498765...769\",\"SubType\":\"debit\"},\"CardType\":\"VC\",\"Currency\":null,\"EmailAddress\":null,\"FraudScreeningResponse\":{\"ReDResponse\":null,\"ResponseCode\":\"\",\"ResponseMessage\":\"\",\"TxnRejected\":false},\"InternalNote\":\"\",\"Is3DS\":false,\"IsCVNPresent\":true,\"IsTestTxn\":true,\"MembershipID\":\"MS749360\",\"OriginalTxnNumber\":null,\"PaymentReason\":\"\",\"ProcessedDateTime\":\"2019-12-06T01:44:17.2870000\",\"RRN\":null,\"ReceiptNumber\":\"99142584901\",\"Reference1\":\"134\",\"Reference2\":null,\"Reference3\":null,\"ResponseCode\":\"PT_V2\",\"ResponseText\":\"Payments are not supported by this merchant facility\",\"SettlementDate\":null,\"Source\":\"api\",\"StatementDescriptor\":{\"AddressLine1\":null,\"AddressLine2\":null,\"City\":null,\"CompanyName\":null,\"CountryCode\":null,\"MerchantName\":null,\"PhoneNumber\":null,\"PostCode\":null,\"State\":null},\"StoreCard\":false,\"SubType\":\"single\",\"Token\":null,\"TxnNumber\":\"354901\",\"Type\":\"cardpresent\"}}"
      read 1347 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to merchantsuite-uat.premier.com.au:443...
      opened
      starting SSL for merchantsuite-uat.premier.com.au:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /api/v3/txns HTTP/1.1\r\nContent-Type: application/json; charset=utf-8\r\nAuthorization: [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: merchantsuite-uat.premier.com.au\r\nContent-Length: 814\r\n\r\n"
      <- "{\"TxnReq\":{\"Action\":\"payment\",\"Amount\":1,\"Currency\":\"AUD\",\"CardDetails\":{\"CardHolderName\":\"Longbob Longsen\",\"CardNumber\":\"[FILTERED]\",\"ExpiryDate\":\"9900\",\"CVN\":\"[FILTERED]\"},\"Customer\":{\"ContactDetails\":{\"EmailAddress\":\"john.smith@test.com\",\"FaxNumber\":\"\",\"HomePhoneNumber\":\"\",\"MobilePhoneNumber\":\"\",\"WorkPhoneNumber\":\"\"},\"PersonalDetails\":{\"DateOfBirth\":\"\",\"FirstName\":\"John\",\"LastName\":\"Smith\",\"MiddleName\":\"\",\"Salutation\":\"Mr\"},\"CustomerNumber\":\"\",\"ExistingCustomer\":false,\"Address\":{\"AddressLine1\":\"456 My Street\",\"AddressLine2\":\"Apt 1\",\"AddressLine3\":null,\"City\":\"Ottawa\",\"CountryCode\":\"CA\",\"PostCode\":\"K1C2N6\",\"State\":\"ON\"}},\"Reference1\":\"134\",\"InternalNote\":\"\",\"PaymentReason\":\"\",\"TokenisationMode\":0,\"SettlementDate\":\"\",\"Source\":\"\",\"StoreCard\":false,\"SubType\":\"single\",\"TestMode\":true,\"Type\":\"cardpresent\"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: private,no-store,no-cache,must-revalidate,proxy-revalidate\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Set-Cookie: api_sessionid=bgin45jxtwdckydpunzvjqhb; path=/; secure; HttpOnly\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Access-Control-Allow-Headers: Content-Type\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
      -> "Access-Control-Max-Age: 1728000\r\n"
      -> "Date: Thu, 05 Dec 2019 14:44:18 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Content-Length: 1347\r\n"
      -> "Set-Cookie: BIGipServeruat_web_ms_green_443_pool=!ZwqNUCaHd7IHX886xuszhet4e+eMzBkyUGbe87OVwwKcM809WgYfIJJjGeYMjkwWT2npsdXKOaX1ksE=;Path=/;Version=1;Secure;Httponly\r\n"
      -> "Strict-Transport-Security: max-age=15552000; includeSubDomains\r\n"
      -> "Set-Cookie: TS01ced9c1=0183fc8d4281e79ed2f69de4c9562e36e85c67202df89bbce9eb25124daacf6a200a73b3855b232aadda534765a0d21da61ed94e0126486ab16c2e8fd5408d33849b74f04f6eb55ec1291569603701e8af97b613da; Path=/; Secure; HTTPOnly\r\n"
      -> "\r\n"
      reading 1347 bytes...
      -> "{\"APIResponse\":{\"ResponseCode\":0,\"ResponseText\":\"Success\"},\"TxnResp\":{\"Action\":\"payment\",\"Agent\":null,\"Amount\":1,\"AmountOriginal\":1,\"AmountSurcharge\":0,\"Authentication3DSResponse\":null,\"AuthoriseID\":null,\"BankAccountDetails\":null,\"BankResponseCode\":null,\"CVNResult\":{\"CVNResultCode\":null},\"CardDetails\":{\"CardHolderName\":\"Longbob Longsen\",\"Category\":\"ATM\",\"ExpiryDate\":\"9900\",\"Issuer\":null,\"IssuerCountryCode\":\"BGR\",\"Localisation\":\"international\",\"MaskedCardNumber\":\"498765...769\",\"SubType\":\"debit\"},\"CardType\":\"VC\",\"Currency\":null,\"EmailAddress\":null,\"FraudScreeningResponse\":{\"ReDResponse\":null,\"ResponseCode\":\"\",\"ResponseMessage\":\"\",\"TxnRejected\":false},\"InternalNote\":\"\",\"Is3DS\":false,\"IsCVNPresent\":true,\"IsTestTxn\":true,\"MembershipID\":\"MS749360\",\"OriginalTxnNumber\":null,\"PaymentReason\":\"\",\"ProcessedDateTime\":\"2019-12-06T01:44:17.2870000\",\"RRN\":null,\"ReceiptNumber\":\"99142584901\",\"Reference1\":\"134\",\"Reference2\":null,\"Reference3\":null,\"ResponseCode\":\"PT_V2\",\"ResponseText\":\"Payments are not supported by this merchant facility\",\"SettlementDate\":null,\"Source\":\"api\",\"StatementDescriptor\":{\"AddressLine1\":null,\"AddressLine2\":null,\"City\":null,\"CompanyName\":null,\"CountryCode\":null,\"MerchantName\":null,\"PhoneNumber\":null,\"PostCode\":null,\"State\":null},\"StoreCard\":false,\"SubType\":\"single\",\"Token\":null,\"TxnNumber\":\"354901\",\"Type\":\"cardpresent\"}}"
      read 1347 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<-eos
    {
      "APIResponse": {
          "ResponseCode": 0,
          "ResponseText": "Success"
      },
      "TxnResp": {
          "Action": "payment",
          "Agent": null,
          "Amount": 1,
          "AmountOriginal": 1,
          "AmountSurcharge": 0,
          "Authentication3DSResponse": null,
          "AuthoriseID": null,
          "BankAccountDetails": null,
          "BankResponseCode": null,
          "CVNResult": {
              "CVNResultCode": null
          },
          "CardDetails": {
              "CardHolderName": "Longbob Longsen",
              "Category": "ATM",
              "ExpiryDate": "9900",
              "Issuer": null,
              "IssuerCountryCode": "BGR",
              "Localisation": "international",
              "MaskedCardNumber": "498765...769",
              "SubType": "debit"
          },
          "CardType": "VC",
          "Currency": null,
          "EmailAddress": null,
          "FraudScreeningResponse": {
              "ReDResponse": null,
              "ResponseCode": "",
              "ResponseMessage": "",
              "TxnRejected": false
          },
          "InternalNote": "",
          "Is3DS": false,
          "IsCVNPresent": true,
          "IsTestTxn": true,
          "MembershipID": "MS749360",
          "OriginalTxnNumber": null,
          "PaymentReason": "",
          "ProcessedDateTime": "2019-12-06T01:44:17.2870000",
          "RRN": null,
          "ReceiptNumber": "99142584901",
          "Reference1": "134",
          "Reference2": null,
          "Reference3": null,
          "ResponseCode": "PT_V2",
          "ResponseText": "Payments are not supported by this merchant facility",
          "SettlementDate": null,
          "Source": "api",
          "StatementDescriptor": {
              "AddressLine1": null,
              "AddressLine2": null,
              "City": null,
              "CompanyName": null,
              "CountryCode": null,
              "MerchantName": null,
              "PhoneNumber": null,
              "PostCode": null,
              "State": null
          },
          "StoreCard": false,
          "SubType": "single",
          "Token": null,
          "TxnNumber": "354901",
          "Type": "cardpresent"
        }
      }
    eos
  end

  def successful_authorize_response
    <<-EOS
      {
        "APIResponse": {
            "ResponseCode": 0,
            "ResponseText": "Success"
        },
        "TxnResp": {
            "Action": "preauth",
            "Agent": null,
            "Amount": 1,
            "AmountOriginal": 1,
            "AmountSurcharge": 0,
            "Authentication3DSResponse": null,
            "AuthoriseID": null,
            "BankAccountDetails": null,
            "BankResponseCode": null,
            "CVNResult": {
                "CVNResultCode": null
            },
            "CardDetails": {
                "CardHolderName": "Longbob Longsen",
                "Category": "ATM",
                "ExpiryDate": "9900",
                "Issuer": null,
                "IssuerCountryCode": "BGR",
                "Localisation": "international",
                "MaskedCardNumber": "498765...769",
                "SubType": "debit"
            },
            "CardType": "VC",
            "Currency": null,
            "EmailAddress": null,
            "FraudScreeningResponse": {
                "ReDResponse": null,
                "ResponseCode": "",
                "ResponseMessage": "",
                "TxnRejected": false
            },
            "InternalNote": "",
            "Is3DS": false,
            "IsCVNPresent": true,
            "IsTestTxn": true,
            "MembershipID": "MS749360",
            "OriginalTxnNumber": null,
            "PaymentReason": "",
            "ProcessedDateTime": "2019-12-06T02:15:57.8800000",
            "RRN": null,
            "ReceiptNumber": "99143174902",
            "Reference1": "134",
            "Reference2": null,
            "Reference3": null,
            "ResponseCode": "PT_V2",
            "ResponseText": "Preauths are not supported by this merchant facility",
            "SettlementDate": null,
            "Source": "api",
            "StatementDescriptor": {
                "AddressLine1": null,
                "AddressLine2": null,
                "City": null,
                "CompanyName": null,
                "CountryCode": null,
                "MerchantName": null,
                "PhoneNumber": null,
                "PostCode": null,
                "State": null
            },
            "StoreCard": false,
            "SubType": "single",
            "Token": null,
            "TxnNumber": "354902",
            "Type": "cardpresent"
        }
    }
    EOS
  end
end
