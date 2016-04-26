require 'test_helper'

class RemotePaymentHighwayTest < Test::Unit::TestCase
  def setup
    @gateway = PaymentHighwayGateway.new(fixtures(:payment_highway))

    @amount = 1000
    @credit_card = credit_card('4153013999700024', month: 11, year: 2017, verification_value: "024")
    @declined_card = credit_card('4153013999700156', month: 11, year: 2017, verification_value: "156")
    @stolen_card = credit_card('4153013999700289', month: 11, year: 2017, verification_value: "289")
    @disabled_online_payments_card = credit_card('4920101111111113', month: 11, year: 2017, verification_value: "113")

    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Request successful.', response.message
  end

  def test_successful_order_status
    options = {
      order_id: SecureRandom.uuid
    }

    @gateway.purchase(@amount, @credit_card, options)
    response = @gateway.order_status(options[:order_id])
    assert_success response
    assert response.params["transactions"].size == 1
  end

  def test_declined_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Authorization failed', response.message
  end

  def test_stolen_purchase
    response = @gateway.purchase(@amount, @stolen_card, @options)
    assert_failure response
    assert_equal 'Authorization failed', response.message
  end

  def test_disabled_online_payment_card_purchase
    response = @gateway.purchase(@amount, @disabled_online_payments_card, @options)
    assert_failure response
    assert_equal 'Authorization failed', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @credit_card)
    assert_success refund
    assert_equal 'Request successful.', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount / 2, purchase.authorization, @credit_card)
    assert_success refund
    assert_equal 'Request successful.', refund.message
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    response = @gateway.refund(@amount*(-1), purchase.authorization, @credit_card)
    assert_failure response
    assert_equal 'Invalid input. Detailed information is in the message field.', response.message
  end

  #def test_successful_verify
    #response = @gateway.verify(@credit_card, @options)
    #assert_success response
    #assert_match %r{REPLACE WITH SUCCESS MESSAGE}, response.message
  #end

  #def test_failed_verify
    #response = @gateway.verify(@declined_card, @options)
    #assert_failure response
    #assert_match %r{REPLACE WITH FAILED PURCHASE MESSAGE}, response.message
  #end

  #def test_successful_authorize_and_capture
    #auth = @gateway.authorize(@amount, @credit_card, @options)
    #assert_success auth

    #assert capture = @gateway.capture(@amount, auth.authorization)
    #assert_success capture
    #assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  #end

  #def test_partial_capture
    #auth = @gateway.authorize(@amount, @credit_card, @options)
    #assert_success auth

    #assert capture = @gateway.capture(@amount-1, auth.authorization)
    #assert_success capture
  #end

  #def test_failed_capture
    #response = @gateway.capture(@amount, '')
    #assert_failure response
    #assert_equal 'REPLACE WITH FAILED CAPTURE MESSAGE', response.message
  #end

  #def test_successful_void
    #auth = @gateway.authorize(@amount, @credit_card, @options)
    #assert_success auth

    #assert void = @gateway.void(auth.authorization)
    #assert_success void
    #assert_equal 'REPLACE WITH SUCCESSFUL VOID MESSAGE', void.message
  #end

  #def test_failed_void
    #response = @gateway.void('')
    #assert_failure response
    #assert_equal 'REPLACE WITH FAILED VOID MESSAGE', response.message
  #end

  #def test_invalid_login
    #gateway = PaymentHighwayGateway.new(login: '', password: '')

    #response = gateway.purchase(@amount, @credit_card, @options)
    #assert_failure response
    #assert_match %r{REPLACE WITH FAILED LOGIN MESSAGE}, response.message
  #end

  #def test_dump_transcript
    ## This test will run a purchase transaction on your gateway
    ## and dump a transcript of the HTTP conversation so that
    ## you can use that transcript as a reference while
    ## implementing your scrubbing logic.  You can delete
    ## this helper after completing your scrub implementation.
    #dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  #end

  #def test_transcript_scrubbing
    #transcript = capture_transcript(@gateway) do
      #@gateway.purchase(@amount, @credit_card, @options)
    #end
    #transcript = @gateway.scrub(transcript)

    #assert_scrubbed(@credit_card.number, transcript)
    #assert_scrubbed(@credit_card.verification_value, transcript)
    #assert_scrubbed(@gateway.options[:password], transcript)
  #end

end
