require 'test_helper'

class RemoteVindiciaTest < Test::Unit::TestCase
  def setup
    @account_id = rand(9000000)

    @gateway = VindiciaGateway.new(fixtures(:vindicia).merge(
      :account_id => @account_id, :avs_success => %{IU}
    ))
    
    @amount = 500
    @credit_card = credit_card('4112344112344113')
    @declined_card = credit_card('4000300011112220')

    @recurring_product_sku = 'CHANGE TO A VALID PRODUCT SKU'
    
    @options = { 
      :order_id => rand(4000000),
      :billing_address => address,
      :shipping_address => address,
      :line_items => { 
        :name => 'Test Product',
        :sku => 'CHANGE TO A VALID PRODUCT SKU',
        :price => 5,
        :quantity => 1
      }
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Ok', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'OK', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'OK', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_equal response.params["qtyFail"].to_i, 1
    assert_failure response
    assert_equal 'Ok', response.message
  end

  def test_successful_void    
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'OK', auth.message
    assert auth.authorization

    assert void = @gateway.void(auth.authorization)
    assert_equal void.params["qtySuccess"].to_i, 1
    assert_success void
    assert_equal 'Ok', void.message
  end

  def test_failed_void
    assert void = @gateway.void('')
    assert_equal void.params["qtyFail"].to_i, 1
    assert_failure void
    assert_equal 'Ok', void.message
  end

  def test_recurrence_setup
    @options.merge!(:product_sku => @recurring_product_sku)

    assert response = @gateway.recurring(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_invalid_login
    gateway = VindiciaGateway.new(
                :login => '',
                :password => '',
                :account_id => 1
              )

    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.message.include?("Permission denied")
  end
end
