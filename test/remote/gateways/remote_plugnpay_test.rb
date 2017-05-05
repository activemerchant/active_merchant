require 'test_helper'

class PlugnpayTest < Test::Unit::TestCase
  def setup
    @gateway = PlugnpayGateway.new(fixtures(:plugnpay))
    @good_card = credit_card("4111111111111111", first_name: 'cardtest')
    @bad_card = credit_card('1234123412341234')
    @options = {
      :billing_address => address,
      :description => 'Store purchaes'
    }
    @amount = 100
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @good_card, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'Success', response.message
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@amount, @bad_card, @options)
    assert_failure response
    assert_equal 'Invalid Credit Card No.', response.message
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @good_card, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @bad_card, @options)
    assert_failure response
    assert_equal 'Invalid Credit Card No.', response.message
  end

  # Capture, and Void require that you Whitelist your IP address.
  # In the gateway admin tool, you must add your IP address to the allowed addresses and uncheck "Remote client" under the
  # "Auth Transactions" section of the "Security Requirements" area in the test account Security Administration Area.
  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @good_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert capture.params['aux_msg'].include? "has been successfully marked for settlement."
    assert_equal 'Success', capture.message
  end

  def test_authorization_and_partial_capture
    assert authorization = @gateway.authorize(@amount, @good_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount - 1, authorization.authorization)
    assert_success capture
    assert capture.params['aux_msg'].include? "has been successfully reauthed for usd 0.99"
    assert_equal 'Success', capture.message
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @good_card, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_purchase_and_refund
    assert purchase = @gateway.purchase(@amount, @good_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Success', refund.message
  end

  def test_refund_with_no_previous_transaction
    assert refund = @gateway.refund(@amount, @good_card, @options)

    assert_success refund
    assert_equal 'Success', refund.message
  end
end
