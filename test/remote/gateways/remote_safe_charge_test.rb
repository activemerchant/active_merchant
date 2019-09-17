require 'test_helper'

class RemoteSafeChargeTest < Test::Unit::TestCase
  def setup
    @gateway = SafeChargeGateway.new(fixtures(:safe_charge))

    @amount = 100
    @credit_card = credit_card('4000100011112224', verification_value: '912')
    @declined_card = credit_card('4000300011112220')
    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: 'Store Purchase',
      currency: 'EUR'
    }

    @three_ds_options = @options.merge(three_d_secure: true)
    @three_ds_gateway = SafeChargeGateway.new(fixtures(:safe_charge_three_ds))
    @three_ds_enrolled_card = credit_card('4012 0010 3749 0014')
    @three_ds_non_enrolled_card = credit_card('5333 3062 3122 6927')
    @three_ds_invalid_pa_res_card = credit_card('4012 0010 3749 0006')
  end

  def test_successful_3ds_purchase
    response = @three_ds_gateway.purchase(@amount, @three_ds_enrolled_card, @three_ds_options)
    assert_success response
    assert !response.params['acsurl'].blank?
    assert !response.params['pareq'].blank?
    assert !response.params['xid'].blank?
    assert_equal 'Success', response.message
  end

  def test_successful_regular_purchase_through_3ds_flow_with_non_enrolled_card
    response = @three_ds_gateway.purchase(@amount, @three_ds_non_enrolled_card, @three_ds_options)
    assert_success response
    assert response.params['acsurl'].blank?
    assert response.params['pareq'].blank?
    assert response.params['xid'].blank?
    assert response.params['threedflow'] = 1
    assert_equal 'Success', response.message
  end

  def test_successful_regular_purchase_through_3ds_flow_with_invalid_pa_res
    response = @three_ds_gateway.purchase(@amount, @three_ds_invalid_pa_res_card, @three_ds_options)
    assert_success response
    assert !response.params['acsurl'].blank?
    assert !response.params['pareq'].blank?
    assert !response.params['xid'].blank?
    assert response.params['threedflow'] = 1
    assert_equal 'Success', response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      user_id: '123',
      auth_type: '2',
      expected_fulfillment_count: '3',
      merchant_descriptor: 'Test Descriptor',
      merchant_phone_number: '(555)555-5555',
      merchant_name: 'Test Merchant',
      stored_credential_mode: true
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Decline', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Success', capture.message
  end

  def test_successful_authorize_and_capture_with_more_options
    extra = {
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      user_id: '123',
      auth_type: '2',
      expected_fulfillment_count: '3',
      merchant_descriptor: 'Test Descriptor',
      merchant_phone_number: '(555)555-5555',
      merchant_name: 'Test Merchant',
      stored_credential_mode: true
    }
    auth = @gateway.authorize(@amount, @credit_card, extra)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Success', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Decline', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Transaction must contain a Card/Token/Account', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Success', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(200, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(100, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'Transaction must contain a Card/Token/Account', response.message
  end

  def test_successful_credit
    response = @gateway.credit(@amount, credit_card('4444436501403986'), @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_credit_with_extra_options
    extra = {
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      user_id: '123',
      auth_type: '2',
      expected_fulfillment_count: '3',
      merchant_descriptor: 'Test Descriptor',
      merchant_phone_number: '(555)555-5555',
      merchant_name: 'Test Merchant',
      stored_credential_mode: true
    }

    response = @gateway.credit(@amount, credit_card('4444436501403986'), extra)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_credit
    response = @gateway.credit(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Decline', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'Invalid Amount', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'Success', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match 'Decline', response.message
  end

  def test_invalid_login
    gateway = SafeChargeGateway.new(client_login_id: '', client_password: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'Invalid login', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:client_password], transcript)
  end

end
