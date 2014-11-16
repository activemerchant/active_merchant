require 'test_helper'

class RemoteIppTest < Test::Unit::TestCase
  def setup
    @gateway = IppGateway.new(fixtures(:ipp))

    @credit_card = credit_card('4005550000000001')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(200, @credit_card, @options)
    assert_success response
    assert_equal '', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(105, @credit_card, @options)
    assert_failure response
    assert_equal 'Do Not Honour', response.message
  end

  def test_invalid_login
    gateway = IppGateway.new(
      login: '',
      password: '',
    )
    response = gateway.purchase(200, @credit_card, @options)
    assert_failure response
  end
end
