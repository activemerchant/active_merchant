require File.dirname(__FILE__) + '/../../test_helper'

class PlugnpayTest < Test::Unit::TestCase
  include ActiveMerchant::Billing

  def setup
    ActiveMerchant::Billing::Base.mode = :test
    
    @login = 'X'
    @password = 'Y'
    
    @gateway = PlugnpayGateway.new(
      :login => @login,
      :password => @password, 
      :debug => true )
      
    @creditcard = credit_card('4242424242424242')
  end

  def test_purchase_success
    @creditcard.number = 1
    
    assert response = @gateway.purchase(1000, @creditcard)
    assert_equal Response, response.class
    assert_equal true, response.success?
  end

  def test_purchase_error
    @creditcard.number = 2

    assert response = @gateway.purchase(1000, @creditcard)
    assert_equal Response, response.class
    assert_equal false, response.success?
  end
  
  def test_purchase_exceptions
    @creditcard.number = 3 
    
    assert_raise(Error) do
      assert response = @gateway.purchase(1000, @creditcard, :order_id => 1)    
    end
  end
  
  def test_amount_style
   assert_equal '10.34', @gateway.send(:amount, Money.new(1034))
   assert_equal '10.34', @gateway.send(:amount, 1034)
                                                      
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end
  
  def test_add_address_outsite_north_america
    result = PlugnpayGateway::PlugnpayPostData.new
    
    @gateway.send(:add_addresses, result, :billing_address => {:address1 => '164 Waverley Street', :country => 'DE', :state => 'Dortmund'} )
    
    assert_equal result[:state], 'ZZ'
    assert_equal result[:province], 'Dortmund'
    
    assert_equal result[:card_state], 'ZZ'
    assert_equal result[:card_prov], 'Dortmund'
    
    assert_equal result[:card_address1], '164 Waverley Street'
    assert_equal result[:card_country], 'DE'
    
  end
                                                             
  def test_add_address
    result = PlugnpayGateway::PlugnpayPostData.new
    
    @gateway.send(:add_addresses, result, :billing_address => {:address1 => '164 Waverley Street', :country => 'US', :state => 'CO'} )
    
    assert_equal result[:card_state], 'CO'
    assert_equal result[:card_address1], '164 Waverley Street'
    assert_equal result[:card_country], 'US'
    
  end
end
