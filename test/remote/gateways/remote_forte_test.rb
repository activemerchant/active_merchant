require 'test_helper'

class RemoteForteTest < Test::Unit::TestCase
  def setup
    @gateway = ForteGateway.new(fixtures(:forte))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('1111111111111111')

    @check = check
    @bad_check = check({
      :name => 'Jim Smith',
      :bank_name => 'Bank of Elbonia',
      :routing_number => '1234567890',
      :account_number => '0987654321',
      :account_holder_type => '',
      :account_type => 'checking',
      :number => '0'
    })

    @options = {
      billing_address: address,
      description: 'Store Purchase',
      order_id: '1'
    }

  end

  def test_invalid_login
    gateway = ForteGateway.new(api_key: "InvalidKey", secret: "InvalidSecret", location_id: "11", account_id: "323")
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match "combination not found.", response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'TEST APPROVAL', response.message
  end

  def test_successful_purchase_with_echeck
    response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_failed_purchase_with_echeck
    response = @gateway.purchase(@amount, @bad_check, @options)
    assert_failure response
    assert_equal 'INVALID TRN', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com",
      address: address
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal "1", response.params["order_number"]
    assert_equal 'TEST APPROVAL', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'INVALID CREDIT CARD NUMBER', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    wait_for_authorization_to_clear

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_equal 'APPROVED', capture.message
  end

  def test_failed_authorize
    @amount = 1985
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'INVALID CREDIT CARD NUMBER', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    wait_for_authorization_to_clear

    assert capture = @gateway.capture(@amount-1, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_match 'field transaction_id', response.message
  end

  def test_successful_credit
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.credit(@amount, @credit_card, @options)
    assert_success refund
    assert_equal 'TEST APPROVAL', refund.message
  end

  def test_partial_credit
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.credit(@amount-1, @credit_card, @options)
    assert_success refund
  end

  def test_failed_credit
    response = @gateway.credit(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    wait_for_authorization_to_clear

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'APPROVED', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_match 'field transaction_id', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{TEST APPROVAL}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{INVALID CREDIT CARD NUMBER}, response.message
  end

  def test_transcript_scrubbing
    @credit_card.verification_value = 789
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end

    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end

  private

  def wait_for_authorization_to_clear
    sleep(10)
  end

end
