require 'test/unit'
require File.dirname(__FILE__) + '/../../test_helper'

class PayJunctionTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = PayJunctionGateway.new(
      :login      => "pj-ql-01",
      :password   => "pj-ql-01p"
    )

    @creditcard = credit_card('4111111111111111')
  end

  def test_purchase_success    
    @creditcard.number = '1'
    
    assert response = @gateway.purchase(Money.new(100), @creditcard)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal true, response.success?
  end

  def test_purchase_error
    @creditcard.number = '2'

    assert response = @gateway.purchase(Money.new(100), @creditcard)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal false, response.success?

  end

  def test_purchase_exceptions
    @creditcard.number = '3' 

    assert_raise(Error) do
      assert response = @gateway.purchase(Money.new(100), @creditcard)  
    end
  end
   
  def test_amount_style   
   assert_equal '10.34', @gateway.send(:amount, Money.new(1034))
   assert_equal '10.34', @gateway.send(:amount, 1034)
                                                  
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end
  
  def test_detect_test_credentials_when_in_production  
    Base.mode = :production
    
    live_gw  = PayJunctionGateway.new(
                 :login      => "l",
                 :password   => "p"
               )
    assert_false live_gw.test?
    
    test_gw = PayJunctionGateway.new(
                :login      => "pj-ql-01",
                :password   => "pj-ql-01p"
              ) 
    assert test_gw.test?
  end
end
