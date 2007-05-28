require File.dirname(__FILE__) + '/../../test_helper'

class UsaEpayTest < Test::Unit::TestCase
  def setup
    @gateway = UsaEpayGateway.new(
      :login => 'LOGIN'
    )

    @creditcard = credit_card('4242424242424242')
    
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
    assert response = @gateway.purchase(100, @creditcard, {})
    assert response.success?
    assert_equal '5555', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @creditcard.number = 2
    assert response = @gateway.purchase(100, @creditcard, {})
    assert !response.success?
    assert response.test?
  end

  def test_request_error
    @creditcard.number = 3
    assert_raise(Error){ @gateway.purchase(100, @creditcard, {}) }
  end

  def test_address_key_prefix
    assert_equal 'bill', @gateway.send(:address_key_prefix, :billing)
    assert_equal 'ship', @gateway.send(:address_key_prefix, :shipping)
    assert_nil @gateway.send(:address_key_prefix, :vacation)
  end

  def test_address_key
    assert_equal :shipfname, @gateway.send(:address_key, 'ship', 'fname')
  end

  def test_add_address
    post = {}
    options = { :address => @address }
    @gateway.send(:add_address, post, @creditcard, options)
    assert_address(:shipping, post)
    assert_equal 20, post.keys.size
  end
  
  def test_add_billing_address
    post = {}
    options = { :billing_address => @address }
    @gateway.send(:add_address, post, @creditcard, options)
    assert_address(:billing, post)
    assert_equal 20, post.keys.size
  end
  
  def test_add_billing_and_shipping_addresses
    post = {}
    options = { :address => @address,
                :billing_address => @address
              }
    @gateway.send(:add_address, post, @creditcard, options)
    assert_address(:shipping, post)
    assert_address(:billing, post)
    assert_equal 20, post.keys.size
  end
  
  def test_amount_style
   assert_equal '10.34', @gateway.send(:amount, 1034)
                                                      
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end
  
  def test_supported_countries
    assert_equal ['US'], UsaEpayGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express], UsaEpayGateway.supported_cardtypes
  end

  private
  def assert_address(type, post) 
    prefix = key_prefix(type)
    assert_equal @creditcard.first_name, post[key(prefix, 'fname')]
    assert_equal @creditcard.last_name, post[key(prefix, 'lname')]
    assert_equal @address[:company], post[key(prefix, 'company')]
    assert_equal @address[:address1], post[key(prefix, 'street')]
    assert_equal @address[:address2], post[key(prefix, 'street2')]
    assert_equal @address[:city], post[key(prefix, 'city')]
    assert_equal @address[:state], post[key(prefix, 'state')]
    assert_equal @address[:zip], post[key(prefix, 'zip')]
    assert_equal @address[:country], post[key(prefix, 'country')]
    assert_equal @address[:phone], post[key(prefix, 'phone')]
  end
  
  def key_prefix(type)
    @gateway.send(:address_key_prefix, type)
  end

  def key(prefix, key)
    @gateway.send(:address_key, prefix, key)
  end
end
