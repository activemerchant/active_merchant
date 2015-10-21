require 'test_helper'

class RemoteJetpayTest < Test::Unit::TestCase

  def setup
    @gateway = JetpayGateway.new(fixtures(:jetpay))

    @credit_card = credit_card('4000300020001000')
    @declined_card = credit_card('4000300020001000')

    @options = {
      :billing_address => address(:country => 'US', :zip => '75008'),
      :shipping_address => address(:country => 'US'),
      :email => 'test@test.com',
      :ip => '127.0.0.1',
      :order_id => '12345',
      :tax => 7
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(9900, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert_not_nil response.authorization
    assert_not_nil response.params["approval"]
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(5205, @declined_card, @options)
    assert_failure response
    assert_equal "Do not honor.", response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(9900, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]

    assert capture = @gateway.capture(9900, auth.authorization)
    assert_success capture
  end

  def test_partial_capture
    assert auth = @gateway.authorize(9900, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]

    assert capture = @gateway.capture(4400, auth.authorization)
    assert_success capture
  end


  def test_void
    # must void a valid auth
    assert auth = @gateway.authorize(9900, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_refund
    assert response = @gateway.purchase(9900, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert_not_nil response.authorization
    assert_not_nil response.params["approval"]

    assert refund = @gateway.refund(2000, response.authorization)
    assert_success refund
    assert_not_nil(refund.authorization)
    assert_not_nil(refund.params["approval"])
  end

    def test_failed_refund
    assert refund = @gateway.refund(1000, 'AAAAAABBBBBBCCCCCC')
    assert_failure refund
  end

  def test_failed_capture
    assert response = @gateway.capture(9900, '7605f7c5d6e8f74deb')
    assert_failure response
    assert_equal 'Transaction Not Found.', response.message
  end

  def test_invalid_login
    gateway = JetpayGateway.new(:login => 'bogus')
    assert response = gateway.purchase(9900, @credit_card, @options)
    assert_failure response

    assert_equal 'Bad Terminal ID.', response.message
  end

  def test_missing_login
    gateway = JetpayGateway.new(:login => '')
    assert response = gateway.purchase(9900, @credit_card, @options)
    assert_failure response

    assert_equal 'No response returned (missing credentials?).', response.message
  end

  def test_transcript_scrubbing
    @credit_card.verification_value = "421"
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(9900, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end
end
