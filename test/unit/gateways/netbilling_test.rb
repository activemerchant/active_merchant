require File.dirname(__FILE__) + '/../../test_helper'

class NetbillingTest < Test::Unit::TestCase
  AMOUNT = 100

  def setup
    @gateway = NetbillingGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @creditcard = credit_card('4242424242424242')

    @address = { :address1 => '1234 My Street',
                 :address2 => 'Apt 1',
                 :company => 'Widgets Inc',
                 :city => 'Ottawa',
                 :state => 'ON',
                 :zip => 'K1C2N6',
                 :country => 'Canada',
                 :phone => '(555)555-5555'
               }
    @options = { :address => @address }
  end
  
  def test_successful_request
    @creditcard.number = 1
    assert response = @gateway.purchase(AMOUNT, @creditcard, @options)
    assert_success response
    assert_equal '5555', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @creditcard.number = 2
    assert response = @gateway.purchase(AMOUNT, @creditcard, @options)
    assert_failure response
    assert response.test?
  end

  def test_request_error
    @creditcard.number = 3
    assert_raise(Error){ @gateway.purchase(AMOUNT, @creditcard, @options) }
  end
end
