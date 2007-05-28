require File.dirname(__FILE__) + '/../../test_helper'

class AuthorizeNetTest < Test::Unit::TestCase
  def setup
    @gateway = AuthorizeNetGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    @creditcard = credit_card('4242424242424242')
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
   
   @gateway.send(:add_creditcard, params, @creditcard)

   assert data = @gateway.send(:post_data, 'AUTH_ONLY', params)
   assert_equal post_data_fixture.size, data.size
  end 

  def test_purchase_meets_minimum_requirements
    params = { 
      :amount => "1.01",
    }                                                         

    @gateway.send(:add_creditcard, params, @creditcard)

    assert data = @gateway.send(:post_data, 'AUTH_ONLY', params)
    minimum_requirements.each do |key|
      assert_not_nil(data =~ /x_#{key}=/)
    end
  end
  
  def test_credit_success
    assert response = @gateway.credit(100, '123456789', :card_number => '1')
    assert response.success?
  end
  
  def test_credit_failure
    assert response = @gateway.credit(100, '123456789', :card_number => '2')
    assert !response.success?
  end
  
  def test_supported_countries
    assert_equal ['US'], AuthorizeNetGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], AuthorizeNetGateway.supported_cardtypes
  end

  private

  def post_data_fixture
    'x_encap_char=%24&x_card_num=4242424242424242&x_exp_date=0806&x_card_code=123&x_type=AUTH_ONLY&x_first_name=Longbob&x_version=3.1&x_login=X&x_last_name=Longsen&x_tran_key=Y&x_relay_response=FALSE&x_delim_data=TRUE&x_delim_char=%2C&x_amount=1.01'
  end
  
 def minimum_requirements
    %w(version delim_data relay_response login tran_key amount card_num exp_date type)
  end

end
