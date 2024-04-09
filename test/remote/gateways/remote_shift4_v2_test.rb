require 'test_helper'
require_relative 'remote_securion_pay_test'

class RemoteShift4V2Test < RemoteSecurionPayTest
  def setup
    super
    @gateway = Shift4V2Gateway.new(fixtures(:shift4_v2))

    @options[:ip] = '127.0.0.1'
    @bank_account = check(
      routing_number: '021000021',
      account_number: '4242424242424242',
      account_type: 'savings'
    )
  end

  def test_successful_purchase_third_party_token
    auth = @gateway.store(@credit_card, @options)
    token = auth.params['defaultCardId']
    customer_id = auth.params['id']
    response = @gateway.purchase(@amount, token, @options.merge!(customer_id: customer_id))
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert_equal 'foo@example.com', response.params['metadata']['email']
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_unsuccessful_purchase_third_party_token
    auth = @gateway.store(@credit_card, @options)
    customer_id = auth.params['id']
    response = @gateway.purchase(@amount, @invalid_token, @options.merge!(customer_id: customer_id))
    assert_failure response
    assert_equal "Token 'tok_invalid' does not exist", response.message
  end

  def test_successful_stored_credentials_first_recurring
    stored_credentials = {
      initiator: 'cardholder',
      reason_type: 'recurring'
    }
    @options.merge!(stored_credential: stored_credentials)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert_equal 'first_recurring', response.params['type']
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_successful_stored_credentials_subsequent_recurring
    stored_credentials = {
      initiator: 'merchant',
      reason_type: 'recurring'
    }
    @options.merge!(stored_credential: stored_credentials)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert_equal 'subsequent_recurring', response.params['type']
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_successful_stored_credentials_customer_initiated
    stored_credentials = {
      initiator: 'cardholder',
      reason_type: 'unscheduled'
    }
    @options.merge!(stored_credential: stored_credentials)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert_equal 'customer_initiated', response.params['type']
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_successful_stored_credentials_merchant_initiated
    stored_credentials = {
      initiator: 'merchant',
      reason_type: 'installment'
    }
    @options.merge!(stored_credential: stored_credentials)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert_equal 'merchant_initiated', response.params['type']
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_match CHARGE_ID_REGEX, response.authorization
    assert_equal response.authorization, response.params['error']['chargeId']
    assert_equal response.message, 'The card was declined.'
  end

  def test_successful_store_and_unstore
    store = @gateway.store(@credit_card, @options)
    assert_success store
    assert card_id = store.params['defaultCardId']
    assert customer_id = store.params['cards'][0]['customerId']
    unstore = @gateway.unstore(card_id, customer_id: customer_id)
    assert_success unstore
    assert_equal unstore.params['id'], card_id
  end

  def test_failed_unstore
    store = @gateway.store(@credit_card, @options)
    assert_success store
    assert customer_id = store.params['cards'][0]['customerId']
    unstore = @gateway.unstore(nil, customer_id: customer_id)
    assert_failure unstore
    assert_equal unstore.params['error']['type'], 'invalid_request'
  end

  def test_successful_purchase_with_a_savings_bank_account
    @options[:billing_address] = address(country: 'US')
    response = @gateway.purchase(@amount, @bank_account, @options)

    assert_success response
    assert_equal 'Transaction approved', response.message
  end

  def test_successful_purchase_with_a_checking_bank_account
    @options[:billing_address] = address(country: 'US')
    @bank_account.account_type = 'checking'

    response = @gateway.purchase(@amount, @bank_account, @options)

    assert_success response
    assert_equal 'Transaction approved', response.message
  end

  def test_successful_purchase_with_a_corporate_savings_bank_account
    @options[:billing_address] = address(country: 'US')
    @bank_account.account_type = 'checking'
    @bank_account.account_holder_type = 'business'

    response = @gateway.purchase(@amount, @bank_account, @options)

    assert_success response
    assert_equal 'Transaction approved', response.message
  end

  def test_successful_full_refund_with_a_savings_bank_account
    @options[:billing_address] = address(country: 'US')
    purchase = @gateway.purchase(@amount, @bank_account, @options)
    assert_success purchase
    assert purchase.authorization

    refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund

    assert_equal 2000, refund.params['refunds'].first['amount']
    assert_equal 1, refund.params['refunds'].size
    assert_equal @amount, refund.params['refunds'].map { |r| r['amount'] }.sum

    assert refund.authorization
  end
end
