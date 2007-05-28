require File.dirname(__FILE__) + '/../../test_helper'

class PayflowUkTest < Test::Unit::TestCase
  def setup
    @gateway = PayflowUkGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @creditcard = CreditCard.new(
      :number => '4242424242424242',
      :month => 8,
      :year => 2008,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    )

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
  
  def test_default_currency
    assert_equal 'GBP', PayflowUkGateway.default_currency
  end
  
  def test_express_instance
    assert_instance_of PayflowExpressUkGateway, @gateway.express
  end
  
  def test_default_partner
    assert_equal 'PayPalUk', PayflowUkGateway.partner
  end
  
  def test_supported_countries
    assert_equal ['GB'], PayflowUkGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :solo, :switch], PayflowUkGateway.supported_cardtypes
  end
end
