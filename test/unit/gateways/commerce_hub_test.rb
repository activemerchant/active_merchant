require 'test_helper'

class CommerceHubTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CommerceHubGateway.new(api_key: 'login', api_secret: 'password', merchant_id: '12345', terminal_id: '0001')

    @amount = 1204
    @credit_card = credit_card('4005550000000019', month: '02', year: '2035', verification_value: '123')
    @declined_card = credit_card('4000300011112220', month: '02', year: '2035', verification_value: '123')
    @options = {}
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['transactionDetails']['captureFlag'], true
      assert_equal request['merchantDetails']['terminalId'], @gateway.options[:terminal_id]
      assert_equal request['merchantDetails']['merchantId'], @gateway.options[:merchant_id]
      assert_equal request['amount']['total'], (@amount / 100.0).to_f
      assert_equal request['source']['card']['cardData'], @credit_card.number
      assert_equal request['source']['card']['securityCode'], @credit_card.verification_value
      assert_equal request['source']['card']['securityCodeIndicator'], 'PROVIDED'
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['transactionDetails']['captureFlag'], false
      assert_equal request['merchantDetails']['terminalId'], @gateway.options[:terminal_id]
      assert_equal request['merchantDetails']['merchantId'], @gateway.options[:merchant_id]
      assert_equal request['amount']['total'], (@amount / 100.0).to_f
      assert_equal request['source']['card']['cardData'], @credit_card.number
      assert_equal request['source']['card']['securityCode'], @credit_card.verification_value
      assert_equal request['source']['card']['securityCodeIndicator'], 'PROVIDED'
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_successful_purchase_with_apple_pay
    apple_pay_config = {
      data: 'hbreWcQg980mUoUCfuCoripnHO210lvtizOFLV6PTw1DjooSwik778bH/qgK2pKelDTiiC8eXeiSwSIfrTPp6tq9x8Xo2H0KYAHCjLaJtoDdnjXm8QtC3m8MlcKAyYKp4hOW6tcPmy5rKVCKr1RFCDwjWd9zfVmp/au8hzZQtTYvnlje9t36xNy057eKmA1Bl1r9MFPxicTudVesSYMoAPS4IS+IlYiZzCPHzSLYLvFNiLFzP77qq7B6HSZ3dAZm244v8ep9EQdZVb1xzYdr6U+F5n1W+prS/fnL4+PVdiJK1Gn2qhiveyQX1XopLEQSbMDaW0wYhfDP9XM/+EDMLaXIKRiCtFry9nkbQZDjr2ti91KOAvzQf7XFbV+O8i60BSlI4/QRmLdKHmk/m0rDgQAoYLgUZ5xjKzXpJR9iW6RWuNYyaf9XdD8s2eB9aBQ=',
      application_data_hash: '94ee059335e587e501cc4bf90613e0814f00a7b08bc7c648fd865a2af6a22cc2',
      ephemeral_public_key: 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEvR+anQg6pElOsCnC3HIeNoEs2XMHQwxuy9plV1MfRRtIiHnQ6MyOS+1FQ7WZR2bVAnHFhPFaM9RYe7/bynvVvg==',
      public_key_hash: 'KRsyW0NauLpN8OwKr+yeu4jl6APbgW05/TYo5eGW0bQ=',
      transaction_id: '31323334353637',
      signature: 'MIAGCSqGSIb3DQEHAqCAMIACAQExDzANBglghkgBZQMEAgEFADCABgkqhkiG9w0BBwEAAKCAMIIB0zCCAXkCAQEwCQYHKoZIzj0EATB2MQswCQYDVQQGEwJVUzELMAkGA1UECAwCTkoxFDASBgNVBAcMC0plcnNleSBDaXR5MRMwEQYDVQQKDApGaXJzdCBEYXRhMRIwEAYDVQQLDAlGaXJzdCBBUEkxGzAZBgNVBAMMEmQxZHZ0bDEwMDAuMWRjLmNvbTAeFw0xNTA3MjMxNjQxMDNaFw0xOTA3MjIxNjQxMDNaMHYxCzAJBgNVBAYTAlVTMQswCQYDVQQIDAJOSjEUMBIGA1UEBwwLSmVyc2V5IENpdHkxEzARBgNVBAoMCkZpcnN0IERhdGExEjAQBgNVBAsMCUZpcnN0IEFQSTEbMBkGA1UEAwwSZDFkdnRsMTAwMC4xZGMuY29tMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAErnHhPM18HFbOomJMUiLiPL7nrJuWvfPy0Gg3xsX3m8q0oWhTs1QcQDTT+TR3yh4sDRPqXnsTUwcvbrCOzdUEeTAJBgcqhkjOPQQBA0kAMEYCIQDrC1z2JTx1jZPvllpnkxPEzBGk9BhTCkEB58j/Cv+sXQIhAKGongoz++3tJroo1GxnwvzK/Qmc4P1K2lHoh9biZeNhAAAxggFSMIIBTgIBATB7MHYxCzAJBgNVBAYTAlVTMQswCQYDVQQIDAJOSjEUMBIGA1UEBwwLSmVyc2V5IENpdHkxEzARBgNVBAoMCkZpcnN0IERhdGExEjAQBgNVBAsMCUZpcnN0IEFQSTEbMBkGA1UEAwwSZDFkdnRsMTAwMC4xZGMuY29tAgEBMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTkwNjA3MTg0MTIxWjAvBgkqhkiG9w0BCQQxIgQg0PLaZU4YWZqtP9t/ygv9XIS/5ngU6FlGjpvyK6VFXVMwCgYIKoZIzj0EAwIERjBEAiBTNmQEPyc3aMm4Mwa0riD3dNdSc9aAhslj65Us8b3aKwIgNSc/y+CWpsr8qDln0fZK6ZD/LWPMxofQedlPy7Q6gY8AAAAAAAA=',
      version: 'EC_v1',
      application_data: 'VEVTVA==',
      merchant_id: 'merchant.com.fapi.tcoe.applepay',
      merchant_private_key: 'MHcCAQEE234234234opsmasdsalsamdsad/asdsad/asdasd/asdAwEHoUQDQgAaslkdsad8asjdnlkm23leu9jclaskdas/masr4+/as34+4fh/sf64g/nX35fs5w=='
    }
    apple_pay = network_tokenization_credit_card('4242424242424242', payment_cryptogram: '111111111100cryptogram', brand: 'apple_pay')
    stub_comms do
      @gateway.purchase(@amount, apple_pay, @options.merge({ apple_pay: apple_pay_config }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['source']['sourceType'], 'ApplePay'
      assert_equal request['source']['data'], apple_pay_config[:data]
      assert_equal request['source']['header']['applicationDataHash'], apple_pay_config[:application_data_hash]
      assert_equal request['source']['header']['ephemeralPublicKey'], apple_pay_config[:ephemeral_public_key]
      assert_equal request['source']['header']['publicKeyHash'], apple_pay_config[:public_key_hash]
      assert_equal request['source']['header']['transactionId'], apple_pay_config[:transaction_id]
      assert_equal request['source']['signature'], apple_pay_config[:signature]
      assert_equal request['source']['version'], apple_pay_config[:version]
      assert_equal request['source']['header']['applicationData'], apple_pay_config[:application_data]
      assert_equal request['source']['applePayMerchantId'], apple_pay_config[:merchant_id]
      assert_equal request['source']['header']['merchantPrivateKey'], apple_pay_config[:merchant_private_key]
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_google_pay
    google_pay_config = {
      encrypted_message: 'NZF5Vs2YaI/t25L/1+dp6tuUOvra9pszs2antqcbHJbkjMMXZSR7innTFJxNR5DNnf4GheWIso8n8MA1q1zqWCU8MaK9bnNcHxvROpvfsU3SCCjkfG2k2M4/RYMjs+lxYW/nEtIIKVVOkdjAj4pI/Wth8xQXphn7hDNiyp9tIydmlPZVnzkXI6mVbpHbbkaCCD4TNPhFBDtx0VafqRjbb2Wt3EDazTx3dHdd+qVX5Xj8/BPb1cmwHWvrDw/dQRk/E0TsP+erLjhLaZ8l2EycxeUEZYqSX5w77S8vd3sw8WXuOCMsU8sx0Bs5IY7hohq67qNDxckP1fcBD4OYdGP6bumJR0J6pJxD5iRh5lFSjN6zNLRI77ylxWL6DwHoe/pPdCc0n6cV0Nt0RJMLjerr12BLuhv4bPQ3QB6jxnbt8JK/EndgIG8xpFyNkKlRUyxAKM22/ZSy45d6qtZIKLXRqDTr9JMk8uJ53QRZtQx8k9KkRZGC+GM2sD+Z75fxc0Yye7l6H0D8p5z1iEzWnYHxd0pmY/cOYEJxnOOdD573QmE6ikFcyaAw3XnCyul/EA==',
      ephemeral_public_key: 'BAhnPIWrCXWv/45GFK0mNAvN9w+NFBs3tQji0wTUS2+hiFKsZujG5wRd4JXGmxhG+k3bglYk544ILBNdDpsAh+o=',
      tag: 'liBzKfGcO+FclHg7XuqRJxR/8EJShRp9/APab0Sho08=',
      signature: 'MEUCIFWTRWUZAOM5nfJC79FtJm56olnbwG4H5uWWxAUWAquiAiEA24j/BcOroeISsdJzYsyoVi8wzu4tnmKw+jdsGfuvPko=',
      version: 'ECv2',
      merchant_id: '676174657761793A666972737464617461',
      merchant_private_key: 'DCEDF9AF72707BFD9C5231ECB9EAD040F3B4BA2AB608579736E37FDBA8884175566BDA410997B2575EA7E76AC54BBDB99DD0F74DD0A648BC0F6A2F06909E79A0F15D779F1A80CFC1EC9612476204C43A',
      signing_verification_key: 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEIsFro6K+IUxRr4yFTOTO+kFCCEvHo7B9IOMLxah6c977oFzX/beObH4a9OfosMHmft3JJZ6B3xpjIb8kduK4/A=='
    }
    google_pay = network_tokenization_credit_card('4242424242424242', payment_cryptogram: '111111111100cryptogram', brand: 'google_pay')
    stub_comms do
      @gateway.purchase(@amount, google_pay, @options.merge({ google_pay: google_pay_config }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['source']['sourceType'], 'GooglePay'
      assert_equal request['source']['data']['encryptedMessage'], google_pay_config[:encrypted_message]
      assert_equal request['source']['data']['ephemeralPublicKey'], google_pay_config[:ephemeral_public_key]
      assert_equal request['source']['data']['tag'], google_pay_config[:tag]
      assert_equal request['source']['signature'], google_pay_config[:signature]
      assert_equal request['source']['version'], google_pay_config[:version]
      assert_equal request['source']['merchantId'], google_pay_config[:merchant_id]
      assert_equal request['source']['merchantPrivateKey'], google_pay_config[:merchant_private_key]
      assert_equal request['source']['signingVerificationKey'], google_pay_config[:signing_verification_key]
    end.respond_with(successful_purchase_response)
  end

  def test_failed_purchase_and_authorize
    @gateway.expects(:ssl_post).returns(failed_purchase_and_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'HOST', response.error_code
  end

  def test_successful_parsing_of_billing_and_shipping_addresses
    address_with_phone = address.merge({ phone_number: '000-000-00-000' })
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge({ billing_address: address_with_phone, shipping_address: address_with_phone }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      %w(shipping billing).each do |key|
        assert_equal request[key + 'Address']['address']['street'], address_with_phone[:address1]
        assert_equal request[key + 'Address']['address']['houseNumberOrName'], address_with_phone[:address2]
        assert_equal request[key + 'Address']['address']['recipientNameOrAddress'], address_with_phone[:name]
        assert_equal request[key + 'Address']['address']['city'], address_with_phone[:city]
        assert_equal request[key + 'Address']['address']['stateOrProvince'], address_with_phone[:state]
        assert_equal request[key + 'Address']['address']['postalCode'], address_with_phone[:zip]
        assert_equal request[key + 'Address']['address']['country'], address_with_phone[:country]
        assert_equal request[key + 'Address']['phone']['phoneNumber'], address_with_phone[:phone_number]
      end
    end.respond_with(successful_authorize_response)
  end

  def test_successful_void
    response = stub_comms do
      @gateway.void('authorization123', @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['referenceTransactionDetails']['referenceTransactionId'], 'authorization123'
      assert_equal request['referenceTransactionDetails']['referenceTransactionType'], 'CHARGES'
      assert_nil request['transactionDetails']['captureFlag']
    end.respond_with(successful_void_and_refund_response)

    assert_success response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(nil, 'authorization123', @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['referenceTransactionDetails']['referenceTransactionId'], 'authorization123'
      assert_equal request['referenceTransactionDetails']['referenceTransactionType'], 'CHARGES'
      assert_nil request['transactionDetails']['captureFlag']
      assert_nil request['amount']
    end.respond_with(successful_void_and_refund_response)

    assert_success response
  end

  def test_successful_partial_refund
    response = stub_comms do
      @gateway.refund(@amount - 1, 'authorization123', @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['referenceTransactionDetails']['referenceTransactionId'], 'authorization123'
      assert_equal request['referenceTransactionDetails']['referenceTransactionType'], 'CHARGES'
      assert_nil request['transactionDetails']['captureFlag']
      assert_equal request['amount']['total'], ((@amount - 1) / 100.0).to_f
      assert_equal request['amount']['currency'], 'USD'
    end.respond_with(successful_void_and_refund_response)

    assert_success response
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['merchantDetails']['terminalId'], @gateway.options[:terminal_id]
      assert_equal request['merchantDetails']['merchantId'], @gateway.options[:merchant_id]
      assert_equal request['source']['card']['cardData'], @credit_card.number
      assert_equal request['source']['card']['securityCode'], @credit_card.verification_value
      assert_equal request['source']['card']['securityCodeIndicator'], 'PROVIDED'
    end.respond_with(successful_store_response)

    assert_success response
    assert_equal response.params['paymentTokens'].first['tokenData'], response.authorization
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['transactionDetails']['captureFlag'], false
      assert_equal request['transactionDetails']['primaryTransactionType'], 'AUTH_ONLY'
      assert_equal request['transactionDetails']['accountVerification'], true
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  private

  def successful_purchase_response
    <<~RESPONSE
      {
        "gatewayResponse": {
            "transactionType": "CHARGE",
            "transactionState": "CAPTURED",
            "transactionOrigin": "ECOM",
            "transactionProcessingDetails": {
                "orderId": "CHG018048a66aafc64d789cb018a53c30fd74",
                "transactionTimestamp": "2022-10-06T11:27:45.593359Z",
                "apiTraceId": "6304d53be8d94312a620962afc9c012d",
                "clientRequestId": "5106241",
                "transactionId": "6304d53be8d94312a620962afc9c012d"
            }
        },
        "source": {
            "sourceType": "PaymentCard",
            "card": {
                "expirationMonth": "02",
                "expirationYear": "2035",
                "securityCodeIndicator": "PROVIDED",
                "bin": "400555",
                "last4": "0019",
                "scheme": "VISA"
            }
        },
        "paymentReceipt": {
            "approvedAmount": {
                "total": 12.04,
                "currency": "USD"
            },
            "processorResponseDetails": {
                "approvalStatus": "APPROVED",
                "approvalCode": "000238",
                "referenceNumber": "962afc9c012d",
                "processor": "FISERV",
                "host": "NASHVILLE",
                "networkInternationalId": "0001",
                "responseCode": "000",
                "responseMessage": "Approved",
                "hostResponseCode": "00",
                "additionalInfo": [
                    {
                        "name": "HOST_RAW_PROCESSOR_RESPONSE",
                        "value": "ARAyIAHvv70O77+9AAAAAAAAAAAAEgQQBhAnRQE1JAABWTk2MmFmYzljMDEyZDAwMDIzODAwMDk5OTk5OTk="
                    }
                ]
            }
        },
        "transactionDetails": {
            "captureFlag": true,
            "transactionCaptureType": "hcs",
            "processingCode": "000000",
            "merchantInvoiceNumber": "123456789012",
            "createToken": true,
            "retrievalReferenceNumber": "962afc9c012d"
        },
        "transactionInteraction": {
            "posEntryMode": "UNSPECIFIED",
            "posConditionCode": "CARD_NOT_PRESENT_ECOM",
            "additionalPosInformation": {
                "dataEntrySource": "UNSPECIFIED",
                "posFeatures": {
                    "pinAuthenticationCapability": "UNSPECIFIED",
                    "terminalEntryCapability": "UNSPECIFIED"
                }
            },
            "hostPosConditionCode": "59"
        },
        "merchantDetails": {
            "tokenType": "BBY0",
            "terminalId": "10000001",
            "merchantId": "100008000003683"
        },
        "networkDetails": {
            "network": {
                "network": "Visa"
            }
        }
      }
    RESPONSE
  end

  def successful_authorize_response
    <<~RESPONSE
      {
        "gatewayResponse": {
            "transactionType": "CHARGE",
            "transactionState": "AUTHORIZED",
            "transactionOrigin": "ECOM",
            "transactionProcessingDetails": {
                "orderId": "CHG01fb29348b9f8a48ed875e6bea3af41744",
                "transactionTimestamp": "2022-10-06T11:28:27.131701Z",
                "apiTraceId": "000bc22420f448288f1226d28dfdf275",
                "clientRequestId": "9573527",
                "transactionId": "000bc22420f448288f1226d28dfdf275"
            }
        },
        "source": {
            "sourceType": "PaymentCard",
            "card": {
                "expirationMonth": "02",
                "expirationYear": "2035",
                "bin": "400555",
                "last4": "0019",
                "scheme": "VISA"
            }
        },
        "paymentReceipt": {
            "approvedAmount": {
                "total": 12.04,
                "currency": "USD"
            },
            "processorResponseDetails": {
                "approvalStatus": "APPROVED",
                "approvalCode": "000239",
                "referenceNumber": "26d28dfdf275",
                "processor": "FISERV",
                "host": "NASHVILLE",
                "networkInternationalId": "0001",
                "responseCode": "000",
                "responseMessage": "Approved",
                "hostResponseCode": "00",
                "additionalInfo": [
                    {
                        "name": "HOST_RAW_PROCESSOR_RESPONSE",
                        "value": "ARAyIAHvv70O77+9AAAAAAAAAAAAEgQQBhAoJzQ2aAABWTI2ZDI4ZGZkZjI3NTAwMDIzOTAwMDk5OTk5OTk="
                    }
                ]
            }
        },
        "transactionDetails": {
            "captureFlag": false,
            "transactionCaptureType": "hcs",
            "processingCode": "000000",
            "merchantInvoiceNumber": "123456789012",
            "createToken": true,
            "retrievalReferenceNumber": "26d28dfdf275"
        },
        "transactionInteraction": {
            "posEntryMode": "UNSPECIFIED",
            "posConditionCode": "CARD_NOT_PRESENT_ECOM",
            "additionalPosInformation": {
                "dataEntrySource": "UNSPECIFIED",
                "posFeatures": {
                    "pinAuthenticationCapability": "UNSPECIFIED",
                    "terminalEntryCapability": "UNSPECIFIED"
                }
            },
            "hostPosConditionCode": "59"
        },
        "merchantDetails": {
            "tokenType": "BBY0",
            "terminalId": "10000001",
            "merchantId": "100008000003683"
        },
        "networkDetails": {
            "network": {
                "network": "Visa"
            }
        }
      }
    RESPONSE
  end

  def failed_purchase_and_authorize_response
    <<~RESPONSE
      {
        "gatewayResponse": {
          "transactionType": "CHARGE",
          "transactionState": "AUTHORIZED",
          "transactionOrigin": "ECOM",
          "transactionProcessingDetails": {
            "orderId": "R-3b83fca8-2f9c-4364-86ae-12c91f1fcf16",
            "transactionTimestamp": "2016-04-16T16:06:05Z",
            "apiTraceId": "1234567a1234567b1234567c1234567d",
            "clientRequestId": "30dd879c-ee2f-11db-8314-0800200c9a66",
            "transactionId": "838916029301"
          }
        },
        "error": [
          {
            "type": "HOST",
            "code": "string",
            "field": "source.sourceType",
            "message": "Missing type ID property.",
            "additionalInfo": "The Reauthorization request was not successful and the Cancel of referenced authorization transaction was not processed, per Auth_before_Cancel configuration"
          }
        ]
      }
    RESPONSE
  end

  def successful_void_and_refund_response
    <<~RESPONSE
      {
        "gatewayResponse": {
          "transactionType": "CANCEL",
          "transactionState": "AUTHORIZED",
          "transactionOrigin": "ECOM",
          "transactionProcessingDetails": {
            "transactionTimestamp": "2021-06-20T23:42:48Z",
            "orderId": "RKOrdID-525133851837",
            "apiTraceId": "362866ac81864d7c9d1ff8b5aa6e98db",
            "clientRequestId": "4345791",
            "transactionId": "84356531338"
          }
        },
        "source": {
          "sourceType": "PaymentCard",
          "card": {
            "bin": "40055500",
            "last4": "0019",
            "scheme": "VISA",
            "expirationMonth": "10",
            "expirationYear": "2030"
          }
        },
        "paymentReceipt": {
          "approvedAmount": {
            "total": 12.04,
            "currency": "USD"
          },
          "merchantName": "Merchant Name",
          "merchantAddress": "123 Peach Ave",
          "merchantCity": "Atlanta",
          "merchantStateOrProvince": "GA",
          "merchantPostalCode": "12345",
          "merchantCountry": "US",
          "merchantURL": "https://www.somedomain.com",
          "processorResponseDetails": {
            "approvalStatus": "APPROVED",
            "approvalCode": "OK5882",
            "schemeTransactionId": "0225MCC625628",
            "processor": "FISERV",
            "host": "NASHVILLE",
            "responseCode": "000",
            "responseMessage": "APPROVAL",
            "hostResponseCode": "00",
            "hostResponseMessage": "APPROVAL",
            "localTimestamp": "2021-06-20T23:42:48Z",
            "bankAssociationDetails": {
              "associationResponseCode": "000",
              "transactionTimestamp": "2021-06-20T23:42:48Z"
            }
          }
        },
        "transactionDetails": {
          "merchantInvoiceNumber": "123456789012"
        }
      }
    RESPONSE
  end

  def successful_store_response
    <<~RESPONSE
      {
        "gatewayResponse": {
          "transactionType": "TOKENIZE",
          "transactionState": "AUTHORIZED",
          "transactionOrigin": "ECOM",
          "transactionProcessingDetails": {
            "transactionTimestamp": "2021-06-20T23:42:48Z",
            "orderId": "RKOrdID-525133851837",
            "apiTraceId": "362866ac81864d7c9d1ff8b5aa6e98db",
            "clientRequestId": "4345791",
            "transactionId": "84356531338"
          }
        },
        "source": {
          "sourceType": "PaymentCard",
          "card": {
            "bin": "40055500",
            "last4": "0019",
            "scheme": "VISA",
            "expirationMonth": "10",
            "expirationYear": "2030"
          }
        },
        "paymentTokens": [
          {
            "tokenData": "8519371934460009",
            "tokenSource": "TRANSARMOR",
            "tokenResponseCode": "000",
            "tokenResponseDescription": "SUCCESS"
          },
          {
            "tokenData": "8519371934460010",
            "tokenSource": "CHASE",
            "tokenResponseCode": "000",
            "tokenResponseDescription": "SUCCESS"
          }
        ],
        "processorResponseDetails": {
          "approvalStatus": "APPROVED",
          "approvalCode": "OK5882",
          "schemeTransactionId": "0225MCC625628",
          "processor": "FISERV",
          "host": "NASHVILLE",
          "responseCode": "000",
          "responseMessage": "APPROVAL",
          "hostResponseCode": "00",
          "hostResponseMessage": "APPROVAL",
          "localTimestamp": "2021-06-20T23:42:48Z",
          "bankAssociationDetails": {
            "associationResponseCode": "000",
            "transactionTimestamp": "2021-06-20T23:42:48Z"
          }
        }
      }
    RESPONSE
  end
end
