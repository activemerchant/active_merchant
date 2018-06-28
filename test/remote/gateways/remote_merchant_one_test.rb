require 'test_helper'

class RemoteMerchantOneTest < Test::Unit::TestCase

  def setup
    @gateway = MerchantOneGateway.new(fixtures(:merchant_one))

    @amount = 10000
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('1111111111111111')

    @options = {
      :order_id => '1',
      :description => 'Store Purchase',
      :billing_address => {
        name: 'Jim Smith',
        address1: '1234 My Street',
        address2: 'Apt 1',
        city: 'Tampa',
        state: 'FL',
        zip: '33603',
        country: 'US',
        phone: '(813)421-4331'
      }
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert response.message.include? 'Invalid Credit Card Number'
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert auth.authorization, auth.to_yaml
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
  end

  def test_invalid_login
    gateway = MerchantOneGateway.new(
      :username => 'nnn',
      :password => 'nnn'
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Authentication Failed', response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Customer Added", response.message
    assert_equal "100", response.params["response_code"]
  end

  def test_unsuccessful_store
    assert response = @gateway.store(@declined_card, @options)
    assert_failure response
    assert response.message.include? 'Invalid Credit Card Number'
  end

  def test_successful_purchase_using_stored_card
    assert store = @gateway.store(@credit_card, @options)
    assert_success store

    assert response = @gateway.purchase(@amount, store.authorization, @options)

    assert_success response
    assert_equal "SUCCESS", response.message
    assert response.params["customer_vault_id"]
  end

  def test_successful_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert response = @gateway.void(authorization.authorization)
    assert_success response
    assert_equal "Transaction Void Successful", response.message
  end

  def test_unsuccessful_void
    assert response = @gateway.void("active_merchant_fake_charge")
    assert_failure response
    assert response.message.start_with?("Invalid Transaction ID specified")
  end

  def test_successful_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert response = @gateway.refund(@amount - 20, purchase.authorization)
    assert_success response
    assert_equal "SUCCESS", response.message
  end

  def test_unsuccessful_refund
    assert response = @gateway.refund(@amount, "active_merchant_fake_charge")
    assert_failure response
    assert response.message.start_with?("Invalid Transaction ID specified")
  end

  def test_successful_unstore
    card = @gateway.store(@credit_card, @options)

    assert response = @gateway.unstore(card.authorization)
    assert_success response
    assert_equal "Customer Deleted", response.message
  end
end
