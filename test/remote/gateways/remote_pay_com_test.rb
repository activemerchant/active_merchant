require 'test_helper'

class RemotePayComTest < Test::Unit::TestCase
  def setup
    @gateway = PayComGateway.new(fixtures(:pay_com))

    @amount = 100
    @credit_card = CreditCard.new(
      :first_name         => 'Test',
      :last_name          => 'abcdfg',
      :month              => '11',
      :year               => '24',
      :number             => '4018810000150015',
      :verification_value => '123'
    )

    @declined_card = CreditCard.new(
      :first_name         => 'Test',
      :last_name          => 'abcdfg',
      :month              => '11',
      :year               => '24',
      :number             => '4000000000001091',
      :verification_value => '123'
    )
    @options = {
      billing_address: {
        address_line1: "23/2 115 Kirkton Avenue",
        address_line2: "",
        city: "Glasgow",
        postal_code: "G13 3EN",
        country: "GB",
      },
      consumer_details: {
        email: "consumer2@pay.com",
        first_name: "John",
        last_name: "Doe",
        phone: "447123456789"
      },
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transaction not allowed for cardholder', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Transaction approved', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transaction not allowed for cardholder', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Authorization id must be provided for capture', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Transaction approved', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'Authorization id must be provided for refund', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Transaction approved', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'Authorization id must be provided for void', response.message
  end

  def test_invalid_login
    gateway = PayComGateway.new(api_key: 'NOT_A_REAL_API_KEY')
    assert_raise ActiveMerchant::ResponseError, 'No api key was found for NOT_A_REAL_API_KEY' do
      response = gateway.purchase(@amount, @credit_card, @options)
    end
  end
end
