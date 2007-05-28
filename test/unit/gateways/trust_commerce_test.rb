require File.dirname(__FILE__) + '/../../test_helper'

class TrustCommerceTest < Test::Unit::TestCase
  def setup
    #TCLink rescue NameError assert false, 'Trust Commerce test cases require "tclink" library from http://www.trustcommerce.com/tclink.html'

    @gateway = TrustCommerceGateway.new(
      :login => 'TestMerchant',
      :password => 'password'
    )

    @creditcard = credit_card('4111111111111111')
  end

  def test_purchase_success    
    @creditcard.number = '1'

    assert response = @gateway.purchase(100, @creditcard, :demo => 'y')
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal true, response.success?
  end

  def test_purchase_error
    @creditcard.number = '2'

    assert response = @gateway.purchase(100, @creditcard, :demo => 'y')
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal false, response.success?

  end

  def test_purchase_exceptions
    @creditcard.number = '3' 

    assert_raise(Error) do
      assert response = @gateway.purchase(100, @creditcard, :demo => 'y')  
    end
  end
   
  def test_amount_style   
   assert_equal '1034', @gateway.send(:amount, 1034)
                                                  
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end
  
  def test_supported_countries
    assert_equal ['US'], TrustCommerceGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :discover, :american_express, :diners_club, :jcb], TrustCommerceGateway.supported_cardtypes
  end
end
