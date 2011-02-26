require 'test_helper'

class FederatedCanadaTest < Test::Unit::TestCase
  def setup
    @gateway = FederatedCanadaGateway.new(
                 :login => 'demo',
                 :password => 'password'
               )

    @credit_card = credit_card
    @credit_card.number = '4111111111111111'
    @credit_card.month = '11'
    @credit_card.year = '2011'

    @credit_card.verification_value = '999'
    @amount = 100

    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    options = {:billing_address => {:address1 => '888', :address2 => "apt 13", :country => 'CA', :state => 'SK', :city => "Big Beaver", :zip => "77777"}}
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1355694937', response.authorization
    assert_equal 'auth', response.params['type']
  end
  
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1346648416', response.authorization
    assert_equal 'sale', response.params['type']    
    assert response.test?
  end
  
  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_add_address
    result = {}
    @gateway.send(:add_address, result, :billing_address => {:address1 => '123 Happy Town Road', :address2 => "apt 13", :country => 'CA', :state => 'SK', :phone => '1234567890'} )
    assert_equal ["address1", "address2", "city", "company", "country", "phone", "state", "zip"], result.stringify_keys.keys.sort
    assert_equal 'SK', result[:state]
    assert_equal '123 Happy Town Road', result[:address1]
    assert_equal 'apt 13', result[:address2]    
    assert_equal 'CA', result[:country]
  end

  def test_add_invoice
    result = {}
    @gateway.send(:add_invoice, result, :order_id => '#1001', :description => "This is a great order")
    assert_equal '#1001', result[:orderid]
    assert_equal 'This is a great order', result[:orderdescription]
  end
   
  def test_purchase_is_valid_csv
    params = {:amount => @amount}
    @gateway.send(:add_creditcard, params, @credit_card)

    assert data = @gateway.send(:post_data, 'auth', params)
    assert_equal post_data_fixture.size, data.size
  end
  
  
  def test_purchase_meets_minimum_requirements
    params = {:amount => @amount}
    @gateway.send(:add_creditcard, params, @credit_card)
    assert data = @gateway.send(:post_data, 'auth', params)
    minimum_requirements.each do |key|
      assert_not_nil(data.include?(key))
    end
  end
   
  def test_expdate_formatting
    assert_equal '0909', @gateway.send(:expdate, credit_card('4111111111111111', :month => "9", :year => "2009"))
    assert_equal '0711', @gateway.send(:expdate, credit_card('4111111111111111', :month => "7", :year => "2011"))
  end

  def test_supported_countries
    assert_equal ['CA'], @gateway.supported_countries
  end

  def test_supported_card_types
    assert_equal @gateway.supported_cardtypes, [:visa, :master, :american_express, :discover]
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'Y', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'M', response.cvv_result['code']
  end
  
  def test_amount
    assert_equal '1.00', @gateway.send(:amount, 100)
    assert_equal '10.00', @gateway.send(:amount, 1000)
    assert_raise(ArgumentError) do
      @gateway.send(:amount, '10.00')
    end
  end
  
  private
  
  def post_data_fixture
    "password=password&type=auth&ccnumber=4111111111111111&username=demo&ccexp=1111&amount=100&cvv=999"
  end
  
  def minimum_requirements
    %w{type username password amount ccnumber ccexp}
  end
  
  # Raw successful authorization response
  def successful_authorization_response
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=1355694937&avsresponse=Y&cvvresponse=M&orderid=&type=auth&response_code=100"
  end

  # Raw successful purchase response
  def successful_purchase_response
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=1346648416&avsresponse=N&cvvresponse=N&orderid=&type=sale&response_code=100"
  end
  
  # Raw failed sale response
  def failed_purchase_response
    "response=2&responsetext=DECLINE&authcode=&transactionid=1346648595&avsresponse=N&cvvresponse=N&orderid=&type=sale&response_code=200"
  end
end
