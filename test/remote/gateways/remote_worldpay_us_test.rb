require 'test_helper'

class RemoteWorldpayUsTest < Test::Unit::TestCase
  def setup
    @gateway = WorldpayUsGateway.new(fixtures(:worldpay_us))

    @amount = 100
    @credit_card = credit_card('4446661234567892')
    @declined_card = credit_card('4000300011112220')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'DECLINED:0500900009:PICK UP CARD:', response.message
  end

  def test_successful_authorize_and_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^\d+\|.+$), response.authorization

    assert capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert response.message =~ /PICK UP CARD:/
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal "Succeeded", refund.message
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
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_success response.responses.last, "The void should succeed"
  end

  def test_failed_verify
    bogus_card = credit_card('4424222222222222')
    assert response = @gateway.verify(bogus_card, @options)
    assert_failure response
    assert response.message =~ /DECLINED/
  end

  def test_passing_billing_address
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:billing_address => address))
    assert_success response
  end

  def test_invalid_login
    gateway = WorldpayUsGateway.new(
                :acctid => "",
                :subid => "",
                :merchantpin => ""
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.message =~ /DECLINED/
  end
end
