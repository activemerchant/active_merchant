require 'test_helper'

class RemoteSwipeCheckoutTest < Test::Unit::TestCase
  def setup
    @gateway = SwipeCheckoutGateway.new(fixtures(:swipe_checkout))

    @amount = 100
    @accepted_card = credit_card('1234123412341234')
    @declined_card = credit_card('1111111111111111')
    @invalid_card  = credit_card('1000000000000000')
    @empty_card  = credit_card('')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @accepted_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
  end

  def test_region_switching
    assert response = @gateway.purchase(@amount, @accepted_card, @options.merge(:region => 'CA'))
    assert_success response
    assert_equal 'Transaction approved', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transaction declined', response.message
  end

  def test_invalid_login
    gateway = SwipeCheckoutGateway.new(
      login: 'invalid',
      api_key: 'invalid',
      region: 'NZ'
    )
    assert response = gateway.purchase(@amount, @accepted_card, @options)
    assert_failure response
    assert_equal 'Access Denied', response.message
  end

  def test_invalid_card
    # Note: Swipe Checkout transaction API returns declined if the card number
    # is invalid, and "invalid card data" if the card number is empty
    assert response = @gateway.purchase(@amount, @invalid_card, @options)
    assert_failure response
    assert_equal 'Transaction declined', response.message
    assert_equal 200, response.params['response_code']
  end

  def test_empty_card
    assert response = @gateway.purchase(@amount, @empty_card, @options)
    assert_failure response
    assert_equal 'Invalid card data', response.message
    assert_equal 303, response.params['response_code']
  end

  def test_no_options
    assert response = @gateway.purchase(@amount, @accepted_card, {})
    assert_success response
  end
end
