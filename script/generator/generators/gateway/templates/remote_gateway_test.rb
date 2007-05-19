require File.dirname(__FILE__) + '/../test_helper'

class Remote<%= class_name %>Test < Test::Unit::TestCase
  include ActiveMerchant::Billing

  def setup
    ActiveMerchant::Billing::Base.gateway_mode = :production

    @gateway = <%= class_name %>Gateway.new(
        :login => 'LOGIN',
        :password => 'PASSWORD'
    )

    @creditcard = credit_card('4000100011112224')

    @declined_card = credit_card('4000300011112220')

    @options = { :address => { :address1 => '1234 Shady Brook Lane',
                              :zip => '90210'
                             }
               }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(Money.new(100), @creditcard, @options)
    assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
    assert response.success?
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(Money.new(100), @declined_card, @options)
    assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
    assert !response.success?
  end

  def test_authorize_and_capture
    amount = Money.new(100)
    assert auth = @gateway.authorize(amount, @creditcard, @options)
    assert auth.success?
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert capture.success?
  end

  def test_failed_capture
    assert response = @gateway.capture(Money.new(100), '')
    assert !response.success?
    assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  end

  def test_invalid_login
    gateway = <%= class_name %>Gateway.new({
        :login => '',
        :password => ''
      })
    assert response = gateway.purchase(Money.new(100), @creditcard, @options)
    assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
    assert !response.success?
  end
end
