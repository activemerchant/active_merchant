require File.dirname(__FILE__) + '/../../test_helper'

class NetbillingTest < Test::Unit::TestCase
  def setup
    @gateway = NetbillingGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @creditcard = credit_card('4242424242424242')
    @amount = 100
    @options = { :billing_address => address }
  end
  
  def test_successful_request
    @creditcard.number = 1
    assert response = @gateway.purchase(@amount, @creditcard, @options)
    assert_success response
    assert_equal '5555', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @creditcard.number = 2
    assert response = @gateway.purchase(@amount, @creditcard, @options)
    assert_failure response
    assert response.test?
  end
end
