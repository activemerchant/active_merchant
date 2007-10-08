require File.dirname(__FILE__) + '/../../test_helper'

class PaySecureTest < Test::Unit::TestCase
  AMOUNT = 100

  def setup
    @gateway = PaySecureGateway.new(
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
  end
  
  def test_successful_request
    @creditcard.number = 1
    assert response = @gateway.purchase(AMOUNT, @creditcard, :order_id => 1)
    assert_success response
    assert_equal '5555', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @creditcard.number = 2
    assert response = @gateway.purchase(AMOUNT, @creditcard, :order_id => 1)
    assert_failure response
    assert response.test?
  end

  def test_request_error
    @creditcard.number = 3
    assert_raise(Error){ @gateway.purchase(AMOUNT, @creditcard, :order_id => 1) }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_response)
    assert response = @gateway.purchase(AMOUNT, @creditcard, :order_id => 1)
    assert_success response
    assert response.test?
  end
  
  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failure_response)
    assert response = @gateway.purchase(AMOUNT, @creditcard, :order_id => 1)
    assert_equal "Field value '8f796cb29a1be32af5ce12d4ca7425c2' does not match required format.", response.message
    assert_failure response
  end
  
  private
  def successful_response
    <<-RESPONSE
Status: Accepted
SettlementDate: 2007-10-09
AUTHNUM: 2778
ErrorString: No Error
CardBin: 1
ERROR: 0
TransID: SimProxy 54041670
    RESPONSE
  end
  
  def failure_response
    <<-RESPONSE
Status: Declined
ErrorString: Field value '8f796cb29a1be32af5ce12d4ca7425c2' does not match required format.
ERROR: 1
    RESPONSE
  end
end
