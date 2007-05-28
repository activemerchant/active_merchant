require File.dirname(__FILE__) + '/../../test_helper'

class MonerisResponseTest < Test::Unit::TestCase
  def setup
    @gateway = MonerisGateway.new(
      :login => 'store1',
      :password => 'yesguy'
    )

    @creditcard = credit_card('4242424242424242')
  end

  def teardown
    Base.mode = :test
  end
  
  def test_purchase_success    
    @creditcard.number = 1

    assert response = @gateway.purchase(100, @creditcard, :order_id => 1)
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
  
  def test_purchase_is_valid_xml

   params = { 
     :order_id => "order1",
     :amount => "1.01",
     :pan => "4242424242424242",
     :expdate => "0303",
     :crypt_type => 7,                                                  
   }

   assert data = @gateway.send(:post_data, 'preauth', params)
   assert REXML::Document.new(data)
   assert_equal xml_capture_fixture.size, data.size
  end  

  private

  def xml_purchase_fixture
   %q{<request><store_id>store1</store_id><api_token>yesguy</api_token><purchase><amount>1.01</amount><pan>4242424242424242</pan><expdate>0303</expdate><crypt_type>7</crypt_type><order_id>order1</order_id></purchase></request>}
  end

  def xml_capture_fixture
   %q{<request><store_id>store1</store_id><api_token>yesguy</api_token><preauth><amount>1.01</amount><pan>4242424242424242</pan><expdate>0303</expdate><crypt_type>7</crypt_type><order_id>order1</order_id></preauth></request>}
  end

end


class MonerisRequestTest < Test::Unit::TestCase
  def setup
    @gateway = MonerisGateway.new(
      :login => 'store1',
      :password => 'yesguy'
    )
  end


  def test_purchase_is_valid_xml

   params = {
     :order_id => "order1",
     :amount => "1.01",
     :pan => "4242424242424242",
     :expdate => "0303",
     :crypt_type => 7,
   }

   assert data = @gateway.send(:post_data, 'purchase', params)
   assert REXML::Document.new(data)
   assert_equal xml_purchase_fixture.size, data.size
  end

  def test_capture_is_valid_xml
 
   params = { 
     :order_id => "order1",
     :amount => "1.01",
     :pan => "4242424242424242",
     :expdate => "0303",
     :crypt_type => 7,                                                  
   }

   assert data = @gateway.send(:post_data, 'preauth', params)
   assert REXML::Document.new(data)
   assert_equal xml_capture_fixture.size, data.size
  end  

  def test_access_url_for_test_environment
    Base.mode = :test
    gateway = MonerisGateway.new(
      :login => 'store1',
      :password => 'yesguy'
    )

    assert_equal 'https://esqa.moneris.com/gateway2/servlet/MpgRequest', gateway.url
  end
  
  def test_access_url_for_production_environment
    Base.mode = :production
    gateway = MonerisGateway.new(
      :login => 'store1',
      :password => 'yesguy'
    )

    assert_equal 'https://www3.moneris.com/gateway2/servlet/MpgRequest', gateway.url
  end
  
  def test_supported_countries
    assert_equal ['CA'], MonerisGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master], MonerisGateway.supported_cardtypes
  end

  private

  def xml_purchase_fixture
   %q{<request><store_id>store1</store_id><api_token>yesguy</api_token><purchase><amount>1.01</amount><pan>4242424242424242</pan><expdate>0303</expdate><crypt_type>7</crypt_type><order_id>order1</order_id></purchase></request>}
  end

  def xml_capture_fixture
   %q{<request><store_id>store1</store_id><api_token>yesguy</api_token><preauth><amount>1.01</amount><pan>4242424242424242</pan><expdate>0303</expdate><crypt_type>7</crypt_type><order_id>order1</order_id></preauth></request>}
  end

end
