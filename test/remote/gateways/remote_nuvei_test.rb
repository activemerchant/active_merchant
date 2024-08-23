require 'test_helper'
require 'timecop'

class RemoteNuveiTest < Test::Unit::TestCase
  def setup
    @gateway = NuveiGateway.new(fixtures(:nuvei))

    @amount = 100
    @credit_card = credit_card('4761344136141390', verification_value: '999', first_name: 'Cure', last_name: 'Tester')
    @declined_card = credit_card('4000128449498204')

    @options = {
      email: 'test@gmail.com',
      billing_address: address.merge(name: 'Cure Tester'),
      ip: '127.0.0.1',
      user_token_id: '123456'
    }
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, @credit_card, @options)
    end

    @gateway.scrub(transcript)
  end

  def test_successful_session_token_generation
    response = @gateway.send(:fetch_session_token, @options)
    assert_success response
    assert_not_nil response.params[:sessionToken]
  end

  def test_failed_session_token_generation
    @gateway.options[:merchant_site_id] = 123
    response = @gateway.send(:fetch_session_token, {})
    assert_failure response
    assert_match 'Invalid merchant site id', response.message
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_not_nil response.params[:transactionId]
    assert_match 'APPROVED', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_match 'DECLINED', response.params['transactionStatus']
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    capture_response = @gateway.capture(@amount, response.authorization)

    assert_success capture_response
    assert_match 'APPROVED', capture_response.message
  end

  def test_successful_zero_auth
    response = @gateway.authorize(0, @credit_card, @options)
    assert_success response
    assert_match 'APPROVED', response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_not_nil response.params[:transactionId]
    assert_match 'APPROVED', response.message
    assert_match 'SUCCESS', response.params['status']
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match 'DECLINED', response.params['transactionStatus']
  end

  def test_failed_purchase_with_invalid_cvv
    @credit_card.verification_value = nil
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'ERROR', response.params['transactionStatus']
    assert_match 'Invalid CVV2', response.message
  end

  def test_failed_capture_invalid_transaction_id
    response = @gateway.capture(@amount, '123')
    assert_failure response
    assert_match 'ERROR', response.params['status']
    assert_match 'Invalid relatedTransactionId', response.message
  end

  def test_successful_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void_response = @gateway.void(response.authorization)
    assert_success void_response
    assert_match 'SUCCESS', void_response.params['status']
    assert_match 'APPROVED', void_response.message
  end

  def test_failed_void_invalid_transaction_id
    response = @gateway.void('123')
    assert_failure response
    assert_match 'ERROR', response.params['status']
    assert_match 'Invalid relatedTransactionId', response.message
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund_response = @gateway.refund(@amount, response.authorization)
    assert_success refund_response
    assert_match 'SUCCESS', refund_response.params['status']
    assert_match 'APPROVED', refund_response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'SUCCESS', response.params['status']
    assert_match 'APPROVED', response.message
  end

  def test_successful_general_credit
    credit_response = @gateway.credit(@amount, @credit_card, @options)
    assert_success credit_response
    assert_match 'SUCCESS', credit_response.params['status']
    assert_match 'APPROVED', credit_response.message
  end

  def test_failed_general_credit
    credit_response = @gateway.credit(@amount, @declined_card, @options)
    assert_failure credit_response
    assert_match 'DECLINED', credit_response.params['transactionStatus']
    assert_match 'External Error in Processing', credit_response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_match 'SUCCESS', response.params['status']
    assert_match 'APPROVED', response.message
  end

  def test_successful_purchase_with_stored_card
    response = @gateway.store(@credit_card, @options)
    assert_success response

    payment_method_token = response.params[:paymentOption][:userPaymentOptionId]
    purchase = @gateway.purchase(@amount, payment_method_token, @options.merge(cvv_code: '999'))
    assert_success purchase
  end

  def test_purchase_using_stored_credentials_cit
    options = @options.merge!(stored_credential: stored_credential(:cardholder, :unscheduled, :initial))
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_success response

    assert capture = @gateway.capture(@amount, response.authorization, @options)
    assert_success capture
    options_stored_credentials = @options.merge!(related_transaction_id: response.authorization, stored_credential: stored_credential(:cardholder, :recurring, id: response.network_transaction_id))
    assert purchase_response = @gateway.purchase(@amount, @credit_card, options_stored_credentials)
    assert_success purchase_response
  end

  def test_purchase_using_stored_credentials_recurring_cit
    # Initial transaction with stored credentials
    initial_options = @options.merge(stored_credential: stored_credential(:cardholder, :unscheduled, :initial))
    initial_response = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success initial_response

    assert_not_nil initial_response.authorization
    assert_match 'SUCCESS', initial_response.params['status']

    stored_credential_options = @options.merge(
      related_transaction_id: initial_response.authorization,
      stored_credential: stored_credential(:merchant, :recurring, network_transaction_id: initial_response.network_transaction_id)
    )

    recurring_response = @gateway.purchase(@amount, @credit_card, stored_credential_options)
    assert_success recurring_response
    assert_match 'SUCCESS', recurring_response.params['status']
  end

  def test_purchase_using_stored_credentials_merchant_installments_cit
    initial_options = @options.merge(stored_credential: stored_credential(:cardholder, :unscheduled, :initial))
    initial_response = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success initial_response

    assert_not_nil initial_response.authorization
    assert_match 'SUCCESS', initial_response.params['status']

    stored_credential_options = @options.merge(
      related_transaction_id: initial_response.authorization,
      stored_credential: stored_credential(:merchant, :installments, network_transaction_id: initial_response.network_transaction_id)
    )

    recurring_response = @gateway.purchase(@amount, @credit_card, stored_credential_options)
    assert_success recurring_response
    assert_match 'SUCCESS', recurring_response.params['status']
  end
end
