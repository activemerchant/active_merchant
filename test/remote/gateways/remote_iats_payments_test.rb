require 'test_helper'

class IatsPaymentsTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = IatsPaymentsGateway.new(fixtures(:iats_payments))
    @amount = 100
    @credit_card = credit_card('4222222222222220')
    @check = check
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'Success', response.message
    assert response.authorization
  end

  def test_failed_purchase
    credit_card = credit_card('4111111111111111')
    assert response = @gateway.purchase(200, credit_card, @options)
    assert_failure response
    assert response.test?
    assert response.message.include?('REJECT')
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    credit_card = credit_card('4111111111111111')
    purchase = @gateway.purchase(@amount, credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_failure refund
  end

  def test_invalid_login
    gateway = IatsPaymentsGateway.new(
      :agent_code => 'X',
      :password => 'Y',
      :region => 'na'
    )

    assert response = gateway.purchase(@amount, @credit_card)
    assert_failure response
  end
end
