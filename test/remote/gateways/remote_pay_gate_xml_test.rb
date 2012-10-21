require 'test_helper'

class RemotePayGateXmlTest < Test::Unit::TestCase
  def setup
    @gateway = PayGateXmlGateway.new(fixtures(:pay_gate_xml))

    @amount = 245000
    @credit_card    = credit_card('4000000000000002')
    @declined_card  = credit_card('4000000000000036')

    @options = {
      :order_id         => generate_unique_id,
      :billing_address  => address,
      :description      => 'Store Purchase',
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Request for Settlement Received', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Declined", response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Auth Done', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Transaction ID Must Only Contain Digits', response.message
  end

  def test_invalid_login
    gateway = PayGateXmlGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Incorrect Credentials Supplied', response.message
  end
end
