require 'test_helper'
class PriorityTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PriorityGateway.new(key: 'sandbox_key', secret: 'secret', merchant_id: 'merchant_id')
    @amount = 4
    @credit_card = credit_card
    @invalid_credit_card = credit_card('4111')
    @replay_id = rand(100...1000)
    @approval_message = 'Approved or completed successfully. '
    @options = { billing_address: address }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal @approval_message, response.message
    assert_equal 'Sale', response.params['type']
    assert response.test?
  end

  def test_failed_purchase_invalid_credit_card
    response = stub_comms do
      @gateway.purchase(@amount, @invalid_credit_card, @options)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal 'Declined', response.error_code
    assert_equal 'Invalid card number', response.message
    assert response.test?
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(333, @credit_card, @options)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal @approval_message, response.message
    assert_equal 'Authorization', response.params['type']
    assert response.test?
  end

  def test_failed_authorize_invalid_credit_card
    response = stub_comms do
      @gateway.purchase(@amount, @invalid_credit_card, @options)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal 'Declined', response.error_code
    assert_equal 'Invalid card number', response.message
    assert_equal 'Authorization', response.params['type']
    assert response.test?
  end

  def test_successful_capture
    response = stub_comms do
      @gateway.capture(@amount, '10000001625060|PaQLIYLRdWtcFKl5VaKTdUVxMutXJ5Ru', @options)
    end.respond_with(successful_capture_response)

    assert_success response
    assert_equal 'Approved', response.message
    assert_equal '10000001625061|PaQLIYLRdWtcFKl5VaKTdUVxMutXJ5Ru', response.authorization
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(@amount, 'bogus_authorization', @options)
    end.respond_with(failed_capture_response)

    assert_failure response
    assert_equal 'Declined', response.error_code
    assert_equal 'Original Transaction Not Found', response.message
    assert_equal nil, response.authorization
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void('bogus authorization')
    assert_failure response
    assert_equal 'Unauthorized', response.error_code
    assert_equal 'Original Payment Not Found Or You Do Not Have Access.', response.message
  end

  def test_successful_refund
    authorization = '86044396|PTp2WxLTXEP9Ml4DfDzTAbDWRaEFLKEM'
    response = stub_comms do
      @gateway.refund(544, authorization, @options)
    end.respond_with(successful_refund_response)

    assert_success response
    assert_equal @approval_message, response.message
    assert response.test?
  end

  def test_failed_duplicate_refund
    authorization = '86044396|PTp2WxLTXEP9Ml4DfDzTAbDWRaEFLKEM'
    response = stub_comms do
      @gateway.refund(544, authorization, @options)
    end.respond_with(failed_duplicate_refund)

    assert_failure response
    assert_equal 'Declined', response.error_code
    assert_equal 'Payment already refunded', response.message
    assert response.test?
  end

  def test_failed_get_payment_status
    @gateway.expects(:ssl_get).returns('Not Found')

    batch_check = @gateway.get_payment_status(123456)

    assert_failure batch_check
    assert_includes batch_check.message, 'Invalid JSON response'
    assert_includes batch_check.message, 'Not Found'
  end

  def test_purchase_passes_shipping_data
    options_with_shipping = @options.merge({ ship_to_country: 'USA', ship_to_zip: 27703, ship_amount: 0.01 })

    stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_shipping)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/shipAmount\":0.01/, data)
      assert_match(/shipToZip\":27703/, data)
      assert_match(/shipToCountry\":\"USA/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_passes_purchases_data
    purchases_data = {
      purchases: [
        {
          line_item_id: 79402,
          name: 'Book',
          description: 'The Elements of Style',
          quantity: 1,
          unit_price: 1.23,
          discount_amount: 0,
          extended_amount: '1.23',
          discount_rate: 0,
          tax_amount: 1
        }
      ]
    }
    options_with_purchases = @options.merge(purchases_data)

    stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_purchases)
    end.check_request do |_endpoint, data, _headers|
      purchase_item = purchases_data[:purchases].first
      purchase_object = JSON.parse(data)['purchases'].first

      assert_equal(purchase_item[:name], purchase_object['name'])
      assert_equal(purchase_item[:description], purchase_object['description'])
      assert_equal(purchase_item[:unit_price], purchase_object['unitPrice'])
      assert_equal(purchase_item[:quantity], purchase_object['quantity'])
      assert_equal(purchase_item[:tax_amount], purchase_object['taxAmount'])
      assert_equal(purchase_item[:discount_rate], purchase_object['discountRate'])
      assert_equal(purchase_item[:discount_amount], purchase_object['discountAmount'])
      assert_equal(purchase_item[:extended_amount], purchase_object['extendedAmount'])
      assert_equal(purchase_item[:line_item_id], purchase_object['lineItemId'])
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_passes_pos_data
    custom_pos_data = {
      pos_data: {
        cardholder_presence: 'NotPresent',
        device_attendance: 'Unknown',
        device_input_capability: 'KeyedOnly',
        device_location: 'Unknown',
        pan_capture_method: 'Manual',
        partial_approval_support: 'Supported',
        pin_capture_capability: 'Twelve'
      }
    }
    options_with_custom_pos_data = @options.merge(custom_pos_data)

    stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_custom_pos_data)
    end.check_request do |_endpoint, data, _headers|
      pos_data_object = JSON.parse(data)['posData']
      assert_equal(custom_pos_data[:pos_data][:cardholder_presence], pos_data_object['cardholderPresence'])
      assert_equal(custom_pos_data[:pos_data][:device_attendance], pos_data_object['deviceAttendance'])
      assert_equal(custom_pos_data[:pos_data][:device_input_capability], pos_data_object['deviceInputCapability'])
      assert_equal(custom_pos_data[:pos_data][:device_location], pos_data_object['deviceLocation'])
      assert_equal(custom_pos_data[:pos_data][:pan_capture_method], pos_data_object['panCaptureMethod'])
      assert_equal(custom_pos_data[:pos_data][:partial_approval_support], pos_data_object['partialApprovalSupport'])
      assert_equal(custom_pos_data[:pos_data][:pin_capture_capability], pos_data_object['pinCaptureCapability'])
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_duplicate_replay_id
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(replay_id: @replay_id))
    end.check_request do |_endpoint, data, _headers|
      assert_equal @replay_id, JSON.parse(data)['replayId']
    end.respond_with(successful_purchase_response_with_replay_id)
    assert_success response

    duplicate_response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(replay_id: response.params['replayId']))
    end.check_request do |_endpoint, data, _headers|
      assert_equal response.params['replayId'], JSON.parse(data)['replayId']
    end.respond_with(successful_purchase_response_with_replay_id)
    assert_success duplicate_response

    assert_equal response.params['id'], duplicate_response.params['id']
  end

  def test_failed_purchase_with_duplicate_replay_id
    response = stub_comms do
      @gateway.purchase(@amount, @invalid_credit_card, @options.merge(replay_id: @replay_id))
    end.respond_with(failed_purchase_response_with_replay_id)
    assert_failure response

    duplicate_response = stub_comms do
      @gateway.purchase(@amount, @invalid_credit_card, @options.merge(replay_id: response.params['replayId']))
    end.respond_with(failed_purchase_response_with_replay_id)
    assert_failure duplicate_response

    assert_equal response.params['id'], duplicate_response.params['id']
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def successful_refund_response
    %(
        {
            "created": "2021-08-03T04:11:24.51Z",
            "paymentToken": "PdSp5zrZBr0Jwx34gbEGoZHkPzWRxXBJ",
            "originalId": 10000001625073,
            "id": 10000001625074,
            "creatorName": "tester-api",
            "isDuplicate": false,
            "merchantId": 12345678,
            "batch": "0001",
            "batchId": 10000000227764,
            "tenderType": "Card",
            "currency": "USD",
            "amount": "-3.21",
            "cardAccount": {
                "cardType": "Visa",
                "entryMode": "Keyed",
                "last4": "1111",
                "cardId": "y15QvOteHZGBm7LH3GNIlTWbA1If",
                "token": "PdSp5zrZBr0Jwx34gbEGoZHkPzWRxXBJ",
                "expiryMonth": "02",
                "expiryYear": "29",
                "hasContract": false,
                "cardPresent": false,
                "isDebit": false,
                "isCorp": false
            },
            "posData": {
                "panCaptureMethod": "Manual"
            },
            "authOnly": false,
            "authCode": "PPSe8b",
            "status": "Approved",
            "risk": {},
            "requireSignature": false,
            "settledAmount": "0",
            "settledCurrency": "USD",
            "cardPresent": false,
            "authMessage": "Approved or completed successfully. ",
            "availableAuthAmount": "0",
            "reference": "121504000047",
            "tax": "0.04",
            "invoice": "V00KCLJT",
            "customerCode": "PTHHV00KCLJT",
            "shipToCountry": "USA",
            "purchases": [
                {
                    "dateCreated": "0001-01-01T00:00:00",
                    "iId": 0,
                    "transactionIId": 0,
                    "transactionId": "0",
                    "name": "Miscellaneous",
                    "description": "Miscellaneous",
                    "code": "MISC",
                    "unitOfMeasure": "EA",
                    "unitPrice": "3.17",
                    "quantity": 1,
                    "taxRate": "0.0126182965299684542586750789",
                    "taxAmount": "0.04",
                    "discountRate": "0",
                    "discountAmount": "0",
                    "extendedAmount": "3.21",
                    "lineItemId": 0
                }
            ],
            "clientReference": "PTHHV00KCLJT",
            "type": "Return",
            "taxExempt": false,
            "reviewIndicator": 0,
            "source": "Tester",
            "shouldGetCreditCardLevel": false
        }
    )
  end

  def failed_void_response
    '{
        "errorCode": "Unauthorized",
        "message": "Unauthorized",
        "details": [
            "Original Payment Not Found Or You Do Not Have Access."
        ],
        "responseCode": "eENKmhrToV9UYxsXAh7iGAQ"
      }'
  end

  def transcript
    '{
      "amount":"100",
      "currency":"USD",
      "email":"john@trexle.com",
      "ip_address":"66.249.79.118",
      "description":"Store Purchase 1437598192",
      "card":{
        "number":"5555555555554444",
        "expiry_month":9,
        "expiry_year":2017,
        "cvc":"123",
        "name":"Longbob Longsen",
        "address_line1":"456 My Street",
        "address_city":"Ottawa",
        "address_postcode":"K1C2N6",
        "address_state":"ON",
        "address_country":"CA"
      }
    }'
  end

  def scrubbed_transcript
    '{
      "amount":"100",
      "currency":"USD",
      "email":"john@trexle.com",
      "ip_address":"66.249.79.118",
      "description":"Store Purchase 1437598192",
      "card":{
        "number":"[FILTERED]",
        "expiry_month":9,
        "expiry_year":2017,
        "cvc":"[FILTERED]",
        "name":"Longbob Longsen",
        "address_line1":"456 My Street",
        "address_city":"Ottawa",
        "address_postcode":"K1C2N6",
        "address_state":"ON",
        "address_country":"CA"
      }
    }'
  end

  def successful_purchase_response
    %(
    {
      "created": "2021-07-25T12:54:37.327Z",
      "paymentToken": "Px0NmeG5uPe4xb9wQHq5WWHasBtIYloZ",
      "id": 10000001620265,
      "creatorName": "Mike B",
      "isDuplicate": false,
      "shouldVaultCard": true,
      "merchantId": 12345678,
      "batch": "0009",
      "batchId": 10000000227516,
      "tenderType": "Card",
      "currency": "USD",
      "amount": "9.87",
      "cardAccount": {
          "cardType": "Visa",
          "entryMode": "Keyed",
          "last4": "1111",
          "cardId": "y15QvOteHZGBm7LH3GNIlTWbA1If",
          "token": "Px0NmeG5uPe4xb9wQHq5WWHasBtIYloZ",
          "expiryMonth": "02",
          "expiryYear": "29",
          "hasContract": false,
          "cardPresent": false,
          "isDebit": false,
          "isCorp": false
      },
      "posData": {
          "panCaptureMethod": "Manual"
      },
      "authOnly": false,
      "authCode": "PPSe7b",
      "status": "Approved",
      "risk": {
          "cvvResponseCode": "M",
          "cvvResponse": "Match",
          "cvvMatch": true,
          "avsResponse": "No Response from AVS",
          "avsAddressMatch": false,
          "avsZipMatch": false
      },
      "requireSignature": false,
      "settledAmount": "0",
      "settledCurrency": "USD",
      "cardPresent": false,
      "authMessage": "Approved or completed successfully. ",
      "availableAuthAmount": "0",
      "reference": "120612000096",
      "tax": "0.12",
      "invoice": "V00554CJ",
      "customerCode": "PTHGV00554CJ",
      "shipToCountry": "USA",
      "purchases": [
          {
              "dateCreated": "0001-01-01T00:00:00",
              "iId": 0,
              "transactionIId": 0,
              "transactionId": "0",
              "name": "Miscellaneous",
              "description": "Miscellaneous",
              "code": "MISC",
              "unitOfMeasure": "EA",
              "unitPrice": "9.75",
              "quantity": 1,
              "taxRate": "0.0123076923076923076923076923",
              "taxAmount": "0.12",
              "discountRate": "0",
              "discountAmount": "0",
              "extendedAmount": "9.87",
              "lineItemId": 0
          }
      ],
      "clientReference": "PTHGV00554CJ",
      "type": "Sale",
      "taxExempt": false,
      "reviewIndicator": 1,
      "source": "Tester1",
      "shouldGetCreditCardLevel": false
  }
)
  end

  def successful_purchase_response_with_replay_id
    %(
      {
        "created": "2022-03-07T16:04:45.103Z",
        "paymentToken": "PuUfnYT8Tt8YlNmIce1wkQamcjmJymuB",
        "id": 86560202,
        "creatorName": "API Key",
        "replayId": #{@replay_id},
        "isDuplicate": false,
        "shouldVaultCard": false,
        "merchantId": 1000003310,
        "batch": "0032",
        "batchId": 10000000271187,
        "tenderType": "Card",
        "currency": "USD",
        "amount": "0.02",
        "cardAccount": {
          "cardType": "Visa",
          "entryMode": "Keyed",
          "last4": "1111",
          "cardId": "y15QvOteHZGBm7LH3GNIlTWbA1If",
          "token": "PuUfnYT8Tt8YlNmIce1wkQamcjmJymuB",
          "expiryMonth": "01",
          "expiryYear": "29",
          "hasContract": false,
          "cardPresent": false,
          "isDebit": false,
          "isCorp": false
        },
        "posData": {
          "panCaptureMethod": "Manual"
        },
        "authOnly": false,
        "authCode": "PPS9f4",
        "status": "Approved",
        "risk": {
          "cvvResponseCode": "N",
          "cvvResponse": "No Match",
          "cvvMatch": false,
          "avsResponseCode": "D",
          "avsAddressMatch": true,
          "avsZipMatch": true
        },
        "requireSignature": false,
        "settledAmount": "0",
        "settledCurrency": "USD",
        "cardPresent": false,
        "authMessage": "Approved or completed successfully",
        "availableAuthAmount": "0",
        "reference": "206616004772",
        "shipAmount": "0.01",
        "shipToZip": "55667",
        "shipToCountry": "USA",
        "purchases": [
          {
            "dateCreated": "0001-01-01T00:00:00",
            "iId": 0,
            "transactionIId": 0,
            "transactionId": "0",
            "name": "Anita",
            "description": "Dump",
            "unitPrice": "0",
            "quantity": 1,
            "taxRate": "0",
            "taxAmount": "0",
            "discountRate": "0",
            "discountAmount": "0",
            "extendedAmount": "0",
            "lineItemId": 0
          },
          {
            "dateCreated": "0001-01-01T00:00:00",
            "iId": 0,
            "transactionIId": 0,
            "transactionId": "0",
            "name": "Old Peculier",
            "description": "Beer",
            "unitPrice": "0",
            "quantity": 1,
            "taxRate": "0",
            "taxAmount": "0",
            "discountRate": "0",
            "discountAmount": "0",
            "extendedAmount": "0",
            "lineItemId": 0
          }
        ],
        "type": "Sale",
        "taxExempt": false,
        "reviewIndicator": 1,
        "source": "API",
        "shouldGetCreditCardLevel": false
      }
    )
  end

  def failed_purchase_response
    %(
    {
      "created": "2021-07-25T14:59:46.617Z",
      "paymentToken": "P3AmSeSyXQDRM0ioGlP05Q6ykRXXVaGx",
      "id": 10000001620267,
      "creatorName": "tester-api",
      "isDuplicate": false,
      "shouldVaultCard": true,
      "merchantId": 12345678,
      "batch": "0009",
      "batchId": 10000000227516,
      "tenderType": "Card",
      "currency": "USD",
      "amount": "411",
      "cardAccount": {
          "entryMode": "Keyed",
          "cardId": "B6R6ItScfvnUDwHWjP6ea1OUVX0f",
          "token": "P3AmSeSyXQDRM0ioGlP05Q6ykRXXVaGx",
          "expiryMonth": "01",
          "expiryYear": "29",
          "hasContract": false,
          "cardPresent": false
      },
      "posData": {
          "panCaptureMethod": "Manual"
      },
      "authOnly": false,
      "status": "Declined",
      "risk": {
          "avsResponse": "No Response from AVS",
          "avsAddressMatch": false,
          "avsZipMatch": false
      },
      "requireSignature": false,
      "settledAmount": "0",
      "settledCurrency": "USD",
      "cardPresent": false,
      "authMessage": "Invalid card number",
      "availableAuthAmount": "0",
      "reference": "120614000100",
      "tax": "0.05",
      "invoice": "V009M2JZ",
      "customerCode": "PTHGV009M2JZ",
      "purchases": [
          {
              "dateCreated": "0001-01-01T00:00:00",
              "iId": 0,
              "transactionIId": 0,
              "transactionId": "0",
              "name": "Miscellaneous",
              "description": "Miscellaneous",
              "code": "MISC",
              "unitOfMeasure": "EA",
              "unitPrice": "4.06",
              "quantity": 1,
              "taxRate": "0.0123152709359605911330049261",
              "taxAmount": "0.05",
              "discountRate": "0",
              "discountAmount": "0",
              "extendedAmount": "411",
              "lineItemId": 0
          }
      ],
      "clientReference": "PTHGV009M2JZ",
      "type": "Sale",
      "taxExempt": false,
      "source": "Tester",
      "shouldGetCreditCardLevel": false
  }
)
  end

  def failed_purchase_response_with_replay_id
    %(
      {
        "created": "2022-03-07T17:41:29.1Z",
        "paymentToken": "PKWMpiNtZ1mlUk4E4d95UWirHfQDNLwv",
        "id": 86560811,
        "creatorName": "API Key",
        "replayId": #{@replay_id},
        "isDuplicate": false,
        "shouldVaultCard": false,
        "merchantId": 1000003310,
        "batch": "0050",
        "batchId": 10000000271205,
        "tenderType": "Card",
        "currency": "USD",
        "amount": "0.02",
        "cardAccount": {
          "entryMode": "Keyed",
          "cardId": "B6R6ItScfvnUDwHWjP6ea1OUVX0f",
          "token": "PKWMpiNtZ1mlUk4E4d95UWirHfQDNLwv",
          "expiryMonth": "01",
          "expiryYear": "29",
          "hasContract": false,
          "cardPresent": false
        },
        "posData": {
          "panCaptureMethod": "Manual"
        },
        "authOnly": false,
        "status": "Declined",
        "risk": {
          "avsResponse": "No Response from AVS",
          "avsAddressMatch": false,
          "avsZipMatch": false
        },
        "requireSignature": false,
        "settledAmount": "0",
        "settledCurrency": "USD",
        "cardPresent": false,
        "authMessage": "Invalid card number",
        "availableAuthAmount": "0",
        "reference": "206617005381",
        "shipAmount": "0.01",
        "shipToZip": "55667",
        "shipToCountry": "USA",
        "purchases": [
          {
            "dateCreated": "0001-01-01T00:00:00",
            "iId": 0,
            "transactionIId": 0,
            "transactionId": "0",
            "name": "Anita",
            "description": "Dump",
            "unitPrice": "0",
            "quantity": 1,
            "taxRate": "0",
            "taxAmount": "0",
            "discountRate": "0",
            "discountAmount": "0",
            "extendedAmount": "0",
            "lineItemId": 0
          },
          {
            "dateCreated": "0001-01-01T00:00:00",
            "iId": 0,
            "transactionIId": 0,
            "transactionId": "0",
            "name": "Old Peculier",
            "description": "Beer",
            "unitPrice": "0",
            "quantity": 1,
            "taxRate": "0",
            "taxAmount": "0",
            "discountRate": "0",
            "discountAmount": "0",
            "extendedAmount": "0",
            "lineItemId": 0
          }
        ],
        "type": "Sale",
        "taxExempt": false,
        "source": "API",
        "shouldGetCreditCardLevel": false
      }
    )
  end

  def successful_authorize_response
    %(
      {
        "created": "2021-07-25T17:58:07.263Z",
        "paymentToken": "PkEcPvkJ9DloiT26r5u6GmXV8yIevwcp",
        "id": 10000001620268,
        "creatorName": "Mike B",
        "isDuplicate": false,
        "shouldVaultCard": true,
        "merchantId": 12345678,
        "tenderType": "Card",
        "currency": "USD",
        "amount": "3.32",
        "cardAccount": {
            "cardType": "Visa",
            "entryMode": "Keyed",
            "last4": "1111",
            "cardId": "y15QvOteHZGBm7LH3GNIlTWbA1If",
            "token": "PkEcPvkJ9DloiT26r5u6GmXV8yIevwcp",
            "expiryMonth": "02",
            "expiryYear": "29",
            "hasContract": false,
            "cardPresent": false,
            "isDebit": false,
            "isCorp": false
        },
        "posData": {
            "panCaptureMethod": "Manual"
        },
        "authOnly": true,
        "authCode": "PPS72f",
        "status": "Approved",
        "risk": {
            "cvvResponseCode": "M",
            "cvvResponse": "Match",
            "cvvMatch": true,
            "avsResponse": "No Response from AVS",
            "avsAddressMatch": false,
            "avsZipMatch": false
        },
        "requireSignature": false,
        "settledAmount": "0",
        "settledCurrency": "USD",
        "cardPresent": false,
        "authMessage": "Approved or completed successfully. ",
        "availableAuthAmount": "3.32",
        "reference": "120617000104",
        "invoice": "V00FZF87",
        "customerCode": "PTHGV00FZF87",
        "shipToCountry": "USA",
        "purchases": [
            {
                "dateCreated": "0001-01-01T00:00:00",
                "iId": 0,
                "transactionIId": 0,
                "transactionId": "0",
                "name": "Miscellaneous",
                "description": "Miscellaneous",
                "code": "MISC",
                "unitOfMeasure": "EA",
                "unitPrice": "3.32",
                "quantity": 1,
                "taxRate": "0",
                "taxAmount": "0",
                "discountRate": "0",
                "discountAmount": "0",
                "extendedAmount": "3.32",
                "lineItemId": 0
            }
        ],
        "clientReference": "PTHGV00FZF87",
        "type": "Authorization",
        "taxExempt": false,
        "reviewIndicator": 1,
        "source": "Tester1",
        "shouldGetCreditCardLevel": false
    }
    )
  end

  def failed_authorize_response
    %(
      {
        "created": "2021-07-25T20:32:47.84Z",
        "paymentToken": "PyzLzQBl8xAgjKYyrDfbA0Dbs39mopvN",
        "id": 10000001620269,
        "creatorName": "tester-api",
        "isDuplicate": false,
        "shouldVaultCard": true,
        "merchantId": 12345678,
        "tenderType": "Card",
        "currency": "USD",
        "amount": "411",
        "cardAccount": {
            "entryMode": "Keyed",
            "cardId": "B6R6ItScfvnUDwHWjP6ea1OUVX0f",
            "token": "PyzLzQBl8xAgjKYyrDfbA0Dbs39mopvN",
            "expiryMonth": "01",
            "expiryYear": "29",
            "hasContract": false,
            "cardPresent": false
        },
        "posData": {
            "panCaptureMethod": "Manual"
        },
        "authOnly": true,
        "status": "Declined",
        "risk": {
            "avsResponse": "No Response from AVS",
            "avsAddressMatch": false,
            "avsZipMatch": false
        },
        "requireSignature": false,
        "settledAmount": "0",
        "settledCurrency": "USD",
        "cardPresent": false,
        "authMessage": "Invalid card number",
        "availableAuthAmount": "411",
        "reference": "120620000107",
        "invoice": "V00LIC5Y",
        "customerCode": "PTHGV00LIC5Y",
        "purchases": [
            {
                "dateCreated": "0001-01-01T00:00:00",
                "iId": 0,
                "transactionIId": 0,
                "transactionId": "0",
                "name": "Miscellaneous",
                "description": "Miscellaneous",
                "code": "MISC",
                "unitOfMeasure": "EA",
                "unitPrice": "411",
                "quantity": 1,
                "taxRate": "0",
                "taxAmount": "0",
                "discountRate": "0",
                "discountAmount": "0",
                "extendedAmount": "411",
                "lineItemId": 0
            }
        ],
        "clientReference": "PTHGV00LIC5Y",
        "type": "Authorization",
        "taxExempt": false,
        "source": "Tester",
        "shouldGetCreditCardLevel": false
    }
    )
  end

  def successful_capture_response
    %(
        {
            "created": "2021-08-03T03:10:38.543Z",
            "paymentToken": "PaQLIYLRdWtcFKl5VaKTdUVxMutXJ5Ru",
            "originalId": 10000001625060,
            "id": 10000001625061,
            "creatorName": "tester-api",
            "isDuplicate": false,
            "merchantId": 12345678,
            "batch": "0016",
            "batchId": 10000000227758,
            "tenderType": "Card",
            "currency": "USD",
            "amount": "7.99",
            "cardAccount": {
                "cardType": "Visa",
                "entryMode": "Keyed",
                "last4": "1111",
                "cardId": "y15QvOteHZGBm7LH3GNIlTWbA1If",
                "token": "PaQLIYLRdWtcFKl5VaKTdUVxMutXJ5Ru",
                "expiryMonth": "01",
                "expiryYear": "29",
                "hasContract": false,
                "cardPresent": false,
                "isDebit": false,
                "isCorp": false
            },
            "posData": {
                "panCaptureMethod": "Manual"
            },
            "authOnly": false,
            "authCode": "PPSbf7",
            "status": "Approved",
            "risk": {},
            "requireSignature": false,
            "settledAmount": "0",
            "settledCurrency": "USD",
            "cardPresent": false,
            "authMessage": "Approved",
            "availableAuthAmount": "0",
            "reference": "121503000033",
            "tax": "0.1",
            "invoice": "V00ICCMR",
            "customerCode": "PTHHV00ICLFZ",
            "purchases": [
                {
                    "dateCreated": "0001-01-01T00:00:00",
                    "iId": 0,
                    "transactionIId": 0,
                    "transactionId": "0",
                    "name": "Miscellaneous",
                    "description": "Miscellaneous",
                    "code": "MISC",
                    "unitOfMeasure": "EA",
                    "unitPrice": "7.89",
                    "quantity": 1,
                    "taxRate": "0.0126742712294043092522179975",
                    "taxAmount": "0.1",
                    "discountRate": "0",
                    "discountAmount": "0",
                    "extendedAmount": "7.99",
                    "lineItemId": 0
                }
            ],
            "clientReference": "PTHHV00ICLFZ",
            "type": "SaleCompletion",
            "reviewIndicator": 0,
            "source": "Tester",
            "shouldGetCreditCardLevel": false
        }
    )
  end

  def failed_capture_response
    %(
      {"created":"2022-04-06T16:54:08.9Z","paymentToken":"PHubmbgcqEPVUI2HmOAr2sF7Vl33MnuJ","id":86777943,"creatorName":"API Key","isDuplicate":false,"merchantId":12345678,"batch":"0028","batchId":10000000272426,"tenderType":"Card","currency":"USD","amount":"0.02","cardAccount":{"token":"PHubmbgcqEPVUI2HmOAr2sF7Vl33MnuJ","hasContract":false,"cardPresent":false},"posData":{"panCaptureMethod":"Manual"},"authOnly":false,"status":"Declined","risk":{},"requireSignature":false,"settledAmount":"0","settledCurrency":"USD","cardPresent":false,"authMessage":"Original Transaction Not Found","availableAuthAmount":"0","reference":"209616004816","type":"Sale","source":"API","shouldGetCreditCardLevel":false}
    )
  end

  def successful_void_response
    %(
      #<Net::HTTPNoContent 204 No Content readbody=true>
    )
  end

  def successful_refund_purchase_response
    %(
      {
        "created": "2021-07-27T02:14:55.477Z",
        "paymentToken": "PU2QSwaBlKx5OEzBKavi1L0Dy9yIMSEx",
        "originalId": 10000001620800,
        "id": 10000001620801,
        "creatorName": "Mike B",
        "isDuplicate": false,
        "merchantId": 12345678,
        "batch": "0001",
        "batchId": 10000000227556,
        "tenderType": "Card",
        "currency": "USD",
        "amount": "-14.14",
        "cardAccount": {
            "cardType": "Visa",
            "entryMode": "Keyed",
            "last4": "1111",
            "cardId": "y15QvOteHZGBm7LH3GNIlTWbA1If",
            "token": "PU2QSwaBlKx5OEzBKavi1L0Dy9yIMSEx",
            "expiryMonth": "02",
            "expiryYear": "29",
            "hasContract": false,
            "cardPresent": false,
            "isDebit": false,
            "isCorp": false
        },
        "posData": {
            "panCaptureMethod": "Manual"
        },
        "authOnly": false,
        "authCode": "PPS39c",
        "status": "Approved",
        "risk": {},
        "requireSignature": false,
        "settledAmount": "0",
        "settledCurrency": "USD",
        "cardPresent": false,
        "authMessage": "Approved or completed successfully. ",
        "availableAuthAmount": "0",
        "reference": "120802000004",
        "tax": "0.17",
        "invoice": "Z00C02TD",
        "customerCode": "PTHGZ00C02TD",
        "shipToCountry": "USA",
        "purchases": [
            {
                "dateCreated": "0001-01-01T00:00:00",
                "iId": 11042381,
                "transactionIId": 0,
                "transactionId": "10000001620800",
                "name": "Miscellaneous",
                "description": "Miscellaneous",
                "code": "MISC",
                "unitOfMeasure": "EA",
                "unitPrice": "13.97",
                "quantity": 1,
                "taxRate": "0.01",
                "taxAmount": "0.17",
                "discountRate": "0",
                "discountAmount": "0",
                "extendedAmount": "14.14",
                "lineItemId": 0
            }
        ],
        "clientReference": "PTHGZ00C02TD",
        "type": "Return",
        "taxExempt": false,
        "reviewIndicator": 0,
        "source": "Tester",
        "shouldGetCreditCardLevel": false
    }
    )
  end

  def failed_duplicate_refund
    %(
      {
        "created": "2021-07-27T04:35:58.397Z",
        "paymentToken": "P9cjoRNccieQXBmDxEmXi2NjLKWtVF9A",
        "originalId": 10000001620798,
        "id": 10000001620802,
        "creatorName": "tester-api",
        "isDuplicate": false,
        "merchantId": 12345678,
        "batch": "0001",
        "batchId": 10000000227556,
        "tenderType": "Card",
        "currency": "USD",
        "amount": "-14.14",
        "cardAccount": {
            "cardType": "Visa",
            "entryMode": "Keyed",
            "last4": "1111",
            "cardId": "y15QvOteHZGBm7LH3GNIlTWbA1If",
            "token": "P9cjoRNccieQXBmDxEmXi2NjLKWtVF9A",
            "expiryMonth": "02",
            "expiryYear": "29",
            "hasContract": false,
            "cardPresent": false,
            "isDebit": false,
            "isCorp": false
        },
        "posData": {
            "panCaptureMethod": "Manual"
        },
        "authOnly": false,
        "authCode": "PPSdda",
        "status": "Declined",
        "risk": {},
        "requireSignature": false,
        "settledAmount": "0",
        "settledCurrency": "USD",
        "cardPresent": false,
        "authMessage": "Payment already refunded",
        "availableAuthAmount": "0",
        "reference": "120804000007",
        "tax": "0.17",
        "invoice": "Z001MFP5",
        "customerCode": "PTHGZ001MFP5",
        "shipToCountry": "USA",
        "purchases": [
            {
                "dateCreated": "0001-01-01T00:00:00",
                "iId": 0,
                "transactionIId": 0,
                "transactionId": "0",
                "name": "Miscellaneous",
                "description": "Miscellaneous",
                "code": "MISC",
                "unitOfMeasure": "EA",
                "unitPrice": "13.97",
                "quantity": 1,
                "taxRate": "0.0121689334287759484609878311",
                "taxAmount": "0.17",
                "discountRate": "0",
                "discountAmount": "0",
                "extendedAmount": "14.14",
                "lineItemId": 0
            }
        ],
        "clientReference": "PTHGZ001MFP5",
        "type": "Return",
        "taxExempt": false,
        "source": "Tester",
        "shouldGetCreditCardLevel": false
      }
    )
  end

  def pre_scrubbed
    %(
      {\"achIndicator\":null,\"amount\":2.11,\"authCode\":null,\"authOnly\":false,\"bankAccount\":null,\"cardAccount\":{\"avsStreet\":\"1\",\"avsZip\":\"88888\",\"cvv\":\"123\",\"entryMode\":\"Keyed\",\"expiryDate\":\"01/29\",\"expiryMonth\":\"01\",\"expiryYear\":\"29\",\"last4\":null,\"magstripe\":null,\"number\":\"4111111111111111\"},\"cardPresent\":false,\"cardPresentType\":\"CardNotPresent\",\"isAuth\":true,\"isSettleFunds\":true,\"isTicket\":false,\"merchantId\":12345678,\"mxAdvantageEnabled\":false,\"mxAdvantageFeeLabel\":\"\",\"paymentType\":\"Sale\",\"purchases\":[{\"taxRate\":\"0.0000\",\"additionalTaxRate\":null,\"discountRate\":null}],\"shouldGetCreditCardLevel\":true,\"shouldVaultCard\":true,\"source\":\"Tester\",\"sourceZip\":\"K1C2N6\",\"taxExempt\":false,\"tenderType\":\"Card\",\"terminals\":[]}
     )
  end

  def post_scrubbed
    %(
      {\"achIndicator\":null,\"amount\":2.11,\"authCode\":null,\"authOnly\":false,\"bankAccount\":null,\"cardAccount\":{\"avsStreet\":\"1\",\"avsZip\":\"88888\",\"cvv\":\"[FILTERED]\",\"entryMode\":\"Keyed\",\"expiryDate\":\"01/29\",\"expiryMonth\":\"01\",\"expiryYear\":\"29\",\"last4\":null,\"magstripe\":null,\"number\":\"[FILTERED]\"},\"cardPresent\":false,\"cardPresentType\":\"CardNotPresent\",\"isAuth\":true,\"isSettleFunds\":true,\"isTicket\":false,\"merchantId\":12345678,\"mxAdvantageEnabled\":false,\"mxAdvantageFeeLabel\":\"\",\"paymentType\":\"Sale\",\"purchases\":[{\"taxRate\":\"0.0000\",\"additionalTaxRate\":null,\"discountRate\":null}],\"shouldGetCreditCardLevel\":true,\"shouldVaultCard\":true,\"source\":\"Tester\",\"sourceZip\":\"K1C2N6\",\"taxExempt\":false,\"tenderType\":\"Card\",\"terminals\":[]}
     )
  end
end
