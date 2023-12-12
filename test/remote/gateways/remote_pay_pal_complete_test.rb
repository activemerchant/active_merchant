require 'test_helper'

class RemotePayPalCompleteTest < Test::Unit::TestCase
  def setup
    @gateway = PaypalCompleteGateway.new(fixtures(:paypal_complete).merge(merchant_id: "D4VTH7TAG6EGQ"))

    @amount = 100
    @credit_card = credit_card('5555555555554444')

    @options = {
      currency: 'USD',
      billing_address: address,
      description: 'Store Purchase',
      order_id: generate_unique_id[0...10]
    }
  end

  def test_invalid_login
    gateway = PaypalCompleteGateway.new(client_id: 'InvalidKey', secret: 'InvalidSecret', bn_code: 'Invalid')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'Failed with 401 Unauthorized', response.message
  end

  def test_successful_store_and_purchase_with_payment_method_token
    assert response = @gateway.store(@credit_card, billing_address: address)
    assert_success response
    assert_equal 'Transaction approved', response.message

    vault_id = response.params['id']
    purchase_response = @gateway.purchase(@amount, vault_id, @options)
    assert_success purchase_response
    assert_equal purchase_response.authorization, purchase_response.params['purchase_units'].first['payments']['captures'].first['id']
  end

  def test_successful_refund
    assert response = @gateway.store(@credit_card, billing_address: address)
    assert_success response

    vault_id = response.params['id']
    purchase = @gateway.purchase(@amount, vault_id, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal 'Transaction approved', refund.message
  end

  def test_successful_void
    assert response = @gateway.store(@credit_card, billing_address: address)
    assert_success response

    vault_id = response.params['id']
    purchase = @gateway.purchase(@amount, vault_id, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'Transaction approved', void.message
  end

  def test_successful_store_and_unstore
    assert store_response = @gateway.store(@credit_card, billing_address: address)
    assert_success store_response
    assert_equal 'Transaction approved', store_response.message

    vault_id = store_response.params['id']
    assert unstore_response = @gateway.unstore(vault_id)
    assert_success unstore_response
    assert_equal 'Transaction approved', unstore_response.message
  end

  def test_transcript_scrubbing
    @credit_card.verification_value = 789
    transcript = capture_transcript(@gateway) do
      @gateway.store(@credit_card, billing_address: address)
    end

    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end
end