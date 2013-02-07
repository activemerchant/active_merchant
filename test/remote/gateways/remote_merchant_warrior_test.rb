require 'test_helper'

class RemoteMerchantWarriorTest < Test::Unit::TestCase
  def setup
    @gateway = MerchantWarriorGateway.new(fixtures(:merchant_warrior).merge(:test => true))

    @success_amount = '100.00'

    # DO NOT USE DECIMALS FOR TOKEN TESTING
    @token_success_amount = '133.00'
    @failure_amount = '102.33'
    @credit_card = credit_card(
      '5123456789012346',
      :month => 5,
      :year => 13,
      :verification_value => '123',
      :brand => 'master'
    )
    @expired_card = credit_card(
      '4564710000000012',
      :month => 2,
      :year => 5,
      :verification_value => '963',
      :brand => 'visa'
    )

    @options = {
      :address => {
        :name => 'Longbob Longsen',
        :country => 'AU',
        :state => 'Queensland',
        :city => 'Brisbane',
        :address1 => '123 test st',
        :zip => '4000'
      },
      :transaction_product => 'TestProduct'
    }
  end

  def test_successful_authorize
    assert auth = @gateway.authorize('150.00', @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction approved', auth.message
    assert_not_nil auth.params["transaction_id"]
    assert_equal auth.params["transaction_id"], auth.authorization

    assert capture = @gateway.capture(@success_amount, auth.authorization)
    assert_success capture
    assert_not_nil capture.params["transaction_id"]
    assert_equal capture.params["transaction_id"], capture.authorization
    assert_not_equal auth.authorization, capture.authorization
  end

  def test_successful_purchase
    assert purchase = @gateway.purchase(@success_amount, @credit_card, @options)
    assert_equal 'Transaction approved', purchase.message
    assert_success purchase
    assert_not_nil purchase.params["transaction_id"]
    assert_equal purchase.params["transaction_id"], purchase.authorization
  end

  def test_failed_purchase
    assert purchase = @gateway.purchase(@failure_amount, @credit_card, @options)
    assert_equal 'Card has expired', purchase.message
    assert_failure purchase
    assert_not_nil purchase.params["transaction_id"]
    assert_equal purchase.params["transaction_id"], purchase.authorization
  end

  def test_successful_refund
    assert purchase = @gateway.purchase(@success_amount, @credit_card, @options)

    assert refund = @gateway.refund(@success_amount, purchase.authorization)
    assert_success refund
    assert_equal 'Transaction approved', refund.message
  end

  def test_failed_refund
    assert refund = @gateway.refund(@success_amount, 'invalid-transaction-id')
    assert_equal 'MW - 011:Invalid transactionID', refund.message
    assert_failure refund
  end

  def test_card_auth_too_much
    assert auth = @gateway.authorize('150.00', @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction approved', auth.message

    assert capture = @gateway.capture(150, auth.authorization)
    assert_equal "MW - 002:Field 'transactionAmount' is invalid", capture.message
    assert_failure capture
  end

  def test_successful_token_purchase
    assert store = @gateway.store(@credit_card)
    assert_equal 'Operation successful', store.message
    assert_success store

    assert purchase = @gateway.purchase(@token_success_amount, store.authorization, @options)
    assert_equal 'Transaction approved', purchase.message
  end

  def test_token_auth
    assert store = @gateway.store(@credit_card)
    assert_success store

    assert auth = @gateway.authorize(@token_success_amount, store.authorization, @options)
    assert_success auth
    assert_equal 'Transaction approved', auth.message
    assert_not_nil auth.authorization

    assert capture = @gateway.capture(@token_success_amount, auth.authorization)
    assert_success capture
  end
end
