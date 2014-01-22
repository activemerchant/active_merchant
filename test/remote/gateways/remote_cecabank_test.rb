require 'test_helper'

class RemoteCecabankTest < Test::Unit::TestCase


  def setup
    @gateway = CecabankGateway.new(fixtures(:cecabank))

    @amount = 100
    @credit_card = credit_card('5540500001000004', {:month => 12, :year => Time.now.year, :verification_value => 989})
    @declined_card = credit_card('5540500001000004', {:month => 11, :year => Time.now.year + 1, :verification_value => 001})
  
    @counter = Time.now.to_i
  end
  
  def valid_options
     @options = {
       :order_id => @counter + 1,
       :description => 'Active Merchant Test Purchase'
     }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, valid_options)
    assert_success response
    assert_equal 'OK', response.message
  end
  
  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, valid_options)
    assert_failure response
    assert_equal 'ERROR', response.message
  end
  
  
  def test_successful_refund
    options = valid_options
    #make purchase
    purchase = @gateway.purchase(@amount, @credit_card, options)
    #refund previous purchase
    assert response = @gateway.refund(@amount, purchase.params["reference"], options)
    assert_success response
    assert_equal 'OK', response.message
  end
  
  def test_unsuccessful_refund
    #refund previous purchase
    assert response = @gateway.refund(@amount, "wrongreference", valid_options)
    assert_failure response
    assert_equal 'ERROR', response.message
  end


  def test_invalid_login
    gateway = CecabankGateway.new(
                :merchant_id => '',
                :acquirer_bin => '',
                :terminal_id => '',
                :key => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, valid_options)
    assert_failure response
    assert_equal 'ERROR', response.message
  end
end
