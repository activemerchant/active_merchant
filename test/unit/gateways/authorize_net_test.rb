require File.dirname(__FILE__) + '/../../test_helper'

class AuthorizeNetTest < Test::Unit::TestCase
  def setup
    @gateway = AuthorizeNetGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    @credit_card = credit_card('4242424242424242')
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
  
    assert response = @gateway.authorize(100, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '508141794', response.authorization
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
  
    assert response = @gateway.authorize(100, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '508141795', response.authorization
  end
  
  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)
  
    assert response = @gateway.authorize(100, @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '508141794', response.authorization
  end
  
  def test_purchase_exception
    @gateway.expects(:ssl_post).raises(Error)
    
    assert_raise(Error) do
      assert response = @gateway.purchase(100, @credit_card, :order_id => 1)    
    end
  end
  
  def test_amount_style
   assert_equal '10.34', @gateway.send(:amount, 1034)
                                                      
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end
  
  def test_add_address_outsite_north_america
    result = {}
    
    @gateway.send(:add_address, result, :billing_address => {:address1 => '164 Waverley Street', :country => 'DE', :state => ''} )
    
    assert_equal ["address", "city", "company", "country", "phone", "state", "zip"], result.stringify_keys.keys.sort
    assert_equal 'n/a', result[:state]
    assert_equal '164 Waverley Street', result[:address] 
    assert_equal 'DE', result[:country] 
    
  end
                                                             
  def test_add_address
    result = {}
    
    @gateway.send(:add_address, result, :billing_address => {:address1 => '164 Waverley Street', :country => 'US', :state => 'CO'} )
    
    assert_equal ["address", "city", "company", "country", "phone", "state", "zip"], result.stringify_keys.keys.sort
    assert_equal 'CO', result[:state]
    assert_equal '164 Waverley Street', result[:address]
    assert_equal 'US', result[:country]
    
  end

  def test_add_invoice
    result = {}
    @gateway.send(:add_invoice, result, :order_id => '#1001')
    assert_equal '#1001', result[:invoice_num]
  end
  
  def test_add_description
    result = {}
    @gateway.send(:add_invoice, result, :description => 'My Purchase is great')
    assert_equal 'My Purchase is great', result[:description]
  end
  
  def test_purchase_is_valid_csv
   params = { :amount => '1.01' }
   
   @gateway.send(:add_creditcard, params, @credit_card)

   assert data = @gateway.send(:post_data, 'AUTH_ONLY', params)
   assert_equal post_data_fixture.size, data.size
  end 

  def test_purchase_meets_minimum_requirements
    params = { 
      :amount => "1.01",
    }                                                         

    @gateway.send(:add_creditcard, params, @credit_card)

    assert data = @gateway.send(:post_data, 'AUTH_ONLY', params)
    minimum_requirements.each do |key|
      assert_not_nil(data =~ /x_#{key}=/)
    end
  end
  
  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.credit(100, '123456789', :card_number => @credit_card.number)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end
  
  def test_failed_credit
    @gateway.expects(:ssl_post).returns(failed_credit_response)
    
    assert response = @gateway.credit(100, '123456789', :card_number => @credit_card.number)
    assert_failure response
    assert_equal 'The referenced transaction does not meet the criteria for issuing a credit', response.message
  end
  
  def test_supported_countries
    assert_equal ['US'], AuthorizeNetGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], AuthorizeNetGateway.supported_cardtypes
  end
  
  def test_failure_without_response_reason_text
    assert_nothing_raised do
      assert_equal '', @gateway.send(:message_from, {})
    end
  end
  
  def test_response_under_review_by_fraud_service
    @gateway.expects(:ssl_post).returns(fraud_review_response)
    
    response = @gateway.purchase(100, @credit_card)
    assert_failure response
    assert response.fraud_review?
    assert_equal "Thank you! For security reasons your order is currently being reviewed", response.message
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(fraud_review_response)
    
    response = @gateway.purchase(100, @credit_card)
    assert_equal 'X', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(fraud_review_response)
    
    response = @gateway.purchase(100, @credit_card)
    assert_equal 'M', response.cvv_result['code']
  end
  
  def test_card_data
    @gateway.expects(:ssl_post).returns(fraud_review_response)
    
    response = @gateway.purchase(100, @credit_card)
    assert_equal CreditCard.last_digits(@credit_card.number), response.card_data['number']
  end

  private

  def post_data_fixture
    'x_encap_char=%24&x_card_num=4242424242424242&x_exp_date=0806&x_card_code=123&x_type=AUTH_ONLY&x_first_name=Longbob&x_version=3.1&x_login=X&x_last_name=Longsen&x_tran_key=Y&x_relay_response=FALSE&x_delim_data=TRUE&x_delim_char=%2C&x_amount=1.01'
  end
  
  def minimum_requirements
    %w(version delim_data relay_response login tran_key amount card_num exp_date type)
  end
  
  def failed_credit_response
    '$3$,$2$,$54$,$The referenced transaction does not meet the criteria for issuing a credit.$,$$,$P$,$0$,$$,$$,$1.00$,$CC$,$credit$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$39265D8BA0CDD4F045B5F4129B2AAA01$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end
  
  def successful_authorization_response
    '$1$,$1$,$1$,$This transaction has been approved.$,$advE7f$,$Y$,$508141794$,$5b3fe66005f3da0ebe51$,$$,$1.00$,$CC$,$auth_only$,$$,$Longbob$,$Longsen$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$2860A297E0FE804BCB9EF8738599645C$,$P$,$2$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end
  
  def successful_purchase_response
    '$1$,$1$,$1$,$This transaction has been approved.$,$d1GENk$,$Y$,$508141795$,$32968c18334f16525227$,$Store purchase$,$1.00$,$CC$,$auth_capture$,$$,$Longbob$,$Longsen$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$269862C030129C1173727CC10B1935ED$,$P$,$2$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end
  
  def failed_authorization_response
    '$2$,$1$,$1$,$This transaction was declined.$,$advE7f$,$Y$,$508141794$,$5b3fe66005f3da0ebe51$,$$,$1.00$,$CC$,$auth_only$,$$,$Longbob$,$Longsen$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$2860A297E0FE804BCB9EF8738599645C$,$P$,$2$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end
 
  def fraud_review_response
    "$4$,$$,$253$,$Thank you! For security reasons your order is currently being reviewed.$,$$,$X$,$0$,$$,$$,$1.00$,$$,$auth_capture$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$207BCBBF78E85CF174C87AE286B472D2$,$M$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$"
  end
end
