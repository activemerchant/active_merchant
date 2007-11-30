require File.dirname(__FILE__) + '/../test_helper'

class RemoteSecurePayTechTest < Test::Unit::TestCase
  ACCEPTED_AMOUNT = 10000
  DECLINED_AMOUNT = 10075

  def setup
    @gateway = SecurePayTechGateway.new(fixtures(:secure_pay_tech))
    @creditcard = credit_card('4987654321098769', :month => 5, :year => 2013)
    @options = { :address => { :address1 => '1234 Shady Brook Lane', :zip => '90210' } }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(ACCEPTED_AMOUNT, @creditcard, @options)
    assert_equal 'Transaction OK', response.message
    assert_success response
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(DECLINED_AMOUNT, @creditcard, @options)
    assert_equal 'Card declined', response.message
    assert_failure response
  end

  def test_invalid_login
    gateway = SecurePayTechGateway.new(
                :login => 'foo',
                :password => 'bar'
              )
    assert response = gateway.purchase(ACCEPTED_AMOUNT, @creditcard, @options)
    assert_equal 'Bad or malformed request', response.message
    assert_failure response
  end
end
