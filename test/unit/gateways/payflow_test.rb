require File.dirname(__FILE__) + '/../../test_helper'

class PayflowTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    
    @gateway = PayflowGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
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
  
  def teardown
    Base.gateway_mode = :test
    PayflowGateway.certification_id = nil
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
  
  def test_using_test_mode
    assert @gateway.test?
  end
  
  def test_overriding_test_mode
    Base.gateway_mode = :production
    
    gateway = PayflowGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD',
      :test => true
    )
    
    assert gateway.test?
  end
  
  def test_using_production_mode
    Base.gateway_mode = :production
    
    gateway = PayflowGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )
    
    assert !gateway.test?
  end
  
  def test_certification_id_class_accessor
    assert_nil PayflowGateway.certification_id
    PayflowGateway.certification_id = 'test'
    assert_equal 'test', PayflowGateway.certification_id
    gateway = PayflowGateway.new(:login => 'test', :password => 'test')
    assert_equal 'test', gateway.options[:certification_id]
  end
  
  def test_passed_in_certificate_overrides_class_accessor
    PayflowGateway.certification_id = 'test'
    gateway = PayflowGateway.new(:login => 'test', :password => 'test', :certification_id => 'Clobber')
    assert_equal 'Clobber', gateway.options[:certification_id]
  end
  
  def test_partner_class_accessor
    assert_equal 'PayPal', PayflowGateway.partner
    gateway = PayflowGateway.new(:login => 'test', :password => 'test')
    assert_equal 'PayPal', gateway.options[:partner]
  end
  
  def test_passed_in_partner_overrides_class_accessor
    assert_equal 'PayPal', PayflowGateway.partner
    gateway = PayflowGateway.new(:login => 'test', :password => 'test', :partner => 'PayPalUk')
    assert_equal 'PayPalUk', gateway.options[:partner]
  end
  
  def test_express_instance
    PayflowGateway.certification_id = '123456'
    gateway = PayflowGateway.new(
      :login => 'test',
      :password => 'password'
    )
    express = gateway.express
    assert_instance_of PayflowExpressGateway, express
    assert_equal '123456', express.options[:certification_id]
    assert_equal 'PayPal', express.options[:partner]
    assert_equal 'test', express.options[:login]
    assert_equal 'password', express.options[:password]
  end

  def test_default_currency
    assert_equal 'USD', PayflowGateway.default_currency
  end
  
  def test_supported_countries
    assert_equal ['US', 'CA', 'SG', 'AU'], PayflowGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :jcb, :discover, :diners_club], PayflowGateway.supported_cardtypes
  end
end
