require 'test_helper'
class PriorityTest < Test::Unit::TestCase
  include CommStub

  def setup
    # run command below to run tests in debug (byebug)
    # byebug -Itest test/unit/gateways/priority_test.rb

    @gateway = PriorityGateway.new(fixtures(:priority))

    @action = 'purchase'
    @amount = 3.33
    @merchant = 1000003310
    @is_settle_funds_purchase = true
    @is_settle_funds_auth = false
    @credit_card_purchase = {
      avsStreet: '1',
      avsZip: '55044',
      cvv: '123',
      entryMode: 'Keyed',
      expiryDate: '01/29',
      expiryMonth: '01',
      expiryYear: '29',
      last4: nil,
      magstripe: nil,
      number: '4111111111111111'
    }
    # Refund params
    @reference_refund = '118819000095'
    @amount_refund = -9.51

    @iid = '10000001610661'
    @cardnumber_verify = '4111111111111111'

    @credit_card_refund = {
      cardId: 'y15QvOteHZGBm7LH3GNIlTWbA1If',
      cardPresent: false,
      cardType: 'Visa',
      entryMode: 'Keyed',
      expiryMonth: '02',
      expiryYear: '29',
      hasContract: false,
      isCorp: false,
      isDebit: false,
      last4: '1111',
      token: 'P6NyKC5UfmZjgAlF3ZEd3YSaJG9qKT6E'
    }

    @response_purchase = {
      "created": '2021-07-27T02:01:52.003Z',
        "paymentToken": 'P3hhDiddFRFTlsa8xmv7LHBGK9aI70UR',
        "id": 10000001620800,
        "creatorName": 'Mike B',
        "isDuplicate": false,
        "shouldVaultCard": true,
        "merchantId": 1000003310,
        "batch": '0033',
        "batchId": 10000000227555,
        "tenderType": 'Card',
        "currency": 'USD',
        "amount": '14.14',
        "cardAccount": {
          "cardType": 'Visa',
            "entryMode": 'Keyed',
            "last4": '9898',
            "cardId": 'y15QvOteHZGBm7LH3GNIlTWbA1If',
            "token": 'P3hhDiddFRFTlsa8xmv7LHBGK9aI70UR',
            "expiryMonth": '02',
            "expiryYear": '29',
            "hasContract": false,
            "cardPresent": false,
            "isDebit": false,
            "isCorp": false
        },
        "posData": {
          "panCaptureMethod": 'Manual'
        },
        "authOnly": false,
        "authCode": 'PPSc72',
        "status": 'Approved',
        "risk": {
          "cvvResponseCode": 'M',
            "cvvResponse": 'Match',
            "cvvMatch": true,
            "avsResponse": 'No Response from AVS',
            "avsAddressMatch": false,
            "avsZipMatch": false
        },
        "requireSignature": false,
        "settledAmount": '0',
        "settledCurrency": 'USD',
        "cardPresent": false,
        "authMessage": 'Approved or completed successfully. ',
        "availableAuthAmount": '0',
        "reference": '120802000003',
        "tax": '0.17',
        "invoice": 'Z00C02TD',
        "customerCode": 'PTHGZ00C02TD',
        "shipToCountry": 'USA',
        "purchases": [
          {
            "dateCreated": '0001-01-01T00:00:00',
              "iId": 0,
              "transactionIId": 0,
              "transactionId": '0',
              "name": 'Miscellaneous',
              "description": 'Miscellaneous',
              "code": 'MISC',
              "unitOfMeasure": 'EA',
              "unitPrice": '13.97',
              "quantity": 1,
              "taxRate": '0.0121689334287759484609878311',
              "taxAmount": '0.17',
              "discountRate": '0',
              "discountAmount": '0',
              "extendedAmount": '14.14',
              "lineItemId": 0
          }
        ],
        "clientReference": 'PTHGZ00C02TD',
        "type": 'Sale',
        "taxExempt": false,
        "reviewIndicator": 1,
        "source": 'Tester1',
        "shouldGetCreditCardLevel": false
    }

    @request_params = {
      achIndicator: nil,
      amount: 5.44,
      authCode: nil,
      authOnly: false,
      bankAccount: nil,
      cardPresent: false,
      cardPresentType: 'CardNotPresent',
      isAuth: true,
      isSettleFunds: true,
      isTicket: false,
      merchantId: 514_391_592,
      mxAdvantageEnabled: false,
      mxAdvantageFeeLabel: '',
      paymentType: 'Sale',
      purchases: [{ taxRate: '0.0000', additionalTaxRate: nil, discountRate: nil }],
      shouldGetCreditCardLevel: true,
      shouldVaultCard: true,
      source: 'Tester1',
      sourceZip: '94102',
      taxExempt: false,
      tenderType: 'Card',
      terminals: []
    }

    # purchase params success
    @amount_purchase = 4.11
    @credit_card_purchase_success = credit_card('4111111111111111', month: '01', year: '2029', first_name: 'Marcus', last_name: 'Rashford', verification_value: '123')

    # Note the 'avsStreet' and 'avsZip' are the values obtained from credit card input on MX Merchant
    @option_spr = {
      billing_address: address,
      avsStreet: '666',
      avsZip: '55044'
    }

    # purchase params fail
    @credit_card_purchase_fail = credit_card('4111', month: '01', year: '2029', first_name: 'Marcus', last_name: 'Rashford', verification_value: '123')
    # purchase params fail end

    # authorize params success
    @amount_authorize = 7.99

    setup_options_hashes
  end

  def setup_options_hashes
    @option_purchase = {
      cardPresent: false,
      cardPresentType: 'CardNotPresent',
      isAuth: true,
      isSettleFunds: @is_settle_funds_purchase,
      isTicket: nil,

      merchantId: @merchant,
      mxAdvantageEnabled: false,
      mxAdvantageFeeLabel: '',
      paymentType: 'Sale',
      bankAccount: nil,

      purchases: [
        {
          taxRate: 0.0000,
          additionalTaxRate: nil,
          discountRate: nil
        }
      ],

      shouldGetCreditCardLevel: true,
      shouldVaultCard: true,
      source: 'Tester1',
      sourceZip: '94102',
      taxExempt: false,
      tenderType: 'Card',
      terminals: []
    }
    # Options  - A standard ActiveMerchant options hash:
    @options_refund = {
      cardPresent: false,
      clientReference: 'PTHER000IKZK',
      created: '2021-07-01T19:01:57.69Z',
      creatorName: 'Mike Saylor',
      currency: 'USD',
      customerCode: 'PTHER000IKZK',
      enteredAmount: 9.51,
      id: nil,
      invoice: 'R000IKZK',
      isDuplicate: false,
      merchantId: @merchant,
      paymentToken: 'P6NyKC5UfmZjgAlF3ZEd3YSaJG9qKT6E',

      posData: { panCaptureMethod: 'Manual' },

      purchases: [
        {
          code: 'MISC',
          dateCreated: '0001-01-01T00:00:00',
          description: 'Miscellaneous',
          discountAmount: '0',
          discountRate: '0',
          extendedAmount: '9.51',
          iId: '11036546',
          lineItemId: 0,
          name: 'Miscellaneous',
          quantity: '1',
          taxAmount: '0.2',
          taxRate: '0.01',
          transactionIId: 0,
          transactionId: '10000001610620',
          unitOfMeasure: 'EA',
          unitPrice: '1.51'
        }
      ],
      reference: @reference_refund,
      replayId: nil,
      requireSignature: false,
      reviewIndicator: nil,

      risk: {
        avsAddressMatch: false,
        avsResponse: 'No Response from AVS',
        avsZipMatch: false,
        cvvMatch: true,
        cvvResponse: 'Match',
        cvvResponseCode: 'M'
      },

      settledAmount: '0',
      settledCurrency: 'USD',
      settledDate: '2021-07-01T19:02:21.553',
      shipToCountry: 'USA',
      shouldGetCreditCardLevel: true,
      source: 'Tester1',
      sourceZip: '94102',
      status: 'Settled',
      tax: '0.12',
      taxExempt: false,
      tenderType: 'Card',
      type: 'Sale'
    }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount_purchase, @credit_card_purchase_success, @option_spr)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'Approved', response.params['status']
    assert_equal 'Sale', response.params['type']

    assert response.test?
  end

  def test_failed_purchase_invalid_creditcard
    response = stub_comms do
      @gateway.purchase(@amount_purchase, @credit_card_purchase_fail, @option_spr)
    end.respond_with(failed_purchase_response)

    assert_success response
    assert_equal 'Declined', response.params['status']

    assert_equal 'Invalid card number', response.params['authMessage']
    assert response.test?
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card_purchase_success, @option_spr)
    end.respond_with(successful_authorize_response)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'Approved', response.params['status']
    assert_equal 'Authorization', response.params['type']
    assert response.test?
  end

  def test_failed_authorize_invalid_creditcard
    response = stub_comms do
      @gateway.purchase(@amount_purchase, @credit_card_purchase_fail, @option_spr)
    end.respond_with(failed_authorize_response)

    assert_success response
    assert_equal 'Declined', response.params['status']

    assert_equal 'Invalid card number', response.params['authMessage']
    assert_equal 'Authorization', response.params['type']
    assert response.test?
  end

  def test_successful_capture
    response = stub_comms do
      @gateway.capture(@amount_authorize, 'authobj', @option_spr)
    end.respond_with(successful_capture_response)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'PaQLIYLRdWtcFKl5VaKTdUVxMutXJ5Ru', response.authorization
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(@amount_authorize, 'bogus', {})
    end.respond_with(failed_capture_response)
    assert_failure response
    assert_equal 'Validation error happened', response.params['message']
    assert_equal nil, response.authorization
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void(123456, @option_spr)
    end.respond_with(failed_void_response)

    assert_failure response

    assert_equal 'Unauthorized', response.params['message']

    assert_equal 'Original Payment Not Found Or You Do Not Have Access.', response.params['details'][0]
  end

  def test_successful_refund_purchase_response
    @response_string_obj = @response_purchase.transform_keys(&:to_s)
    @amount_refund = @response_string_obj['amount'].to_f * -1
    @credit_card = @response_string_obj['cardAccount'].transform_keys(&:to_s)
    @response_string_obj['cardAccount'] = @response_string_obj['cardAccount'].transform_keys(&:to_s)
    @response_string_obj['posData'] = @response_string_obj['posData'].transform_keys(&:to_s)
    @response_string_obj['purchases'][0] = @response_string_obj['purchases'][0].transform_keys(&:to_s)
    @response_string_obj['risk'] = @response_string_obj['risk'].transform_keys(&:to_s)
    @response_string_obj['source'] = 'Tester'

    response = stub_comms do
      @gateway.refund(@amount_refund, @credit_card, @response_string_obj)
    end.check_request do |_endpoint, data, _headers|
      json = JSON.parse(data)

      assert_equal json['amount'], @amount_refund
      assert_credit_card_data_passed(data, @credit_card)
      assert_refund_data_passed(data, @response_string_obj)
    end.respond_with(successful_refund_purchase_response)
    assert_success response
    assert_equal 'PU2QSwaBlKx5OEzBKavi1L0Dy9yIMSEx', response.authorization
    assert response.test?
  end

  def test_successful_refund
    @response_string_obj = @response_purchase.transform_keys(&:to_s)
    @amount_refund = @response_string_obj['amount'].to_f * -1
    @credit_refund = @response_string_obj['cardAccount'].transform_keys(&:to_s)
    @response_string_obj['cardAccount'] = @response_string_obj['cardAccount'].transform_keys(&:to_s)
    response = stub_comms do
      @gateway.refund(@amount_refund, @credit_refund, @response_string_obj)
    end.respond_with(successful_refund_response)
    assert_success response
    assert_equal 'Approved', response.params['status']
    assert_equal 'Approved or completed successfully. ', response.params['authMessage']
    assert response.test?
  end

  # Payment already refunded
  def test_failed_refund_purchase_response
    @response_string_obj = @response_purchase.transform_keys(&:to_s)
    @amount_refund = @response_string_obj['amount'].to_f * -1
    @credit_refund = @response_string_obj['cardAccount'].transform_keys(&:to_s)
    @response_string_obj['cardAccount'] = @response_string_obj['cardAccount'].transform_keys(&:to_s)

    response = stub_comms do
      @gateway.refund(@amount_refund, @credit_refund, @response_string_obj)
    end.respond_with(failed_refund_purchase_response)
    assert_success response
    assert_equal 'Declined', response.params['status']
    assert_equal 'Payment already refunded', response.params['authMessage']
    assert response.test?
  end

  def test_get_payment_status
    # check is this transaction associated batch is "Closed".
    batchcheck = @gateway.get_payment_status(123456, @option_spr)

    assert_failure batchcheck
    assert_equal 'Invalid JSON response', batchcheck.params['message'][0..20]
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
            "merchantId": 1000003310,
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

  def assert_credit_card_data_passed(data, credit_card)
    parsed_data = JSON.parse(data)
    card_data = parsed_data['cardAccount']

    assert_equal card_data['cardType'], credit_card['cardType']
    assert_equal card_data['entryMode'], credit_card['entryMode']

    assert_equal card_data['last4'], credit_card['last4']
    assert_equal card_data['cardId'], credit_card['cardId']
    assert_equal card_data['token'], credit_card['token']
    assert_equal card_data['expiryMonth'], credit_card['expiryMonth']
    assert_equal card_data['expiryYear'], credit_card['expiryYear']
    assert_equal card_data['hasContract'], credit_card['hasContract']

    assert_equal card_data['cardPresent'], credit_card['cardPresent']
    assert_equal card_data['isDebit'], credit_card['isDebit']
    assert_equal card_data['isCorp'], credit_card['isCorp']
  end

  def assert_refund_data_passed(data, purchase_resp)
    parsed_data = JSON.parse(data)

    assert_equal parsed_data['cardPresent'], purchase_resp['cardPresent']
    assert_equal parsed_data['clientReference'], purchase_resp['clientReference']
    assert_equal parsed_data['created'], purchase_resp['created']
    assert_equal parsed_data['creatorName'], purchase_resp['creatorName']
    assert_equal parsed_data['currency'], purchase_resp['currency']
    assert_equal parsed_data['customerCode'], purchase_resp['customerCode']
    assert_equal parsed_data['enteredAmount'], purchase_resp['amount']
    assert_equal parsed_data['id'], 0
    assert_equal parsed_data['invoice'], purchase_resp['invoice']
    assert_equal parsed_data['isDuplicate'], false
    assert_equal parsed_data['merchantId'], purchase_resp['merchantId'].to_s
    assert_equal parsed_data['paymentToken'], purchase_resp['cardAccount']['token']

    pos_data = parsed_data['posData']
    purchase_resp_pos_data = purchase_resp['posData']

    assert_equal pos_data['panCaptureMethod'], purchase_resp_pos_data['panCaptureMethod']

    purchases_data = parsed_data['purchases'][0]
    purchase_resp_purchase = purchase_resp['purchases'][0]

    assert_equal purchases_data['code'], purchase_resp_purchase['code']
    assert_equal purchases_data['dateCreated'], purchase_resp_purchase['dateCreated']
    assert_equal purchases_data['description'], purchase_resp_purchase['description']
    assert_equal purchases_data['discountAmount'], purchase_resp_purchase['discountAmount']
    assert_equal purchases_data['discountRate'], purchase_resp_purchase['discountRate']
    assert_equal purchases_data['extendedAmount'], purchase_resp_purchase['extendedAmount']
    assert_equal purchases_data['iId'], purchase_resp_purchase['iId']
    assert_equal purchases_data['lineItemId'], purchase_resp_purchase['lineItemId']
    assert_equal purchases_data['name'], purchase_resp_purchase['name']
    assert_equal purchases_data['quantity'], purchase_resp_purchase['quantity']
    assert_equal purchases_data['taxAmount'], purchase_resp_purchase['taxAmount']
    assert_equal purchases_data['taxRate'], purchase_resp_purchase['taxRate']
    assert_equal purchases_data['transactionIId'], purchase_resp_purchase['transactionIId']
    assert_equal purchases_data['transactionId'], purchase_resp_purchase['transactionId']
    assert_equal purchases_data['unitOfMeasure'], purchase_resp_purchase['unitOfMeasure']
    assert_equal purchases_data['unitPrice'], purchase_resp_purchase['unitPrice']

    assert_equal parsed_data['reference'], purchase_resp['reference']
    assert_equal parsed_data['replayId'], nil
    assert_equal parsed_data['requireSignature'], false
    assert_equal parsed_data['reviewIndicator'], nil

    risk_data = parsed_data['risk']
    purchase_resp_risk = purchase_resp['risk']

    assert_equal risk_data['avsAddressMatch'], purchase_resp_risk['avsAddressMatch']
    assert_equal risk_data['avsResponse'], purchase_resp_risk['avsResponse']
    assert_equal risk_data['avsZipMatch'], purchase_resp_risk['avsZipMatch']
    assert_equal risk_data['cvvMatch'], purchase_resp_risk['cvvMatch']
    assert_equal risk_data['cvvResponse'], purchase_resp_risk['cvvResponse']
    assert_equal risk_data['cvvResponseCode'], purchase_resp_risk['cvvResponseCode']

    assert_equal parsed_data['settledAmount'], purchase_resp['settledAmount']
    assert_equal parsed_data['settledCurrency'], purchase_resp['settledCurrency']
    assert_equal parsed_data['settledDate'], purchase_resp['created']
    assert_equal parsed_data['shipToCountry'], purchase_resp['shipToCountry']
    assert_equal parsed_data['shouldGetCreditCardLevel'], purchase_resp['shouldGetCreditCardLevel']
    assert_equal parsed_data['source'], 'Tester'
    assert_equal parsed_data['sourceZip'], nil
    assert_equal parsed_data['status'], purchase_resp['status']
    assert_equal parsed_data['tax'], purchase_resp['tax']
    assert_equal parsed_data['taxExempt'], purchase_resp['taxExempt']
    assert_equal parsed_data['tenderType'], 'Card'
    assert_equal parsed_data['type'], purchase_resp['type']
  end

  def failed_void_response
    %(
      {
        "errorCode": "Unauthorized",
        "message": "Unauthorized",
        "details": [
            "Original Payment Not Found Or You Do Not Have Access."
        ],
        "responseCode": "egYl4vLdB6WIk4ocQBuIPvA"
    }
    )
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
      "merchantId": 1000003310,
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

  def failed_purchase_response
    %(
    {
      "created": "2021-07-25T14:59:46.617Z",
      "paymentToken": "P3AmSeSyXQDRM0ioGlP05Q6ykRXXVaGx",
      "id": 10000001620267,
      "creatorName": "tester-api",
      "isDuplicate": false,
      "shouldVaultCard": true,
      "merchantId": 1000003310,
      "batch": "0009",
      "batchId": 10000000227516,
      "tenderType": "Card",
      "currency": "USD",
      "amount": "4.11",
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
              "extendedAmount": "4.11",
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

  def successful_authorize_response
    %(
      {
        "created": "2021-07-25T17:58:07.263Z",
        "paymentToken": "PkEcPvkJ9DloiT26r5u6GmXV8yIevwcp",
        "id": 10000001620268,
        "creatorName": "Mike B",
        "isDuplicate": false,
        "shouldVaultCard": true,
        "merchantId": 1000003310,
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
        "merchantId": 1000003310,
        "tenderType": "Card",
        "currency": "USD",
        "amount": "4.11",
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
        "availableAuthAmount": "4.11",
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
                "unitPrice": "4.11",
                "quantity": 1,
                "taxRate": "0",
                "taxAmount": "0",
                "discountRate": "0",
                "discountAmount": "0",
                "extendedAmount": "4.11",
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
            "merchantId": 1000003310,
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
      {
        "errorCode": "ValidationError",
        "message": "Validation error happened",
        "details": [
            "merchantId required"
        ],
        "responseCode": "eENKmhrToV9UYxsXAh7iGAQ"
    }
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
        "merchantId": 1000003310,
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

  def failed_refund_purchase_response
    %(
      {
        "created": "2021-07-27T04:35:58.397Z",
        "paymentToken": "P9cjoRNccieQXBmDxEmXi2NjLKWtVF9A",
        "originalId": 10000001620798,
        "id": 10000001620802,
        "creatorName": "tester-api",
        "isDuplicate": false,
        "merchantId": 1000003310,
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
      {\"achIndicator\":null,\"amount\":2.11,\"authCode\":null,\"authOnly\":false,\"bankAccount\":null,\"cardAccount\":{\"avsStreet\":\"1\",\"avsZip\":\"88888\",\"cvv\":\"123\",\"entryMode\":\"Keyed\",\"expiryDate\":\"01/29\",\"expiryMonth\":\"01\",\"expiryYear\":\"29\",\"last4\":null,\"magstripe\":null,\"number\":\"4111111111111111\"},\"cardPresent\":false,\"cardPresentType\":\"CardNotPresent\",\"isAuth\":true,\"isSettleFunds\":true,\"isTicket\":false,\"merchantId\":1000003310,\"mxAdvantageEnabled\":false,\"mxAdvantageFeeLabel\":\"\",\"paymentType\":\"Sale\",\"purchases\":[{\"taxRate\":\"0.0000\",\"additionalTaxRate\":null,\"discountRate\":null}],\"shouldGetCreditCardLevel\":true,\"shouldVaultCard\":true,\"source\":\"Tester\",\"sourceZip\":\"K1C2N6\",\"taxExempt\":false,\"tenderType\":\"Card\",\"terminals\":[]}
     )
  end

  def post_scrubbed
    %(
      {\"achIndicator\":null,\"amount\":2.11,\"authCode\":null,\"authOnly\":false,\"bankAccount\":null,\"cardAccount\":{\"avsStreet\":\"1\",\"avsZip\":\"88888\",\"cvv[FILTERED]\",\"entryMode\":\"Keyed\",\"expiryDate\":\"01/29\",\"expiryMonth\":\"01\",\"expiryYear\":\"29\",\"last4\":null,\"magstripe\":null,\"number[FILTERED]\"},\"cardPresent\":false,\"cardPresentType\":\"CardNotPresent\",\"isAuth\":true,\"isSettleFunds\":true,\"isTicket\":false,\"merchantId\":1000003310,\"mxAdvantageEnabled\":false,\"mxAdvantageFeeLabel\":\"\",\"paymentType\":\"Sale\",\"purchases\":[{\"taxRate\":\"0.0000\",\"additionalTaxRate\":null,\"discountRate\":null}],\"shouldGetCreditCardLevel\":true,\"shouldVaultCard\":true,\"source\":\"Tester\",\"sourceZip\":\"K1C2N6\",\"taxExempt\":false,\"tenderType\":\"Card\",\"terminals\":[]}
     )
  end
end
