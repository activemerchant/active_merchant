require File.dirname(__FILE__) + '/../../test_helper'

class BrainTreeTest < Test::Unit::TestCase
  
  def setup
    @gateway = BrainTreeGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @creditcard = credit_card('4242424242424242')
    @amount = rand(9999)+1001
    @address = { :address1 => '1234 My Street',
                 :address2 => 'Apt 1',
                 :company => 'Widgets Inc',
                 :city => 'Ottawa',
                 :state => 'ON',
                 :zip => 'K1C2N6',
                 :country => 'Canada',
                 :phone => '(555)555-5555'
               }
  end
  
  def test_successful_request
    @creditcard.number = 1
    assert response = @gateway.purchase(@amount, @creditcard, {})
    assert_success response
    assert_equal '5555', response.authorization
  end

  def test_unsuccessful_request
    @creditcard.number = 2
    assert response = @gateway.purchase(@amount, @creditcard, {})
    assert_failure response
  end

  def test_request_error
    @creditcard.number = 3
    assert_raise(Error){ @gateway.purchase(@amount, @creditcard, {}) }
  end
  
  def test_add_address
    result = {}
    
    @gateway.send(:add_address, result,nil, :billing_address => {:address1 => '164 Waverley Street', :country => 'US', :state => 'CO'} )
    assert_equal ["address1", "city", "company", "country", "phone", "state", "zip"], result.stringify_keys.keys.sort
    assert_equal 'CO', result[:state]
    assert_equal '164 Waverley Street', result[:address1]
    assert_equal 'US', result[:country]
    
  end
  
  def test_supported_countries
    assert_equal ['US'], AuthorizeNetGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], AuthorizeNetGateway.supported_cardtypes
  end
  
  def test_adding_store_adds_vault_id_flag
    result = {}
    
    @gateway.send(:add_creditcard, result,@creditcard, :store=>true )
    assert_equal ["ccexp", "ccnumber", "customer_vault", "cvv", "firstname", "lastname"], result.stringify_keys.keys.sort
    assert_equal 'add_customer', result[:customer_vault]
    
  end
  def test_blank_store_doesnt_add_vault_flag
    result = {}
    
    @gateway.send(:add_creditcard, result,@creditcard, {} )
    assert_equal ["ccexp", "ccnumber", "cvv", "firstname", "lastname"], result.stringify_keys.keys.sort
    assert_nil result[:customer_vault]
    
  end
end
