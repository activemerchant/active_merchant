require 'test_helper'

class RemoteFuseboxTest < Test::Unit::TestCase
  def setup
    @gateway = FuseboxGateway.new(fixtures(:fusebox))

    @amount = 100
    @credit_card = credit_card('4012000000001')
    @declined_card = credit_card('4000000000000000')
  end

  def test_successful_purchase_with_inquiry
    @gateway.class.force_inquiry = true
    assert response = @gateway.purchase(@amount, @credit_card, reference: unique_reference)
    assert_success response
    assert_match(/^0000, COMPLETE/, response.message)
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, reference: unique_reference)
    assert_success response
    assert_match(/^0000, COMPLETE/, response.message)
  end

  def test_successful_refund
    assert response = @gateway.refund(@amount, @credit_card, reference: unique_reference)
    assert_success response
    assert_match(/^0000, COMPLETE/, response.message)
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, reference: unique_reference)
    assert_failure response
    assert_match(/^0041 BAD ACCT NUMBER/, response.message)
  end

  def test_successful_authorize
    assert response = @gateway.authorize(0, @credit_card, reference: unique_reference)
    assert_success response
    assert_match(/^0000, COMPLETE/, response.message)
  end

  def test_unsuccessful_authorize
    assert response = @gateway.authorize(0, @declined_card, reference: unique_reference)
    assert_failure response
    assert_match(/^0041 BAD ACCT NUMBER/, response.message)
  end

  def test_successful_auth_and_reverse
    @reference = unique_reference
    assert response = @gateway.store(@credit_card, reference: @reference, auth_amount: 100)
    assert_success response
    assert_match(/^0000, COMPLETE/, response.message)
    @token = response.params['token']

    assert response = @gateway.auth_reversal(100, @token, reference: @reference)
    assert_success response
    assert_match(/^0000, COMPLETE/, response.message)
  end

  def test_successful_store_and_refund
    # Get a token
    assert response = @gateway.store(@credit_card, reference: unique_reference)
    assert_success response
    @token = response.params['token']
    assert_match(/^ID:[0-9]+/, @token)

    # Charge a payment to the token
    @reference = unique_reference
    assert response = @gateway.purchase(@amount, @token, reference: @reference)
    assert_success response
    assert_match(/^0000, COMPLETE/, response.message)
    assert_match(/^[0-9]+/, response.authorization)

    # Void the prior transaction
    assert response = @gateway.void(@amount, @token, reference: @reference)
    assert_success response
    assert_match(/^0000, COMPLETE/, response.message)
  end

private
  def unique_reference
    @@counter ||= 0
    "#{Time.now.to_i % 10000000}#{@@counter += 1}"
  end

end
