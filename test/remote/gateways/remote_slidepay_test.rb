require 'test_helper'

class RemoteSlidepayTest < Test::Unit::TestCase
  def setup
    @gateway = SlidepayGateway.new(fixtures(:slidepay))

    @amount = 101
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :billing_address => address
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    response = @gateway.refund(nil, purchase.authorization)
    assert_success response
  end

  def test_failed_refund
    response = @gateway.refund(nil, "bogus")
    assert_failure response
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_capture
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    response = @gateway.capture(nil, authorize.authorization)
    assert_success response
  end

  def test_failed_capture
    response = @gateway.capture(nil, "bogus")
    assert_failure response
  end

  def test_successful_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    response = @gateway.void(authorize.authorization)
    assert_success response
  end

  def test_failed_void
    response = @gateway.void("bogus")
    assert_failure response
  end
end
