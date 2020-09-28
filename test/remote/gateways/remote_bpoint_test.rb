require 'test_helper'

class RemoteBpointTest < Test::Unit::TestCase
  def setup
    @gateway = BpointGateway.new(fixtures(:bpoint))

    @amount = 100
    approved_year = '00'
    declined_year = '01'
    @credit_card = credit_card('4987654321098769', month: '99', year: approved_year)
    @declined_card = credit_card('4987654321098769', month: '99', year: declined_year)
    @error_card = credit_card('498765432109', month: '99', year: approved_year)

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_store
    response = @gateway.store(@credit_card, { crn1: 'TEST' })
    assert_success response
    assert_equal "Success", response.message
    token_key = 'AddTokenResult_Token'
    assert_not_nil response.params[token_key]
    assert_not_nil response.authorization
    assert_equal response.params[token_key], response.authorization
  end

  def test_failed_store
    response = @gateway.store(@error_card)
    assert_failure response
    assert_equal "Error", response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
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
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(@amount, auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void(@amount, '')
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_invalid_login
    gateway = BpointGateway.new(
      username: 'abc',
      password: '123',
      merchant_number: 'xyz'
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'invalid login', response.message
    assert_failure response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
