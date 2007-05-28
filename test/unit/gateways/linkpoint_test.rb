require File.dirname(__FILE__) + '/../../test_helper'

ActiveMerchant::Billing::LinkpointGateway.pem_file = File.read( File.dirname(__FILE__) + '/../../mycert.pem'  ) 

class LinkpointResponseTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    
    @gateway = LinkpointGateway.new(:login => 123123, :result => "GOOD")

    @creditcard = credit_card('4111111111111111')
  end
  
  def teardown
    Base.gateway_mode = :test
  end

  def test_credit_card_formatting
    assert_equal '04', @gateway.send(:format_creditcard_expiry_year, 2004)
    assert_equal '04', @gateway.send(:format_creditcard_expiry_year, '2004')
    assert_equal '04', @gateway.send(:format_creditcard_expiry_year, 4)
    assert_equal '04', @gateway.send(:format_creditcard_expiry_year, '04')
  end
  
  def test_authorize
    @creditcard.number = '1'
    
    assert response = @gateway.authorize(2400, @creditcard, :order_id => 1000, 
      :address1 => '1313 lucky lane',
      :city => 'Lost Angeles',
      :state => 'CA',
      :zip => '90210'
    )
    assert_equal Response, response.class
    assert_equal true, response.success?
  end
  
  def test_purchase_success
    @creditcard.number = '1'
    
    assert response = @gateway.purchase(2400, @creditcard, :order_id => 1001,
      :address1 => '1313 lucky lane',
      :city => 'Lost Angeles',
      :state => 'CA',
      :zip => '90210'
    )
    assert_equal Response, response.class
    assert_equal true, response.success?
  end
  
  def test_purchase_decline
    @creditcard.number = '2'
    
    @gateway = LinkpointGateway.new(:login => 123123, 
      :result => "DECLINE",
      :address1 => '1313 lucky lane',
      :city => 'Lost Angeles',
      :state => 'CA',
      :zip => '90210'
    )

    assert response = @gateway.purchase(100, @creditcard, :order_id => 1002)
    assert_equal Response, response.class
    assert_equal false, response.success?
  end
  
  def test_recurring
    @creditcard.number = '1'
    
    assert response = @gateway.recurring(2400, @creditcard, :order_id => 1003, :installments => 12, :startdate => "immediate", :periodicity => :monthly)
    assert_equal Response, response.class
    assert_equal true, response.success?
  end
  
  def test_amount_style
   assert_equal '10.34', @gateway.send(:amount, 1034)
                                                      
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end
end


class LinkpointRequestTest < Test::Unit::TestCase
  def setup
    @gateway = LinkpointGateway.new(:login => 123123, :result => "GOOD")

    @creditcard = CreditCard.new(
      :number => '4111111111111111',
      :month => Time.now.month.to_s,
      :year => (Time.now + 1.year).year,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    )
  end


  def test_purchase_is_valid_xml
    parameters = @gateway.send(:parameters, 1000, @creditcard, :ordertype => "SALE", :order_id => 1004,
      :billing_address => {
        :address1 => '1313 lucky lane',
        :city => 'Lost Angeles',
        :state => 'CA',
        :zip => '90210'
      }
    )
  
    assert data = @gateway.send(:post_data, parameters)
    assert REXML::Document.new(data)
  end

  
  def test_recurring_is_valid_xml
    parameters = @gateway.send(:parameters, 1000, @creditcard, :ordertype => "SALE", :action => "SUBMIT", :installments => 12, :startdate => "immediate", :periodicity => "monthly", :order_id => 1006,
      :billing_address => {
        :address1 => '1313 lucky lane',
        :city => 'Lost Angeles',
        :state => 'CA',
        :zip => '90210'
      }
    )
    assert data = @gateway.send(:post_data, parameters)
    assert REXML::Document.new(data)
  end

  def test_declined_purchase_is_valid_xml
    @gateway = LinkpointGateway.new(:login => 123123, :result => "DECLINE")
    
    parameters = @gateway.send(:parameters, 1000, @creditcard, :ordertype => "SALE", :order_id => 1005,
      :billing_address => {
        :address1 => '1313 lucky lane',
        :city => 'Lost Angeles',
        :state => 'CA',
        :zip => '90210'
      }
    )
  
    assert data = @gateway.send(:post_data, parameters)
    assert REXML::Document.new(data)
  end
  
  def test_overriding_test_mode
    Base.gateway_mode = :production
    
    gateway = LinkpointGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD',
      :test => true
    )
    
    assert gateway.test?
  end
  
  def test_using_production_mode
    Base.gateway_mode = :production
    
    gateway = LinkpointGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )
    
    assert !gateway.test?
  end
  
  def test_supported_countries
    assert_equal ['US'], LinkpointGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], LinkpointGateway.supported_cardtypes
  end
end
