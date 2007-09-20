require File.dirname(__FILE__) + '/../../test_helper'
class ViaklixTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  def setup
    @gateway = ViaklixGateway.new(
      :login => 'LOGIN',
      :password => 'PIN'
    )
    
    @creditcard = credit_card('4242424242424242')
    
    @options = {
      :order_id => '37',
      :email => "paul@domain.com",
      :description => 'Test Transaction',
      :address => { 
         :address1 => '164 Waverley Street', 
         :address2 => 'APT #7', 
         :country => 'US', 
         :city => 'Boulder', 
         :state => 'CO', 
         :zip => '12345' 
         }     
    }
  end
  
  def test_purchase_success    
    @creditcard.number = 1

    assert response = @gateway.purchase(100, @creditcard)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal true, response.success?
  end

  def test_purchase_error
    @creditcard.number = 2

    assert response = @gateway.purchase(100, @creditcard, :order_id => 1)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal false, response.success?

  end
  
  def test_purchase_exceptions
    @creditcard.number = 3 
    
    assert_raise(Error) do
      assert response = @gateway.purchase(100, @creditcard, :order_id => 1)    
    end
  end
  
  def test_invalid_login
    @gateway.expects(:ssl_post).returns(invalid_login_response)
    
    assert response = @gateway.purchase(100, @creditcard, :order_id => 1)
    
    assert_equal '7000', response.params['result']
    assert_equal 'The viaKLIX ID and/or User ID supplied in the authorization request is invalid.', response.params['result_message']
    assert_failure response
  end
  
  private
  
  def invalid_login_response
    <<-RESPONSE
ssl_result=7000\r
ssl_result_message=The viaKLIX ID and/or User ID supplied in the authorization request is invalid.\r
    RESPONSE
  end
end