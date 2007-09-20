require File.dirname(__FILE__) + '/../test_helper'

class RemoteCyberSourceTest < Test::Unit::TestCase
  # Amount in cents
  AMOUNT = 100

  def setup
    Base.gateway_mode = :test

    @gateway = CyberSourceGateway.new(fixtures(:cyber_source))

    @creditcard = credit_card('4111111111111111', :type => 'visa')
    @declined_card = credit_card('801111111111111', :type => 'visa')
    
    @options = {
      :address => { 
        :address1 => '1234 My Street',
        :address2 => 'Apt 1',
        :company => 'Widgets Inc',
        :city => 'Ottawa',
        :state => 'ON',
        :zip => 'K1C2N6',
        :country => 'Canada',
        :phone => '(555)555-5555'
      },

      :order_id => generate_order_id,
      :line_items => [
        {
          :declared_value => 100,
          :quantity => 2,
          :code => 'default',
          :description => 'Giant Walrus',
          :sku => 'WA323232323232323'
        },
        {
          :declared_value => 100,
          :quantity => 2,
          :description => 'Marble Snowcone',
          :sku => 'FAKE1232132113123'
        }
      ],  
      :currency => 'USD',
      :email => 'someguy1232@fakeemail.net',
      :ignore_avs => 'true',
      :ignore_cvv => 'true'
    }

  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(AMOUNT, @creditcard, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_unsuccessful_authorization
    assert response = @gateway.authorize(AMOUNT, @declined_card, @options)
    assert response.test?
    assert_equal 'Invalid account number', response.message
    assert_equal false,  response.success?
  end

  def test_successful_tax_calculation
    assert response = @gateway.calculate_tax(@creditcard, @options)
    assert_equal 'Successful transaction', response.message
    assert response.params['totalTaxAmount']
    assert_not_equal "0", response.params['totalTaxAmount']
    assert_success response
    assert response.test?
  end

  def test_successful_tax_calculation_with_nexus
    @gateway.options = @gateway.options.merge(:nexus => 'WI')
    assert response = @gateway.calculate_tax(@creditcard, @options)
    assert_equal 'Successful transaction', response.message
    assert response.params['totalTaxAmount']
    assert_equal "0", response.params['totalTaxAmount']
    assert_success response
    assert response.test?
  end

  def test_successful_purchase
    assert response = @gateway.purchase(AMOUNT, @creditcard, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(AMOUNT, @declined_card, @options)
    assert_equal 'Invalid account number', response.message
    assert_failure response
    assert response.test?
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(AMOUNT, @creditcard, @options)
    assert_success auth
    assert_equal 'Successful transaction', auth.message
  
    assert capture = @gateway.capture(AMOUNT, auth.authorization)
    assert_success capture
  end
  
  def test_good_authorize_and_bad_capture
    assert auth = @gateway.authorize(AMOUNT, @creditcard, @options)
    assert_success auth
    assert_equal 'Successful transaction', auth.message

    assert capture = @gateway.capture(AMOUNT + 10, auth.authorization, @options)
    assert_failure capture
    assert_equal "One or more fields contains invalid data",  capture.message
  end

  def test_failed_capture_bad_auth_info
    assert auth = @gateway.authorize(AMOUNT, @creditcard, @options)
    assert capture = @gateway.capture(AMOUNT, "a;b;c", @options)
    assert_failure capture
  end

  def test_invalid_login
    gateway = CyberSourceGateway.new( :login => '', :password => '' )
    assert response = gateway.purchase(AMOUNT, @creditcard, @options)
    assert_equal "wsse:InvalidSecurity: \nSecurity Data : illegal null input\n", response.message
    assert_failure response
  end
end
