require 'test_helper'

class RemoteGlobalTransportTest < Test::Unit::TestCase
  def setup
    @gateway = GlobalTransportGateway.new(fixtures(:global_transport))

    @credit_card = credit_card('4003002345678903')

    @options = {
      email: 'john@example.com',
      order_id: '1',
      billing_address: address,
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(500, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(2304, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(500, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(500, auth.authorization)
    assert_success capture
    assert_equal "Approved", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(40000, @credit_card, @options)
    assert_failure response
    assert_equal "Declined", response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(500, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(499, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    auth = @gateway.authorize(500, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(1000, auth.authorization)
    assert_failure capture
    assert_match /must be less than or equal to the original amount/, capture.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(500, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(500, purchase.authorization)
    assert_success refund
    assert_equal "Approved", refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(500, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(490, purchase.authorization)
    assert_success refund
    assert_equal "Approved", refund.message
  end

  def test_failed_refund
    purchase = @gateway.purchase(500, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(1000, purchase.authorization)
    assert_failure refund
    assert_match /Refund Exceeds Available Refund Amount/, refund.message
  end

  def test_successful_void
    auth = @gateway.authorize(500, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal "Approved", void.message
  end

  def test_failed_void
    assert void = @gateway.void("UnknownAuthorization")
    assert_failure void
    assert_equal "Invalid PNRef", void.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "Approved", response.message
  end

  def test_failed_verify
    response = @gateway.verify(credit_card('4003'), @options)
    assert_failure response
    assert_equal "Invalid Account Number", response.message
  end

  def test_invalid_login
    gateway = GlobalTransportGateway.new(global_user_name: '', global_password: '', term_type: '')
    response = gateway.purchase(500, @credit_card, @options)
    assert_failure response
    assert_equal("Invalid Login Information", response.message)
  end
end
