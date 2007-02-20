require 'test/unit'
require File.dirname(__FILE__) + '/../../test_helper'

class TrustCommerceTest < Test::Unit::TestCase
  include ActiveMerchant::Billing

  def setup
    #TCLink rescue NameError assert false, 'Trust Commerce test cases require "tclink" library from http://www.trustcommerce.com/tclink.html'

    @gateway = TrustCommerceGateway.new({
      :login => 'TestMerchant',
      :password => 'password'
    })

    @creditcard = CreditCard.new({
      :number => '4111111111111111',
      :month => 8,
      :year => 2006,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    })
    
  end

  def test_purchase_success    
    @creditcard.number = '1'

    assert response = @gateway.purchase(Money.ca_dollar(100), @creditcard, :demo => 'y')
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal true, response.success?
  end

  def test_purchase_error
    @creditcard.number = '2'

    assert response = @gateway.purchase(Money.ca_dollar(100), @creditcard, :demo => 'y')
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal false, response.success?

  end

  def test_purchase_exceptions
    @creditcard.number = '3' 

    assert_raise(Error) do
      assert response = @gateway.purchase(Money.ca_dollar(100), @creditcard, :demo => 'y')  
    end
  end
   
  def test_amount_style   
   assert_equal '1034', @gateway.send(:amount, Money.us_dollar(1034))
   assert_equal '1034', @gateway.send(:amount, 1034)
                                                  
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end

end
