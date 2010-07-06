require 'test_helper'

class BraintreeTest < Test::Unit::TestCase

  def test_new_with_login_password_creates_braintree_orange
    gateway = BraintreeGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )
    assert_instance_of BraintreeOrangeGateway, gateway
  end

  def test_new_with_merchant_id_creates_braintree_blue
    gateway = BraintreeGateway.new(
      :merchant_id => 'MERCHANT_ID',
      :public_key => 'PUBLIC_KEY',
      :private_key => 'PRIVATE_KEY'
    )
    assert_instance_of BraintreeBlueGateway, gateway
  end
  
  def test_should_have_display_name_of_just_braintree
    assert_equal "Braintree", BraintreeGateway.display_name
  end

  def test_should_have_homepage_url
    assert_equal "http://www.braintreepaymentsolutions.com", BraintreeGateway.homepage_url
  end
  
  def test_should_have_supported_credit_card_types
    assert_equal [:visa, :master, :american_express, :discover, :jcb], BraintreeGateway.supported_cardtypes
  end
  
  def test_should_have_supported_countries
    assert_equal ['US'], BraintreeGateway.supported_countries
  end
  
  def test_should_have_default_currency
    assert_equal "USD", BraintreeGateway.default_currency
  end  
end
