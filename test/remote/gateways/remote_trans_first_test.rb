require 'test_helper'

class RemoteTransFirstTest < Test::Unit::TestCase

  def setup
    @gateway = TransFirstGateway.new(fixtures(:trans_first))

    @credit_card = credit_card('4485896261017708', verification_value: 999)
    @check = check
    @amount = 1201
    @options = {
      :order_id => generate_unique_id,
      :invoice => 'ActiveMerchant Sale',
      :billing_address => address
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert response.test?
    assert_success response
    assert !response.authorization.blank?

    @gateway.void(response.authorization)
  end

  def test_successful_purchase_with_echeck
    assert response = @gateway.purchase(@amount, @check, @options)
    assert response.test?
    assert_success response
    assert !response.authorization.blank?
  end

  def test_failed_purchase
    @amount = 21
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Insufficient funds', response.message
  end

  def test_successful_refund_with_echeck
    assert purchase = @gateway.purchase(@amount, @check, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_invalid_login
    gateway = TransFirstGateway.new(
      :login => '',
      :password => ''
    )
    assert response = gateway.purchase(1100, @credit_card, @options)
    assert_failure response
  end
end
