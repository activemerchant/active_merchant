require File.dirname(__FILE__) + '/../test_helper'

class RemoteSecurePayTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  
  AMOUNT = 100
  
  def setup
    @login = 'LOGIN'
    @password = 'PASSWORD'
    
    @gateway = SecurePayGateway.new(
      :login => @login,
      :password => @password
    )

    @creditcard = credit_card('4111111111111111',
      :month => 7,
      :year  => 2007
    )
    
    @options = { :order_id => generate_order_id,
      :description => 'Store purchase',
      :billing_address => {
        :address1 => '1234 My Street',
        :address2 => 'Apartment 204',
        :city => 'Beverly Hills',
        :state => 'CA',
        :country => 'US',
        :zip => '90210'
      }
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(AMOUNT, @creditcard, @options)
    assert response.success?
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end
end
