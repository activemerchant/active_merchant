require 'test_helper'

class RemoteDwollaTest < Test::Unit::TestCase
  

  def setup
    @gateway = DwollaGateway.new(fixtures(:dwolla))
    
    @amount = 100
    @options = {
      :order_id => '230000',
      :email => 'buyer@jadedpallet.com',
      :billing_address => { :name => 'Fred Brooks',
                    :address1 => '1234 Penny Lane',
                    :city => 'Jonsetown',
                    :state => 'NC',
                    :country => 'US',
                    :zip => '23456'
                  } ,
      :description => 'Stuff that you purchased, yo!',
      :return_url => 'http://example.com/return',
      :cancel_return_url => 'http://example.com/cancel'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  end

  def test_invalid_login
    gateway = DwollaGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  end
end
