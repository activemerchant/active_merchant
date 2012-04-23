require 'test_helper'

class RemoteAnzEgateTest < Test::Unit::TestCase
  
  def setup
    @gateway = AnzEgateGateway.new(fixtures(:anz_egate))
    
    @amount = 100
    
    # ANZ eGate returns success/error codes via the cents value
    @invalid_amount = 101
    
    @credit_card = credit_card('5123456789012346', :month => 5, :year => 2013)
    @invalid_credit_card = credit_card('1234567812345678', :month => Time.now.month, :year => Time.now.year)

    @options = {
      :order_id => '1',
      :invoice => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert response.authorization
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@invalid_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_invalid_card
    assert response = @gateway.purchase(@amount, @invalid_credit_card, @options)
    assert_failure response
    assert_match /Invalid Card Number/i, response.message
  end

  def test_invalid_amount
    assert response = @gateway.purchase(0, @credit_card, @options)
    assert_failure response
    assert_equal 'Field vpc_Amount value [0] is invalid.', response.message
  end

  def test_invalid_login
    gateway = AnzEgateGateway.new(
                :merchant_id => 'DOES_NOT_EXIST',
                :access_code => 'DOES_NOT_EXIST'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Merchant [DOES_NOT_EXIST] does not exist', response.message
  end

  def test_successful_credit
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    
    options = { 
      :order_id => '1',
      :invoice => '1',
      :description => 'Refund',
      :username => fixtures(:anz_egate)[:username],
      :password => fixtures(:anz_egate)[:password]
    }

    refund = @gateway.credit(@amount, response.authorization, options)
    assert_success refund
    assert_equal 'Approved', refund.message
  end

  def test_credit_invalid_login
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    
    options = { 
      :order_id => '1',
      :invoice => '1',
      :description => 'Refund',
      :username => 'DOES_NOT_EXIST',
      :password => 'DOES_NOT_EXIST'
    }

    refund = @gateway.credit(@amount, response.authorization, options)
    assert_failure refund
    assert_match %r{E5000: Username and/or password for (.*?) is invalid.}, refund.message
  end
end
