require File.dirname(__FILE__) + '/../../test_helper'

class ProtxTest < Test::Unit::TestCase
  def setup
    @gateway = ProtxGateway.new(
      :login => 'X'
    )

    @creditcard = credit_card('4242424242424242', :type => 'visa')
  end

  def test_purchase_success    
    @creditcard.number = 1

    assert response = @gateway.purchase(100, @creditcard, :order_id => 1)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_success response
  end

  def test_purchase_error
    @creditcard.number = 2

    assert response = @gateway.purchase(100, @creditcard, :order_id => 1)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_failure response
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
    assert_success response
    
    assert_equal "1;{7307C8A9-766E-4BD1-AC41-3C34BB83F7E5};5559;WIUMDJS607", response.authorization
  end
  
  def test_purchase_url
    assert_equal 'https://ukvpstest.protx.com/vspgateway/service/vspdirect-register.vsp', @gateway.send(:build_endpoint_url, :purchase)
  end
  
  def test_capture_url
    assert_equal 'https://ukvpstest.protx.com/vspgateway/service/release.vsp', @gateway.send(:build_endpoint_url, :capture)
  end
  
  def test_electron_cards
    # Visa range
    assert_no_match ProtxGateway::ELECTRON, '4245180000000000'
    
    # First electron range
    assert_match ProtxGateway::ELECTRON, '4245190000000000'
                                                                
    # Second range                                              
    assert_match ProtxGateway::ELECTRON, '4249620000000000'
    assert_match ProtxGateway::ELECTRON, '4249630000000000'
                                                                
    # Third                                                     
    assert_match ProtxGateway::ELECTRON, '4508750000000000'
                                                                
    # Fourth                                                    
    assert_match ProtxGateway::ELECTRON, '4844060000000000'
    assert_match ProtxGateway::ELECTRON, '4844080000000000'
                                                                
    # Fifth                                                     
    assert_match ProtxGateway::ELECTRON, '4844110000000000'
    assert_match ProtxGateway::ELECTRON, '4844550000000000'
                                                                
    # Sixth                                                     
    assert_match ProtxGateway::ELECTRON, '4917300000000000'
    assert_match ProtxGateway::ELECTRON, '4917590000000000'
                                                                
    # Seventh                                                   
    assert_match ProtxGateway::ELECTRON, '4918800000000000'
    
    # Visa
    assert_no_match ProtxGateway::ELECTRON, '4918810000000000'
    
    # 19 PAN length
    assert_match ProtxGateway::ELECTRON, '4249620000000000000'
    
    # 20 PAN length
    assert_no_match ProtxGateway::ELECTRON, '42496200000000000'
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
