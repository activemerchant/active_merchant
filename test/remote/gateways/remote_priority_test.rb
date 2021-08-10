require 'test_helper'
require 'byebug'

class RemotePriorityTest < Test::Unit::TestCase
  def setup
    # Consumer API Key: Generated in MX Merchant for specific test merchant
    # Consumer API Secret:= Generated in MX Merchant for specific test merchant

    # run command below to run tests in debug (byebug)
    # byebug -Itest test/unit/gateways/card_stream_test.rb
    #
    # bundle exec rake test:remote TEST=test/remote/gateways/remote_priority_test.rb
    # ruby -Itest test/unit/gateways/priority_test.rb -n test_successful_void

    # Run specific remote test
    # ruby -Itest test/remote/gateways/remote_priority_test.rb -n test_fail_refund_already_refunded_purchase_response
    @gateway = PriorityGateway.new(fixtures(:priority))

    # byebug

    # purchase params success
    @amount_purchase = 2.11
    @credit_card_purchase_success = credit_card('4111111111111111', month: '01', year: '2029', first_name: 'Marcus', last_name: 'Rashford', verification_value: '123')
    @option_spr = {
      merchant: 514391592,
      billing_address: address,
      key: 'Generated in MX Merchant for specific test merchant',
      secret: 'Generated in MX Merchant for specific test merchant'
    }
    # purchase params success end

    # purchase params fail inavalid card number
    @credit_card_purchase_fail_invalid_number = credit_card('4111', month: '01', year: '2029', first_name: 'Marcus', last_name: 'Rashford', verification_value: '123')

    # purchase params fail missing card number month
    @credit_card_purchase_fail_missing_month = credit_card('4111111111111111', month: '', year: '2029', first_name: 'Marcus', last_name: 'Rashford', verification_value: '123')

    # purchase params fail missing card verification number
    @credit_card_purchase_fail_missing_verification = credit_card('4111111111111111', month: '01', year: '2029', first_name: 'Marcus', last_name: 'Rashford', verification_value: '')

    # purchase params fail end

    # authorize params success
    @amount_authorize = 7.99
    # authorize params success end

    # verify params
    @iid = '10000001617842'
    @cardnumber_verify = '4111111111111111'
    # verify params end

    # Refund params
    @amount_refund = -4.32
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
      token: 'P4A4gziiGpRgiHyAec1rl1FLafaVUMY6'
    }
    @authCode_refund = 'PPS16f'

    # Used by Refund tests
    @response_purchase = {
      "created": '2021-08-09T17:14:35.453Z',
      "paymentToken": 'P2xdr7bFjt3qRrPpCaysN50HCwfRG0qI',
      "id": 10000001631109,
      "creatorName": 'Mike B',
      "isDuplicate": false,
      "shouldVaultCard": true,
      "merchantId": 514391592,
      "batch": '0027',
      "batchId": 10000000228180,
      "tenderType": 'Card',
      "currency": 'USD',
      "amount": '16.12',
      "cardAccount": {
        "cardType": 'Visa',
          "entryMode": 'Keyed',
          "last4": '1111',
          "cardId": 'y15QvOteHZGBm7LH3GNIlTWbA1If',
          "token": 'P2xdr7bFjt3qRrPpCaysN50HCwfRG0qI',
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
      "authCode": 'PPS375',
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
      "reference": '122117000365',
      "tax": '0.2',
      "invoice": 'H00FIO0B',
      "customerCode": 'PTHIH00FIO0B',
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
            "unitPrice": '15.92',
            "quantity": 1,
            "taxRate": '0.0125628140703517587939698492',
            "taxAmount": '0.2',
            "discountRate": '0',
            "discountAmount": '0',
            "extendedAmount": '16.12',
            "lineItemId": 0
        }
      ],
      "clientReference": 'PTHIH00FIO0B',
      "type": 'Sale',
      "taxExempt": false,
      "reviewIndicator": 1,
      "source": 'QuickPay',
      "shouldGetCreditCardLevel": false
    }
    # Refund params end
  end

  def test_successful_purchase
    # byebug
    response = @gateway.purchase(@amount_purchase, @credit_card_purchase_success, @option_spr)
    # byebug
    assert_success response
    assert_equal 'Approved', response.params['status']
  end

  # Invalid card number
  def test_failed_purchase
    # byebug
    response = @gateway.purchase(@amount_purchase, @credit_card_purchase_fail_invalid_number, @option_spr)
    # byebug
    assert_success response

    assert_equal 'Invalid card number', response.params['authMessage']
    assert_equal 'Declined', response.params['status']
  end

  # Missing card number month
  def test_failed_purchase_missing_card_month
    # byebug
    response = @gateway.purchase(@amount_purchase, @credit_card_purchase_fail_missing_month, @option_spr)
    # byebug
    assert_failure response

    assert_equal 'ValidationError', response.params['errorCode']
    assert_equal 'Validation error happened', response.params['message']
    assert_equal 'Missing expiration month and / or year', response.params['details'][0]
  end

  # Missing card verification number
  def test_failed_purchase_missing_card_verification_number
    # byebug
    response = @gateway.purchase(@amount_purchase, @credit_card_purchase_fail_missing_verification, @option_spr)
    # byebug
    assert_success response

    assert_equal 'CVV is required based on merchant fraud settings', response.params['authMessage']
    assert_equal 'Declined', response.params['status']
  end

  # Authorize tests
  def test_successful_Authorize
    # byebug
    response = @gateway.authorize(@amount_purchase, @credit_card_purchase_success, @option_spr)
    # byebug
    assert_success response
    assert_equal 'Approved', response.params['status']
  end

  # Invalid card number
  def test_failed_Authorize
    # byebug
    response = @gateway.authorize(@amount_purchase, @credit_card_purchase_fail_invalid_number, @option_spr)
    # byebug
    assert_success response

    assert_equal 'Invalid card number', response.params['authMessage']
    assert_equal 'Declined', response.params['status']
  end

  # Missing card number month
  def test_failed_Authorize_missing_card_month
    # byebug
    response = @gateway.authorize(@amount_purchase, @credit_card_purchase_fail_missing_month, @option_spr)
    # byebug
    assert_failure response

    assert_equal 'ValidationError', response.params['errorCode']
    assert_equal 'Validation error happened', response.params['message']
    assert_equal 'Missing expiration month and / or year', response.params['details'][0]
  end

  # Missing card verification number
  def test_failed_Authorize_missing_card_verification_number
    # byebug
    response = @gateway.authorize(@amount_purchase, @credit_card_purchase_fail_missing_verification, @option_spr)
    # byebug
    assert_success response

    assert_equal 'CVV is required based on merchant fraud settings', response.params['authMessage']
    assert_equal 'Declined', response.params['status']
  end

  # Capture tests
  def test_successful_capture
    authobj = @gateway.authorize(@amount_authorize, @credit_card_purchase_success, @option_spr)
    assert_success authobj
    # byebug
    capture = @gateway.capture(@amount_authorize, authobj.authorization, authobj.params['authCode'], @option_spr)
    # byebug
    assert_success capture
    assert_equal 'Approved', capture.params['authMessage']
    assert_equal 'Approved', capture.params['status']
  end

  # Invalid authorization and null auth code
  def test_failed_capture
    # byebug
    capture = @gateway.capture(@amount_authorize, 'bogus', '', @option_spr)
    # byebug
    assert_success capture

    assert_equal 'Original Transaction Not Found', capture.params['authMessage']
    assert_equal 'Declined', capture.params['status']
  end

  # Void tests
  # Batch status is by default is set to Open wehn Sale transaction is created
  def test_successful_void_batch_open
    response = @gateway.purchase(@amount_purchase, @credit_card_purchase_success, @option_spr)
    assert_success response
    # byebug

    # check is this transaction associated batch is "Closed".
    batchcheck = @gateway.getpaymentstatus(response.params['batchId'], @option_spr)
    # byebug
    # if batch Open then fail test. Batch must be closed to perform a Refund
    if batchcheck.params['status'] == 'Open'
      #   byebug
      assert void = @gateway.void(response.params['id'], @option_spr)
      assert_success void
      assert_equal 'Succeeded', void.message
    else
      #   byebug
      assert_failure response
    end
  end

  def test_failed_void
    # byebug
    assert void = @gateway.void(123456, @option_spr)
    # byebug

    assert_failure void
    assert_equal 'Unauthorized', void.params['errorCode']
    assert_equal 'Unauthorized', void.params['message']
    assert_equal 'Original Payment Not Found Or You Do Not Have Access.', void.params['details'][0]
  end

  # Will have to find a transaction id associated with a refunded transaction.
  # Look for refunded Sale on MXM and take Payment ID in Advanced extra modal
  # Void will fail if transaction has already been refunded
  #   This test is not valid as we will test for batch status (Open or Closed) first (linked to a transaction).
  #   def test_failed_void_on_refunded_trans
  #     # byebug
  #     assert void = @gateway.void(10000001625074, @option_spr)
  #     byebug
  #     # assert_failure void

  #     assert_equal 'ContactCustomerSupport', void.error_code
  #   end

  def test_success_getpaymentstatus
    response = @gateway.purchase(@amount_purchase, @credit_card_purchase_success, @option_spr)
    assert_success response
    # byebug

    # check is this transaction associated batch is "Closed".
    batchcheck = @gateway.getpaymentstatus(response.params['batchId'], @option_spr)
    # byebug

    assert_success batchcheck
    # byebug
    assert_equal 'Open', batchcheck.params['status']
  end

  def test_failed_getpaymentstatus
    # byebug

    # check is this transaction associated batch is "Closed".
    batchcheck = @gateway.getpaymentstatus(123456, @option_spr)
    # byebug

    assert_failure batchcheck
    # byebug
    assert_equal 'Invalid JSON response', batchcheck.params['message'][0..20]
  end

  def test_successful_verify
    # byebug
    response = @gateway.verify(@cardnumber_verify)
    # byebug
    assert_failure response
    assert_match 'JPMORGAN CHASE BANK, N.A.', response.params['bank']['name']
   end

  def test_failed_verify
    # byebug
    response = @gateway.verify(12345)
    # byebug
    assert_failure response
    assert_match %r{Invalid bank bin number, must be 6-10 digits}, response.params['message']
  end

  def test_transcript_scrubbing
    # credit_card_success = credit_card('4444333322221111', verification_value: 976225)

    transcript = capture_transcript(@gateway) do
      # byebug
      @gateway.purchase(@amount_purchase, @credit_card_purchase_success, @option_spr)
      # byebug
    end
    # byebug
    clean_transcript = @gateway.scrub(transcript)
    # byebug
    assert_scrubbed(@credit_card_purchase_success.number, clean_transcript)
    assert_scrubbed(@credit_card_purchase_success.verification_value.to_s, clean_transcript)
  end

  # def test_invalid_login
  #   gateway = CardStreamGateway.new(login: '', password: '')

  #   response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  #   assert_match %r{REPLACE WITH FAILED LOGIN MESSAGE}, response.message
  # end

  # Tests that will fail as we need to manually set threshold to above exceed limit

  # Login to MXC and for client set in Advanced tab "Daily Authorization Decline Percent to 1".
  # This will set threshold exceeded limit.
  # Then run this test
  def test_fail_purchase_threshold_exceeded
    # byebug
    response = @gateway.purchase(@amount_purchase, @credit_card_purchase_success, @option_spr)
    # byebug
    assert_success response
    assert_equal 'Decline threshold exceeded', response.params['authMessage']
    assert_equal 'Declined', response.params['status']
  end

  # Login to MXC and for client set in Advanced tab "Daily Authorization Decline Percent to 1".
  # This will set threshold exceeded limit.
  # Then run this test
  def test_fail_Authorize_threshold_exceeded
    # byebug
    response = @gateway.authorize(@amount_purchase, @credit_card_purchase_success, @option_spr)
    # byebug
    assert_success response
    assert_equal 'Decline threshold exceeded', response.params['authMessage']
    assert_equal 'Declined', response.params['status']
  end
  # end of threshold exceeded limit

  # Refund tests
  # Test if we can perform a refund by following steps. This is the happy path.
  #   1. Create Sale/Purchase
  #   2. Test if linked batch is Open
  #   3. Close linked batch with Sale/Purchase transaction
  #   4. Perform Refund
  def test_successful_refund_and_batch_closed
    response = @gateway.purchase(@amount_purchase, @credit_card_purchase_success, @option_spr)
    assert_success response
    # byebug

    # check is this transaction associated batch is "Closed".
    batchcheck = @gateway.getpaymentstatus(response.params['batchId'], @option_spr)
    # byebug
    # if batch Open then fail test. Batch must be closed to perform a Refund
    if batchcheck.params['status'] == 'Open'
      # byebug

      closebatch = @gateway.closebatch(response.params['batchId'], @option_spr)
      # byebug
      refund = @gateway.refund((response.params['amount'].to_f * -1), response.params['cardAccount'], response.params['authCode'], response.params, @option_spr)
      # byebug
      assert_success refund
      assert refund.params['status'] == 'Approved'

      assert_equal 'Succeeded', refund.message

    else
      # byebug
      assert_failure response
    end
  end

  # This test will happen when Spreedly tries to refund a transaction when linked batch is in 'Open' status
  # using capture response body from sale/purchase. Copy to variable @response_purchase
  # perform following steps and run 2 tests against "test_successful_refund_purchase_response"

  # Test 1 (will fail!)
  # 1). run sale purchase
  # 2). capture sale/purchase response object and save to @response_purchase variable
  # 3). Run test_successful_refund_purchase_response (with linked batch status of 'Open')

  # Test 2 (will pass)
  # 1). run sale purchase
  # 2). capture sale/purchase response object and save to @response_purchase variable
  # 3). close batch
  # 4). Run test_successful_refund_purchase_response

  def test_successful_refund_purchase_response
    # byebug
    @responseStringObj = @response_purchase.transform_keys(&:to_s)
    @amount_refund = @responseStringObj['amount'].to_f * -1
    @credit_card = @responseStringObj['cardAccount'].transform_keys(&:to_s)
    @responseStringObj['cardAccount'] = @responseStringObj['cardAccount'].transform_keys(&:to_s)
    @responseStringObj['posData'] = @responseStringObj['posData'].transform_keys(&:to_s)
    @responseStringObj['purchases'][0] = @responseStringObj['purchases'][0].transform_keys(&:to_s)
    @responseStringObj['risk'] = @responseStringObj['risk'].transform_keys(&:to_s)

    # byebug
    # check is this transaction associated batch is "Closed".
    batchcheck = @gateway.getpaymentstatus(@responseStringObj['batchId'], @option_spr)

    # if batch Open then fail test. Batch must be closed to perform a Refund
    if batchcheck.params['status'] == 'Open'
      assert_equal '1', '2'
    else
      # byebug
      refund = @gateway.refund(@amount_refund, @credit_card, @responseStringObj['authCode'], @responseStringObj, @option_spr)
      assert_success refund
      assert refund.params['status'] == 'Approved'
      # byebug
      assert_equal 'Succeeded', refund.message
    end
  end

  # Run this test after test "test_successful_refund_purchase_response".
  # This will be "Declined" as transaction has been refunded in "test above test_successful_refund_purchase_response".
  #   def test_fail_refund_already_refunded_purchase_response
  #     # byebug

  #     @responseStringObj = @response_purchase.transform_keys(&:to_s)
  #     @amount_refund = @responseStringObj['amount'].to_f * -1
  #     @credit_card = @responseStringObj['cardAccount'].transform_keys(&:to_s)
  #     @responseStringObj['cardAccount'] = @responseStringObj['cardAccount'].transform_keys(&:to_s)
  #     @responseStringObj['posData'] = @responseStringObj['posData'].transform_keys(&:to_s)
  #     @responseStringObj['purchases'][0] = @responseStringObj['purchases'][0].transform_keys(&:to_s)
  #     @responseStringObj['risk'] = @responseStringObj['risk'].transform_keys(&:to_s)

  #     # byebug
  #     # check is this transaction associated batch is "Closed".
  #     batchcheck = @gateway.getpaymentstatus(@responseStringObj['batchId'], @option_spr)

  #     # if batch Open then fail test. Batch must be closed to perform a Refund
  #     if batchcheck.params['status'] == 'Open'
  #       assert_failure response
  #     else
  #       # byebug
  #       refund = @gateway.refund(@amount_refund, @credit_card, @responseStringObj['authCode'], @responseStringObj)
  #       assert_success refund
  #       assert refund.params['status'] == 'Declined'
  #       assert refund.params['authMessage'] == 'Payment already refunded'
  #       # byebug
  #       assert_equal 'Succeeded', refund.message
  #     end
  #   end
end
