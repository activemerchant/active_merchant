require 'test_helper'

class RemoteDirectConnectTest < Test::Unit::TestCase
  def setup
    @gateway = DirectConnectGateway.new(fixtures(:direct_connect))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4111111111111112')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_dump_transcript
    skip("Transcript scrubbing for this gateway has been tested.")

    # This test will run a purchase transaction on your gateway
    # and dump a transcript of the HTTP conversation so that
    # you can use that transcript as a reference while
    # implementing your scrubbing logic
    dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)
    cvnum_str = "cvnum=#{@credit_card.verification_value}"
    refute transcript.include?(cvnum_str), "Expected #{cvnum_str} to be scrubbed out of transcript"
    assert_scrubbed(@credit_card.number, transcript)

    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'Approved', response.message
    assert response.authorization
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    
    assert_failure response
    assert_equal :invalidAccountNumber, DirectConnectGateway::DIRECT_CONNECT_CODES[response.params['result']]
    assert_equal 'Invalid Account Number', response.message
  end

  def test_successful_authorize
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response

    assert_equal :invalidAccountNumber, DirectConnectGateway::DIRECT_CONNECT_CODES[response.params['result']]
    assert_equal 'Invalid Account Number', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, @credit_card, purchase.authorization, @options)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, @credit_card, purchase.authorization, @options)
    assert_success refund
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount+1, @credit_card, purchase.authorization, @options)
    assert_failure refund
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{REPLACE WITH SUCCESS MESSAGE}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match "Invalid Account Number", response.message
    assert_equal :invalidAccountNumber, DirectConnectGateway::DIRECT_CONNECT_CODES[response.params['result']]
  end

  def test_invalid_login
    gateway = DirectConnectGateway.new(
      login: '',
      password: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  # recurring

  def test_successful_add_contract
  end

  def test_failed_add_contract
  end

  def test_successful_update_contract
  end

  def test_failed_update_contract
  end

  def test_successful_delete_contract
  end

  def test_failed_delete_contract
  end

  # crm

  def test_successful_add_customer
  end

  def test_failed_add_customer
  end

  def test_successful_update_customer
  end

  def test_failed_update_customer
  end

  def test_successful_delete_customer
  end

  def test_failed_delete_customer
  end

  def test_successful_add_credit_card_info
  end

  def test_failed_add_credit_card_info
  end

  def test_successful_update_credit_card_info
  end

  def test_failed_update_credit_card_info
  end

  def test_successful_delete_credit_card_info
  end

  def test_failed_delete_credit_card_info
  end

  # card safe

  def test_successful_store_card
  end

  def test_failed_store_card
  end

  def test_successful_process_stored_card
  end

  def test_failed_process_stored_card
  end

  # these are the 'processcreditcard' methods under the recurring tab in the docs
  def test_successful_process_stored_card_recurring
  end

  def test_successful_process_stored_card_recurring
  end
end
