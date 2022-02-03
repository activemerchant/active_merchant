require 'test_helper'

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

    # purchase params success
    @amount_purchase = 2
    @credit_card = credit_card('4111111111111111', month: '01', year: '2029', first_name: 'Marcus', last_name: 'Rashford', verification_value: '999')
    @invalid_credit_card = credit_card('123456', month: '01', year: '2029', first_name: 'Marcus', last_name: 'Rashford', verification_value: '999')
    @faulty_credit_card = credit_card('12345', month: '01', year: '2029', first_name: 'Marcus', last_name: 'Rashford', verification_value: '999')

    @option_spr = {
      billing_address: address(),
      invoice: '666',
      cardPresent: false,
      cardPresentType: 'CardNotPresent',
      isAuth: false,
      paymentType: 'Sale',
      bankAccount: '',
      shouldVaultCard: false,
      taxExempt: false,
      tenderType: 'Card',
      ship_amount: 0.01,
      ship_to_country: 'USA',
      ship_to_zip: '55667',
      purchases: [
        {
          lineItemId: 79402,
          name: 'Anita',
          description: 'Dump',
          quantity: 1,
          unitPrice: '1.23',
          discountAmount: 0,
          extendedAmount: '1.23',
          discountRate: 0
        },
        {
          lineItemId: 79403,
          name: 'Old Peculier',
          description: 'Beer',
          quantity: 1,
          unitPrice: '2.34',
          discountAmount: 0,
          extendedAmount: '2.34',
          discountRate: 0
        }
      ],
      code: '101',
      taxRate: '05',
      taxAmount: '0.50',
      posData: {
        cardholderPresence: 'Ecom',
        cardPresent: 'false',
        deviceAttendance: 'HomePc',
        deviceInputCapability: 'Unknown',
        deviceLocation: 'HomePc',
        panCaptureMethod: 'Manual',
        partialApprovalSupport: 'NotSupported',
        pinCaptureCapability: 'Incapable'
      }
    }

    # purchase params fail inavalid card number
    @credit_card_purchase_fail_invalid_number = credit_card('4111', month: '01', year: '2029', first_name: 'Marcus', last_name: 'Rashford', verification_value: '999')

    # purchase params fail missing card number month
    @credit_card_purchase_fail_missing_month = credit_card('4111111111111111', month: '', year: '2029', first_name: 'Marcus', last_name: 'Rashford', verification_value: '999')

    # purchase params fail missing card verification number
    @credit_card_purchase_fail_missing_verification = credit_card('4111111111111111', month: '01', year: '2029', first_name: 'Marcus', last_name: 'Rashford', verification_value: '')

    # authorize params success
    @amount_authorize = 799
    # authorize params success end
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount_purchase, @credit_card, @option_spr)
    assert_success response
    assert_equal 'Approved', response.params['status']
  end

  # Invalid card number
  def test_failed_purchase
    response = @gateway.purchase(@amount_purchase, @credit_card_purchase_fail_invalid_number, @option_spr)
    assert_failure response

    assert_equal 'Invalid card number', response.message
    assert_equal 'Declined', response.params['status']
  end

  # Missing card number month
  def test_failed_purchase_missing_card_month
    response = @gateway.purchase(@amount_purchase, @credit_card_purchase_fail_missing_month, @option_spr)
    assert_failure response

    assert_equal 'ValidationError', response.error_code
    assert_equal 'Validation error happened', response.params['message']
    assert_equal 'Missing expiration month and / or year', response.message
  end

  # Missing card verification number
  def test_failed_purchase_missing_card_verification_number
    response = @gateway.purchase(@amount_purchase, @credit_card_purchase_fail_missing_verification, @option_spr)
    assert_failure response

    assert_equal 'CVV is required based on merchant fraud settings', response.message
    assert_equal 'Declined', response.params['status']
  end

  # Authorize tests
  def test_successful_authorize
    response = @gateway.authorize(@amount_purchase, @credit_card, @option_spr)
    assert_success response
    assert_equal 'Approved', response.params['status']
  end

  # Invalid card number
  def test_failed_authorize
    response = @gateway.authorize(@amount_purchase, @credit_card_purchase_fail_invalid_number, @option_spr)
    assert_failure response

    assert_equal 'Invalid card number', response.message
    assert_equal 'Declined', response.params['status']
  end

  # Missing card number month
  def test_failed_authorize_missing_card_month
    response = @gateway.authorize(@amount_purchase, @credit_card_purchase_fail_missing_month, @option_spr)
    assert_failure response

    assert_equal 'ValidationError', response.error_code
    assert_equal 'Validation error happened', response.params['message']
    assert_equal 'Missing expiration month and / or year', response.message
  end

  # Missing card verification number
  def test_failed_authorize_missing_card_verification_number
    response = @gateway.authorize(@amount_purchase, @credit_card_purchase_fail_missing_verification, @option_spr)
    assert_failure response

    assert_equal 'CVV is required based on merchant fraud settings', response.message
    assert_equal 'Declined', response.params['status']
  end

  # Capture tests
  def test_successful_capture
    auth_obj = @gateway.authorize(@amount_authorize, @credit_card, @option_spr)
    assert_success auth_obj
    # add auth code to options
    @option_spr.update(auth_code: auth_obj.params['authCode'])

    capture = @gateway.capture(@amount_authorize, auth_obj.authorization.to_s, @option_spr)
    assert_success capture
    assert_equal 'Approved', capture.message
    assert_equal 'Approved', capture.params['status']
  end

  # Invalid authorization and null auth code
  def test_failed_capture
    # add auth code to options
    @option_spr.update(auth_code: '12345')
    capture = @gateway.capture(@amount_authorize, { 'payment_token' => 'bogus' }.to_s, @option_spr)
    assert_failure capture

    assert_equal 'Original Transaction Not Found', capture.message
    assert_equal 'Declined', capture.params['status']
  end

  # Void tests
  # Batch status is by default is set to Open when Sale transaction is created
  def test_successful_void_batch_open
    response = @gateway.purchase(@amount_purchase, @credit_card, @option_spr)
    assert_success response

    batch_check = @gateway.get_payment_status(response.params['batchId'], @option_spr)
    assert_equal batch_check.params['status'], 'Open'

    void = @gateway.void({ 'id' => response.params['id'] }.to_s, @option_spr)
    assert_success void
  end

  def test_failed_void
    assert void = @gateway.void({ 'id' => 123456 }.to_s, @option_spr)
    assert_failure void
    assert_equal 'Unauthorized', void.error_code
    assert_equal 'Original Payment Not Found Or You Do Not Have Access.', void.message
  end

  def test_success_get_payment_status
    response = @gateway.purchase(@amount_purchase, @credit_card, @option_spr)
    assert_success response

    # check is this transaction associated batch is "Closed".
    batch_check = @gateway.get_payment_status(response.params['batchId'], @option_spr)

    assert_success batch_check
    assert_equal 'Open', batch_check.params['status']
  end

  def test_failed_get_payment_status
    # check is this transaction associated batch is "Closed".
    batch_check = @gateway.get_payment_status(123456, @option_spr)

    assert_failure batch_check
    assert_equal 'Invalid JSON response', batch_check.params['message'][0..20]
  end

  # Must enter 6 to 10 numbers from start of card to test
  def test_successful_verify
    # Generate jwt token from key and secret. Pass generated jwt to verify function. The verify function requires a jwt for header authorization.
    jwt_response = @gateway.create_jwt(@option_spr)
    response = @gateway.verify(@credit_card, { jwt_token: jwt_response.params['jwtToken'] })
    assert_success response
    assert_match 'JPMORGAN CHASE BANK, N.A.', response.params['bank']['name']
  end

  # Must enter 6 to 10 numbers from start of card to test
  def test_failed_verify
    # Generate jwt token from key and secret. Pass generated jwt to verify function. The verify function requires a jwt for header authorization.
    jwt_response = @gateway.create_jwt(@option_spr)
    @gateway.verify(@invalid_credit_card, { jwt_token: jwt_response.params['jwtToken'] })
  rescue StandardError => e
    if e.to_s.include? 'No bank information found for bin number'
      response = { 'error' => 'No bank information found for bin number' }
      assert_match 'No bank information found for bin number', response['error']
    else
      assert_match 'No bank information found for bin number', 'error'
    end
  end

  def test_failed_verify_must_be_6_to_10_digits
    # Generate jwt token from key and secret. Pass generated jwt to verify function. The verify function requires a jwt for header authorization.
    jwt_response = @gateway.create_jwt(@option_spr)
    @gateway.verify(@faulty_credit_card, { jwt_token: jwt_response.params['jwtToken'] })
  rescue StandardError => e
    if e.to_s.include? 'Invalid bank bin number, must be 6-10 digits'
      response = { 'error' => 'Invalid bank bin number, must be 6-10 digits' }
      assert_match 'Invalid bank bin number, must be 6-10 digits', response['error']
    else
      assert_match 'Invalid bank bin number, must be 6-10 digits', 'error'
    end
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount_purchase, @credit_card, @option_spr)
    end
    clean_transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end

  # Refund tests
  # Test if we can perform a refund by following steps. This is the happy path.
  #   1. Create Sale/Purchase
  #   2. Test if linked batch is Open
  #   3. Close linked batch with Sale/Purchase transaction
  #   4. Perform Refund
  def test_successful_refund_and_batch_closed
    response = @gateway.purchase(@amount_purchase, @credit_card, @option_spr)
    assert_success response

    batch_check = @gateway.get_payment_status(response.params['batchId'], @option_spr)
    assert_equal batch_check.params['status'], 'Open'

    @gateway.close_batch(response.params['batchId'], @option_spr)
    refund_params = @option_spr.merge(response.params).deep_transform_keys { |key| key.to_s.underscore }.transform_keys(&:to_sym)

    refund = @gateway.refund(response.params['amount'].to_f * 100, response.authorization.to_s, refund_params)
    assert_success refund
    assert refund.params['status'] == 'Approved'
    assert_equal 'Approved or completed successfully', refund.message
  end

  def test_successful_batch_closed_and_void
    response = @gateway.purchase(@amount_purchase, @credit_card, @option_spr)
    assert_success response
    batch_check = @gateway.get_payment_status(response.params['batchId'], @option_spr)

    @gateway.close_batch(response.params['batchId'], @option_spr) if batch_check.params['status'] == 'Open'

    void = @gateway.void({ 'id' => response.params['id'] }.to_s, @option_spr)
    assert void.params['code'] == '204'

    payment_status = @gateway.get_payment_status(response.params['batchId'], @option_spr)
    assert payment_status.params['status'] == 'Pending'
  end
end
