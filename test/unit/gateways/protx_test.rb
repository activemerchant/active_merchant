require File.dirname(__FILE__) + '/../../test_helper'

class ProtxTest < Test::Unit::TestCase
  def setup
    @gateway = ProtxGateway.new(
      :login => 'X'
    )

    @creditcard = credit_card('4242424242424242')
  end

  def test_purchase_success    
    @creditcard.number = 1

    assert response = @gateway.purchase(100, @creditcard, :order_id => 1)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert response.success?
  end

  def test_purchase_error
    @creditcard.number = 2

    assert response = @gateway.purchase(100, @creditcard, :order_id => 1)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert !response.success?
  end
  
  def test_purchase_exceptions
    @creditcard.number = 3 
    
    assert_raise(Error) do
      assert response = @gateway.purchase(100, @creditcard, :order_id => 1)    
    end
  end
  
  def test_authorization_format
    @gateway.expects(:ssl_post).returns(successful_response)
    
    assert response = @gateway.purchase(100, @creditcard, :order_id => 1)
    assert response.success?
    
    assert_equal "1;{7307C8A9-766E-4BD1-AC41-3C34BB83F7E5};5559;WIUMDJS607", response.authorization
  end
  
  def test_purchase_url
    assert_equal 'https://ukvpstest.protx.com/vspgateway/service/vspdirect-register.vsp', @gateway.send(:build_endpoint_url, :purchase)
  end
  
  def test_capture_url
    assert_equal 'https://ukvpstest.protx.com/vspgateway/service/release.vsp', @gateway.send(:build_endpoint_url, :capture)
  end

  private

  def successful_response
    <<-RESP
VPSProtocol=2.22 
Status=OK
StatusDetail=VSP Direct transaction from VSP Simulator.
VPSTxId={7307C8A9-766E-4BD1-AC41-3C34BB83F7E5}
SecurityKey=WIUMDJS607
TxAuthNo=5559
AVSCV2=NO DATA MATCHES
AddressResult=NOTMATCHED
PostCodeResult=MATCHED
CV2Result=NOTMATCHED
    RESP
  end
end
