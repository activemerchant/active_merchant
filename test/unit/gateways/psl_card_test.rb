require File.dirname(__FILE__) + '/../../test_helper'

class PslCardTest < Test::Unit::TestCase
  include ActiveMerchant::Billing

  # 100 Cents
  AMOUNT = 100

  def setup
    @gateway = PslCardGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @creditcard = credit_card('4242424242424242')
  end
  
  def test_successful_purchase
    @creditcard.number = 1
    assert response = @gateway.purchase(AMOUNT, @creditcard, {})
    assert response.success?
    assert_equal '5555', response.authorization
    assert response.test?
  end
  
  def test_successful_authorization
    @creditcard.number = 1
    assert response = @gateway.authorize(AMOUNT, @creditcard, {})
    assert response.success?
    assert_equal '5555', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @creditcard.number = 2
    assert response = @gateway.purchase(AMOUNT, @creditcard, {})
    assert !response.success?
    assert response.test?
  end

  def test_request_error
    @creditcard.number = 3
    assert_raise(Error){ @gateway.purchase(AMOUNT, @creditcard, {}) }
  end
end