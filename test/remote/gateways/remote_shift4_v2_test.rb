require 'test_helper'
require_relative 'remote_securion_pay_test'

class RemoteShift4V2Test < RemoteSecurionPayTest
  def setup
    super
    @gateway = Shift4V2Gateway.new(fixtures(:shift4_v2))
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
end
