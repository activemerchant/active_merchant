require 'test_helper'

class JetpayTest < Test::Unit::TestCase
  include ActiveMerchant::Billing

  def setup
    Base.gateway_mode = :test

    @gateway = JetpayGateway.new(:login => 'login')
    
    @credit_card = credit_card
    @amount = 100
    
    @options = {
      :order_id => '1',
      :billing_address => address(:country => 'US'),
      :shipping_address => address(:country => 'US'),
      :email => 'test@test.com',
      :ip => '127.0.0.1',
      :order_id => '12345',
      :tax => 7
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    
    assert_equal '707a4f1750d8dc03bd;TEST47;100', response.authorization
    assert_equal('TEST47', response.params["approval"])
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal('7605f7c5d6e8f74deb;;100', response.authorization)
    assert response.test?
  end
  
  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    
    assert_equal('010327153017T10018;502F6B;100', response.authorization)
    assert_equal('502F6B', response.params["approval"])
    assert response.test?
  end
  
  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    
    assert response = @gateway.capture(1111, "010327153017T10018;502F7B;1111")
    assert_success response
    
    assert_equal('010327153017T10018;502F6B;1111', response.authorization)
    assert_equal('502F6B', response.params["approval"])
    assert response.test?
  end
  
  def test_successful_void
    # no need for csv
    card = credit_card('4242424242424242', :verification_value => nil)
    
    @gateway.expects(:ssl_post).returns(successful_void_response)
    
    assert response = @gateway.void('010327153x17T10418;502F7B;500')
    assert_success response
    
    assert_equal('010327153x17T10418;502F7B;500', response.authorization)
    assert_equal('502F7B', response.params["approval"])
    assert response.test?
  end
  
  def test_successful_credit
    # no need for csv
    card = credit_card('4242424242424242', :verification_value => nil)

    @gateway.expects(:ssl_post).returns(successful_credit_response)
    
    # linked credit # now deprecated, use refund
    assert response = @gateway.credit(9900, '010327153017T10017')
    assert_success response
    
    assert_equal('010327153017T10017;002F6B;9900', response.authorization)
    assert_equal('002F6B', response.params['approval'])
    assert response.test?
    
    # unlinked credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    
    assert response = @gateway.credit(9900, card)
    assert_success response    
  end
  
  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    
    # linked credit
    assert response = @gateway.refund(9900, '010327153017T10017')
    assert_success response
    
    assert_equal('010327153017T10017;002F6B;9900', response.authorization)
    assert_equal('002F6B', response.params['approval'])
    assert response.test?
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'Y', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'P', response.cvv_result['code']
  end
  
  
  private
  def successful_purchase_response
    <<-EOF
    <JetPayResponse><TransactionID>707a4f1750d8dc03bd</TransactionID>
      <ActionCode>000</ActionCode>
      <Approval>TEST47</Approval>
      <CVV2>P</CVV2>
      <ResponseText>APPROVED</ResponseText>
      <AddressMatch>Y</AddressMatch>
      <ZipMatch>Y</ZipMatch>
      <AVS>Y</AVS>
    </JetPayResponse>
    EOF
  end
  
  def failed_purchase_response
    <<-EOF
      <JetPayResponse>
        <TransactionID>7605f7c5d6e8f74deb</TransactionID>
        <ActionCode>005</ActionCode>
        <ResponseText>DECLINED</ResponseText>
      </JetPayResponse>
    EOF
  end
  
  def successful_authorize_response
    <<-EOF
      <JetPayResponse>
        <TransactionID>010327153017T10018</TransactionID>
        <ActionCode>000</ActionCode>
        <Approval>502F6B</Approval>
        <ResponseText>APPROVED</ResponseText>
      </JetPayResponse>
    EOF
  end
  
  def successful_capture_response
    <<-EOF
      <JetPayResponse>
        <TransactionID>010327153017T10018</TransactionID>
        <ActionCode>000</ActionCode>
        <Approval>502F6B</Approval>
        <ResponseText>APPROVED</ResponseText>
      </JetPayResponse>
    EOF
  end
  
  def successful_void_response
    <<-EOF
      <JetPayResponse>
        <TransactionID>010327153x17T10418</TransactionID>
        <ActionCode>000</ActionCode>
        <Approval>502F7B</Approval>
        <ResponseText>VOID PROCESSED</ResponseText>
      </JetPayResponse>
    EOF
  end
  
  def successful_credit_response
    <<-EOF
      <JetPayResponse>
        <TransactionID>010327153017T10017</TransactionID>
        <ActionCode>000</ActionCode>
        <Approval>002F6B</Approval>
        <ResponseText>APPROVED</ResponseText>
      </JetPayResponse>
    EOF
  end
end
