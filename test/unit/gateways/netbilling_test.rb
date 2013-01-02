require 'test_helper'

class NetbillingTest < Test::Unit::TestCase
  include CommStub
  
  def setup
    @gateway = NetbillingGateway.new(:login => 'login')

    @credit_card = credit_card('4242424242424242')
    @amount = 100
    @options = { :billing_address => address }
  end
  
  def test_successful_request
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '110270311543', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'X', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end
  
  def test_site_tag_sent_if_provided
    @gateway = NetbillingGateway.new(:login => 'login', :site_tag => 'dummy-site-tag')
    
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/site_tag=dummy-site-tag/, data)
    end.respond_with(successful_purchase_response)
  
    assert_success response
  end

  def test_site_tag_not_sent_if_not_provided
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_no_match(/site_tag/, data)
    end.respond_with(successful_purchase_response)
  
    assert_success response
  end

  private
  def successful_purchase_response
    "avs_code=X&cvv2_code=M&status_code=1&auth_code=999999&trans_id=110270311543&auth_msg=TEST+APPROVED&auth_date=2008-01-25+16:43:54"
  end
  
  def unsuccessful_purchase_response
    "status_code=0&auth_msg=CARD+EXPIRED&trans_id=110492608613&auth_date=2008-01-25+17:47:44"
  end
end
