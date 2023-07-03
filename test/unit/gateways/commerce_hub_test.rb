require 'test_helper'

class CommerceHubTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CommerceHubGateway.new(api_key: 'login', api_secret: 'password', merchant_id: '12345', terminal_id: '0001')

    @amount = 1204
    @credit_card = credit_card('4005550000000019', month: '02', year: '2035', verification_value: '123')
    @google_pay = network_tokenization_credit_card(
      '4005550000000019',
      brand: 'visa',
      eci: '05',
      month: '02',
      year: '2035',
      source: :google_pay,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      transaction_id: '13456789'
    )
    @apple_pay = network_tokenization_credit_card(
      '4005550000000019',
      brand: 'visa',
      eci: '05',
      month: '02',
      year: '2035',
      source: :apple_pay,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      transaction_id: '13456789'
    )
    @no_supported_source = network_tokenization_credit_card(
      '4005550000000019',
      brand: 'visa',
      eci: '05',
      month: '02',
      year: '2035',
      source: :no_source,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )
    @declined_card = credit_card('4000300011112220', month: '02', year: '2035', verification_value: '123')
    @options = {}
    @post = {}
  end

  def test_successful_purchase
    @options[:order_id] = 'abc123'

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['transactionDetails']['captureFlag'], true
      assert_equal request['transactionDetails']['createToken'], false
      assert_equal request['transactionDetails']['merchantOrderId'], 'abc123'
      assert_equal request['merchantDetails']['terminalId'], @gateway.options[:terminal_id]
      assert_equal request['merchantDetails']['merchantId'], @gateway.options[:merchant_id]
      assert_equal request['amount']['total'], (@amount / 100.0).to_f
      assert_equal request['source']['card']['cardData'], @credit_card.number
      assert_equal request['source']['card']['securityCode'], @credit_card.verification_value
      assert_equal request['transactionInteraction']['posEntryMode'], 'MANUAL'
      assert_equal request['source']['card']['securityCodeIndicator'], 'PROVIDED'
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_google_pay
    response = stub_comms do
      @gateway.purchase(@amount, @google_pay, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['transactionDetails']['captureFlag'], true
      assert_equal request['merchantDetails']['terminalId'], @gateway.options[:terminal_id]
      assert_equal request['merchantDetails']['merchantId'], @gateway.options[:merchant_id]
      assert_equal request['amount']['total'], (@amount / 100.0).to_f
      assert_equal request['source']['card']['cardData'], @google_pay.number
      assert_equal request['source']['cavv'], @google_pay.payment_cryptogram
      assert_equal request['source']['walletType'], 'GOOGLE_PAY'
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_apple_pay
    response = stub_comms do
      @gateway.purchase(@amount, @apple_pay, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['transactionDetails']['captureFlag'], true
      assert_equal request['merchantDetails']['terminalId'], @gateway.options[:terminal_id]
      assert_equal request['merchantDetails']['merchantId'], @gateway.options[:merchant_id]
      assert_equal request['amount']['total'], (@amount / 100.0).to_f
      assert_equal request['source']['card']['cardData'], @apple_pay.number
      assert_equal request['source']['cavv'], @apple_pay.payment_cryptogram
      assert_equal request['source']['walletType'], 'APPLE_PAY'
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_no_supported_source_as_apple_pay
    response = stub_comms do
      @gateway.purchase(@amount, @no_supported_source, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['transactionDetails']['captureFlag'], true
      assert_equal request['merchantDetails']['terminalId'], @gateway.options[:terminal_id]
      assert_equal request['merchantDetails']['merchantId'], @gateway.options[:merchant_id]
      assert_equal request['amount']['total'], (@amount / 100.0).to_f
      assert_equal request['source']['card']['cardData'], @apple_pay.number
      assert_equal request['source']['cavv'], @apple_pay.payment_cryptogram
      assert_equal request['source']['walletType'], 'APPLE_PAY'
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

  def test_failed_purchase_and_authorize
    @gateway.expects(:ssl_post).returns(failed_purchase_and_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'string', response.error_code
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
      @gateway.void('abc123|authorization123', @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal 'authorization123', request['referenceTransactionDetails']['referenceTransactionId']
      assert_equal 'CHARGES', request['referenceTransactionDetails']['referenceTransactionType']
      assert_nil request['transactionDetails']['captureFlag']
    end.respond_with(successful_void_and_refund_response)

    assert_success response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(nil, 'abc123|authorization123', @options)
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
      @gateway.refund(@amount - 1, 'abc123|authorization123', @options)
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

  def test_successful_purchase_cit_with_gsf
    options = stored_credential_options(:cardholder, :unscheduled, :initial)
    options[:data_entry_source] = 'MOBILE_WEB'
    options[:pos_entry_mode] = 'MANUAL'
    options[:pos_condition_code] = 'CARD_PRESENT'
    response = stub_comms do
      @gateway.purchase(@amount, 'authorization123', options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['transactionInteraction']['origin'], 'ECOM'
      assert_equal request['transactionInteraction']['eciIndicator'], 'CHANNEL_ENCRYPTED'
      assert_equal request['transactionInteraction']['posConditionCode'], 'CARD_PRESENT'
      assert_equal request['transactionInteraction']['posEntryMode'], 'MANUAL'
      assert_equal request['transactionInteraction']['additionalPosInformation']['dataEntrySource'], 'MOBILE_WEB'
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_successful_purchase_mit_with_gsf
    options = stored_credential_options(:merchant, :recurring)
    options[:origin] = 'POS'
    options[:pos_entry_mode] = 'MANUAL'
    options[:data_entry_source] = 'MOBILE_WEB'
    response = stub_comms do
      @gateway.purchase(@amount, 'authorization123', options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['transactionInteraction']['origin'], 'POS'
      assert_equal request['transactionInteraction']['eciIndicator'], 'CHANNEL_ENCRYPTED'
      assert_equal request['transactionInteraction']['posConditionCode'], 'CARD_NOT_PRESENT_ECOM'
      assert_equal request['transactionInteraction']['posEntryMode'], 'MANUAL'
      assert_equal request['transactionInteraction']['additionalPosInformation']['dataEntrySource'], 'MOBILE_WEB'
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_successful_purchase_with_gsf_scheme_reference_transaction_id
    @options = stored_credential_options(:cardholder, :unscheduled, :initial)
    @options[:physical_goods_indicator] = true
    @options[:scheme_reference_transaction_id] = '12345'
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['storedCredentials']['schemeReferenceTransactionId'], '12345'
      assert_equal request['transactionDetails']['physicalGoodsIndicator'], true
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def stored_credential_options(*args, ntid: nil)
    {
      order_id: '#1001',
      stored_credential: stored_credential(*args, ntid: ntid)
    }
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
    stub_comms do
      @gateway.verify(@credit_card, @options)
    end.check_request do |endpoint, data, _headers|
      request = JSON.parse(data)
      assert_match %r{verification}, endpoint
      assert_equal request['source']['sourceType'], 'PaymentCard'
    end.respond_with(successful_authorize_response)
  end

  def test_getting_avs_cvv_from_response
    gateway_resp = {
      'paymentReceipt' => {
        'processorResponseDetails' => {
          'bankAssociationDetails' => {
            'associationResponseCode' => 'V000',
            'avsSecurityCodeResponse' => {
              'streetMatch' => 'NONE',
               'postalCodeMatch' => 'NONE',
               'securityCodeMatch' => 'NOT_CHECKED',
               'association' => {
                 'securityCodeResponse' => 'X',
                 'avsCode' => 'Y'
               }
            }
          }
        }
      }
    }

    assert_equal 'X', @gateway.send(:get_avs_cvv, gateway_resp, 'cvv')
    assert_equal 'Y', @gateway.send(:get_avs_cvv, gateway_resp, 'avs')
  end

  def test_successful_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_uses_order_id_to_keep_transaction_references_when_provided
    @options[:order_id] = 'abc123'

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'abc123|6304d53be8d94312a620962afc9c012d', response.authorization
  end

  def test_detect_success_state_for_verify_on_success_transaction
    gateway_resp = {
      'gatewayResponse' => {
        'transactionState' => 'VERIFIED'
      }
    }

    assert @gateway.send :success_from, gateway_resp, 'verify'
  end

  def test_detect_success_state_for_verify_on_failure_transaction
    gateway_resp = {
      'gatewayResponse' => {
        'transactionState' => 'NOT_VERIFIED'
      }
    }

    refute @gateway.send :success_from, gateway_resp, 'verify'
  end

  def test_add_reference_transaction_details_capture_reference_id
    authorization = '|922e-59fc86a36c03'

    @gateway.send :add_reference_transaction_details, @post, authorization, {}, :capture
    assert_equal '922e-59fc86a36c03', @post[:referenceTransactionDetails][:referenceTransactionId]
    assert_nil @post[:referenceTransactionDetails][:referenceTransactionType]
  end

  def test_add_reference_transaction_details_void_reference_id
    authorization = '|922e-59fc86a36c03'

    @gateway.send :add_reference_transaction_details, @post, authorization, {}, :void
    assert_equal '922e-59fc86a36c03', @post[:referenceTransactionDetails][:referenceTransactionId]
    assert_equal 'CHARGES', @post[:referenceTransactionDetails][:referenceTransactionType]
  end

  def test_add_reference_transaction_details_refund_reference_id
    authorization = '|922e-59fc86a36c03'

    @gateway.send :add_reference_transaction_details, @post, authorization, {}, :refund
    assert_equal '922e-59fc86a36c03', @post[:referenceTransactionDetails][:referenceTransactionId]
    assert_equal 'CHARGES', @post[:referenceTransactionDetails][:referenceTransactionType]
  end

  def test_successful_purchase_when_encrypted_credit_card_present
    @options[:order_id] = 'abc123'
    @options[:encryption_data] = {
      keyId: SecureRandom.uuid,
      encryptionType: 'RSA',
      encryptionBlock: SecureRandom.alphanumeric(20),
      encryptionBlockFields: 'card.cardData:16,card.nameOnCard:8,card.expirationMonth:2,card.expirationYear:4,card.securityCode:3',
      encryptionTarget: 'MANUAL'
    }

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      refute_nil request['source']['encryptionData']
      assert_equal request['source']['sourceType'], 'PaymentCard'
      assert_equal request['source']['encryptionData']['keyId'], @options[:encryption_data][:keyId]
      assert_equal request['source']['encryptionData']['encryptionType'], 'RSA'
      assert_equal request['source']['encryptionData']['encryptionBlock'], @options[:encryption_data][:encryptionBlock]
      assert_equal request['source']['encryptionData']['encryptionBlockFields'], @options[:encryption_data][:encryptionBlockFields]
      assert_equal request['source']['encryptionData']['encryptionTarget'], 'MANUAL'
    end.respond_with(successful_purchase_response)

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

  def pre_scrubbed
    <<~PRE_SCRUBBED
      opening connection to cert.api.fiservapps.com:443...
      opened
      starting SSL for cert.api.fiservapps.com:443...
      SSL established
      <- "POST /ch/payments/v1/charges HTTP/1.1\r\nContent-Type: application/json\r\nClient-Request-Id: 3473900\r\nApi-Key: nEcoHEQZjKtkKW9dN6yH7x4gO2EIARKe\r\nTimestamp: 1670258885014\r\nAccept-Language: application/json\r\nAuth-Token-Type: HMAC\r\nAccept: application/json\r\nAuthorization: TQh0nE38Mv7cbxbX3oSIUxZ4RzMkTmS2hpUSd6Rgi98=\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: cert.api.fiservapps.com\r\nContent-Length: 500\r\n\r\n"
      <- "{\"transactionDetails\":{\"captureFlag\":true,\"merchantInvoiceNumber\":\"995952121195\"},\"amount\":{\"total\":12.04,\"currency\":\"USD\"},\"source\":{\"sourceType\":\"PaymentCard\",\"card\":{\"cardData\":\"4005550000000019\",\"expirationMonth\":\"02\",\"expirationYear\":\"2035\",\"securityCode\":\"123\",\"securityCodeIndicator\":\"PROVIDED\"}},\"transactionInteraction\":{\"origin\":\"ECOM\",\"eciIndicator\":\"CHANNEL_ENCRYPTED\",\"posConditionCode\":\"CARD_NOT_PRESENT_ECOM\"},\"merchantDetails\":{\"terminalId\":\"10000001\",\"merchantId\":\"100008000003683\"}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Mon, 05 Dec 2022 16:48:06 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 1709\r\n"
      -> "Connection: close\r\n"
      -> "Expires: 0\r\n"
      -> "Referrer-Policy: no-referrer\r\n"
      -> "X-Frame-Options: DENY\r\n"
      -> "X-Vcap-Request-Id: 30397096-5cb9-46e1-7c63-3ac2494ca38e\r\n"
      -> "targetServerReceivedEndTimestamp: 1670258886388\r\n"
      -> "targetServerSentStartTimestamp: 1670258885212\r\n"
      -> "X-Xss-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
      -> "Cache-Control: no-store, no-cache, must-revalidate\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Access-Control-Max-Age: 86400\r\n"
      -> "ApiTraceId: 19d178570f274a2196540af6e2e0bf55\r\n"
      -> "Via: 1.1 dca1-bit16021\r\n"
      -> "\r\n"
      reading 1709 bytes...
      -> "{\"gatewayResponse\":{\"transactionType\":\"CHARGE\",\"transactionState\":\"CAPTURED\",\"transactionOrigin\":\"ECOM\",\"transactionProcessingDetails\":{\"orderId\":\"CHG0147086beb95194e808a3bf88e052285d7\",\"transactionTimestamp\":\"2022-12-05T16:48:05.358725Z\",\"apiTraceId\":\"19d178570f274a2196540af6e2e0bf55\",\"clientRequestId\":\"3473900\",\"transactionId\":\"19d178570f274a2196540af6e2e0bf55\"}},\"source\":{\"sourceType\":\"PaymentCard\",\"card\":{\"expirationMonth\":\"02\",\"expirationYear\":\"2035\",\"securityCodeIndicator\":\"PROVIDED\",\"bin\":\"400555\",\"last4\":\"0019\",\"scheme\":\"VISA\"}},\"paymentReceipt\":{\"approvedAmount\":{\"total\":12.04,\"currency\":\"USD\"},\"processorResponseDetails\":{\"approvalStatus\":\"APPROVED\",\"approvalCode\":\"000119\",\"referenceNumber\":\"0af6e2e0bf55\",\"processor\":\"FISERV\",\"host\":\"NASHVILLE\",\"networkInternationalId\":\"0001\",\"responseCode\":\"000\",\"responseMessage\":\"Approved\",\"hostResponseCode\":\"00\",\"additionalInfo\":[{\"name\":\"HOST_RAW_PROCESSOR_RESPONSE\",\"value\":\"ARAyIAHvv70O77+9AAIAAAAAAAAAEgQSBRZIBTNCVQABWTBhZjZlMmUwYmY1NTAwMDExOTAwMDk5OTk5OTkABAACMTQ=\"}]}},\"transactionDetails\":{\"captureFlag\":true,\"transactionCaptureType\":\"hcs\",\"processingCode\":\"000000\",\"merchantInvoiceNumber\":\"995952121195\",\"createToken\":true,\"retrievalReferenceNumber\":\"0af6e2e0bf55\",\"cavvInPrimary\":false},\"transactionInteraction\":{\"posEntryMode\":\"UNSPECIFIED\",\"posConditionCode\":\"CARD_NOT_PRESENT_ECOM\",\"additionalPosInformation\":{\"dataEntrySource\":\"UNSPECIFIED\",\"posFeatures\":{\"pinAuthenticationCapability\":\"UNSPECIFIED\",\"terminalEntryCapability\":\"UNSPECIFIED\"}},\"hostPosEntryMode\":\"000\",\"hostPosConditionCode\":\"59\"},\"merchantDetails\":{\"tokenType\":\"BBY0\",\"terminalId\":\"10000001\",\"merchantId\":\"100008000003683\"},\"networkDetails\":{\"network\":{\"network\":\"Visa\"}}}"
      read 1709 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<~POST_SCRUBBED
      opening connection to cert.api.fiservapps.com:443...
      opened
      starting SSL for cert.api.fiservapps.com:443...
      SSL established
      <- "POST /ch/payments/v1/charges HTTP/1.1\r\nContent-Type: application/json\r\nClient-Request-Id: 3473900\r\nApi-Key: [FILTERED]\r\nTimestamp: 1670258885014\r\nAccept-Language: application/json\r\nAuth-Token-Type: HMAC\r\nAccept: application/json\r\nAuthorization: [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: cert.api.fiservapps.com\r\nContent-Length: 500\r\n\r\n"
      <- "{\"transactionDetails\":{\"captureFlag\":true,\"merchantInvoiceNumber\":\"995952121195\"},\"amount\":{\"total\":12.04,\"currency\":\"USD\"},\"source\":{\"sourceType\":\"PaymentCard\",\"card\":{\"cardData\":\"[FILTERED]\",\"expirationMonth\":\"02\",\"expirationYear\":\"2035\",\"securityCode\":\"[FILTERED]\",\"securityCodeIndicator\":\"PROVIDED\"}},\"transactionInteraction\":{\"origin\":\"ECOM\",\"eciIndicator\":\"CHANNEL_ENCRYPTED\",\"posConditionCode\":\"CARD_NOT_PRESENT_ECOM\"},\"merchantDetails\":{\"terminalId\":\"10000001\",\"merchantId\":\"100008000003683\"}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Mon, 05 Dec 2022 16:48:06 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 1709\r\n"
      -> "Connection: close\r\n"
      -> "Expires: 0\r\n"
      -> "Referrer-Policy: no-referrer\r\n"
      -> "X-Frame-Options: DENY\r\n"
      -> "X-Vcap-Request-Id: 30397096-5cb9-46e1-7c63-3ac2494ca38e\r\n"
      -> "targetServerReceivedEndTimestamp: 1670258886388\r\n"
      -> "targetServerSentStartTimestamp: 1670258885212\r\n"
      -> "X-Xss-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
      -> "Cache-Control: no-store, no-cache, must-revalidate\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Access-Control-Max-Age: 86400\r\n"
      -> "ApiTraceId: 19d178570f274a2196540af6e2e0bf55\r\n"
      -> "Via: 1.1 dca1-bit16021\r\n"
      -> "\r\n"
      reading 1709 bytes...
      -> "{\"gatewayResponse\":{\"transactionType\":\"CHARGE\",\"transactionState\":\"CAPTURED\",\"transactionOrigin\":\"ECOM\",\"transactionProcessingDetails\":{\"orderId\":\"CHG0147086beb95194e808a3bf88e052285d7\",\"transactionTimestamp\":\"2022-12-05T16:48:05.358725Z\",\"apiTraceId\":\"19d178570f274a2196540af6e2e0bf55\",\"clientRequestId\":\"3473900\",\"transactionId\":\"19d178570f274a2196540af6e2e0bf55\"}},\"source\":{\"sourceType\":\"PaymentCard\",\"card\":{\"expirationMonth\":\"02\",\"expirationYear\":\"2035\",\"securityCodeIndicator\":\"PROVIDED\",\"bin\":\"400555\",\"last4\":\"0019\",\"scheme\":\"VISA\"}},\"paymentReceipt\":{\"approvedAmount\":{\"total\":12.04,\"currency\":\"USD\"},\"processorResponseDetails\":{\"approvalStatus\":\"APPROVED\",\"approvalCode\":\"000119\",\"referenceNumber\":\"0af6e2e0bf55\",\"processor\":\"FISERV\",\"host\":\"NASHVILLE\",\"networkInternationalId\":\"0001\",\"responseCode\":\"000\",\"responseMessage\":\"Approved\",\"hostResponseCode\":\"00\",\"additionalInfo\":[{\"name\":\"HOST_RAW_PROCESSOR_RESPONSE\",\"value\":\"ARAyIAHvv70O77+9AAIAAAAAAAAAEgQSBRZIBTNCVQABWTBhZjZlMmUwYmY1NTAwMDExOTAwMDk5OTk5OTkABAACMTQ=\"}]}},\"transactionDetails\":{\"captureFlag\":true,\"transactionCaptureType\":\"hcs\",\"processingCode\":\"000000\",\"merchantInvoiceNumber\":\"995952121195\",\"createToken\":true,\"retrievalReferenceNumber\":\"0af6e2e0bf55\",\"cavvInPrimary\":false},\"transactionInteraction\":{\"posEntryMode\":\"UNSPECIFIED\",\"posConditionCode\":\"CARD_NOT_PRESENT_ECOM\",\"additionalPosInformation\":{\"dataEntrySource\":\"UNSPECIFIED\",\"posFeatures\":{\"pinAuthenticationCapability\":\"UNSPECIFIED\",\"terminalEntryCapability\":\"UNSPECIFIED\"}},\"hostPosEntryMode\":\"000\",\"hostPosConditionCode\":\"59\"},\"merchantDetails\":{\"tokenType\":\"BBY0\",\"terminalId\":\"10000001\",\"merchantId\":\"100008000003683\"},\"networkDetails\":{\"network\":{\"network\":\"Visa\"}}}"
      read 1709 bytes
      Conn close
    POST_SCRUBBED
  end
end
