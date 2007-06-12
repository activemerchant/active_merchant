require File.dirname(__FILE__) + '/../test_helper'

class RemoteTransFirstTest < Test::Unit::TestCase
  AMOUNT = 100

  def setup
    @gateway = TransFirstGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @creditcard = credit_card('4111111111111111')

    @options = { 
      :order_id => generate_order_id,
      :invoice => 'ActiveMerchant Sale',
      :address => { :address1 => '1234 Shady Brook Lane',
                    :zip => '90210'
                  }
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(AMOUNT, @creditcard, @options)
    assert_equal 'test transaction', response.message
    assert response.test?
    assert response.success?
    assert !response.authorization.blank?
  end

  def test_invalid_login
    gateway = TransFirstGateway.new(
      :login => '',
      :password => ''
    )
    assert response = gateway.purchase(AMOUNT, @creditcard, @options)
    assert_equal 'invalid account', response.message
    assert !response.success?
  end
end
