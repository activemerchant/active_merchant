require 'test_helper'

class LucyTest < Test::Unit::TestCase
  def setup
    
    @gateway = LucyGateway.new(
                 :login => 'X',
                 :password => 'Y',
                 :test => true
               )

    @credit_card = ::ActiveMerchant::Billing::CreditCard.new({
                  :number => '4005551155111114',
                  :month => 10,
                  :year => Time.now.year + 1,
                  :first_name => 'John',
                  :last_name => 'Doe'
                })
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    assert_equal '13266', response.authorization
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
  
  def test_expired_credit_card
    @gateway.expects(:ssl_post).returns(expired_credit_card_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
  
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '13349', response.authorization
  end

  private
  
  def successful_purchase_response
    "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<Response xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"SmartPayments\">\r\n  <Result>0</Result>\r\n  <RespMSG>Approved</RespMSG>\r\n  <Message>APPROVED</Message>\r\n  <AuthCode>095331</AuthCode>\r\n  <PNRef>13266</PNRef>\r\n  <HostCode>00000000</HostCode>\r\n  <GetCommercialCard>False</GetCommercialCard>\r\n  <ExtData>CardType=VISA,BatchNum=000000&lt;BatchNum&gt;000000&lt;/BatchNum&gt;</ExtData>\r\n</Response>"
  end
  
  def failed_purchase_response
    "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<Response xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"SmartPayments\">\r\n  <Result>12</Result>\r\n  <RespMSG>Decline</RespMSG>\r\n  <Message>DECLINED</Message>\r\n  <AuthCode>AUTH  DECLINED  200</AuthCode>\r\n  <PNRef>13315</PNRef>\r\n  <HostCode>00000000</HostCode>\r\n  <GetCommercialCard>False</GetCommercialCard>\r\n  <ExtData>CardType=VISA,BatchNum=000000&lt;BatchNum&gt;000000&lt;/BatchNum&gt;</ExtData>\r\n</Response>"
  end

  def expired_credit_card_response
    "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<Response xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"SmartPayments\">\r\n  <Result>24</Result>\r\n  <RespMSG>Invalid Expiration Date</RespMSG>\r\n  <ExtData>CardType=VISA</ExtData>\r\n</Response>"
  end

  def successful_authorization_response
    "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<Response xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"SmartPayments\">\r\n  <Result>0</Result>\r\n  <RespMSG>Approved</RespMSG>\r\n  <Message>APPROVED</Message>\r\n  <AuthCode>095431</AuthCode>\r\n  <PNRef>13349</PNRef>\r\n  <HostCode>00000000</HostCode>\r\n  <GetCommercialCard>False</GetCommercialCard>\r\n  <ExtData>CardType=VISA,BatchNum=000000&lt;BatchNum&gt;000000&lt;/BatchNum&gt;</ExtData>\r\n</Response>"
  end

end
