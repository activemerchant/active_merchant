require 'test_helper'

class RemoteElavonTest < Test::Unit::TestCase
  def setup
    @gateway = ElavonGateway.new(fixtures(:elavon))

    @credit_card = credit_card('4111111111111111')
    @bad_credit_card = credit_card('invalid')

    @options = {
      :email => "paul@domain.com",
      :description => 'Test Transaction',
      :billing_address => address
    }
    @amount = 100
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'APPROVAL', response.message
    assert response.authorization
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @bad_credit_card, @options)

    assert_failure response
    assert response.test?
    assert_equal 'The Credit Card Number supplied in the authorization request appears to be invalid.', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVAL', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization, :credit_card => @credit_card)
    assert_success capture
  end

  def test_unsuccessful_capture
    assert response = @gateway.capture(@amount, '', :credit_card => @credit_card)
    assert_failure response
    assert_equal 'The FORCE Approval Code supplied in the authorization request appears to be invalid or blank.  The FORCE Approval Code must be 6 or less alphanumeric characters.', response.message
  end

  def test_unsuccessful_authorization
    @credit_card.number = "1234567890123"
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The Credit Card Number supplied in the authorization request appears to be invalid.', response.message
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "APPROVAL", response.message
    assert_success response.responses.last, "The void should succeed"
  end

  def test_failed_verify
    assert response = @gateway.verify(@bad_credit_card, @options)
    assert_failure response
    assert_match %r{appears to be invalid}, response.message
  end

  def test_purchase_and_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization

    assert credit = @gateway.credit(@amount, @credit_card, @options)
    assert_success credit
    assert credit.authorization
  end

  def test_purchase_and_successful_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert refund.authorization
  end

  def test_purchase_and_failed_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount + 5, purchase.authorization)
    assert_failure refund
    assert_match %r{exceed}i, refund.message
  end

  def test_purchase_and_successful_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert response = @gateway.void(purchase.authorization)

    assert_success response
    assert response.authorization
  end

  def test_purchase_and_unsuccessful_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert response = @gateway.void(purchase.authorization)
    assert response = @gateway.void(purchase.authorization)
    assert_failure response
    assert_equal 'The transaction ID is invalid for this transaction type', response.message
  end

  def test_authorize_and_successful_void
    assert authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    assert response = @gateway.void(authorize.authorization)

    assert_success response
    assert response.authorization
  end

  def test_successful_store_without_verify
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_nil response.message
    assert response.test?
  end

  def test_successful_store_with_verify_false
    assert response = @gateway.store(@credit_card, @options.merge(verify: false))
    assert_success response
    assert_nil response.message
    assert response.test?
  end

  def test_successful_store_with_verify_true
    assert response = @gateway.store(@credit_card, @options.merge(verify: true))
    assert_success response
    assert_equal 'APPROVAL', response.message
    assert response.test?
  end

  def test_unsuccessful_store
    assert response = @gateway.store(@bad_credit_card, @options)
    assert_failure response
    assert_equal "The Credit Card Number supplied in the authorization request appears to be invalid.", response.message
    assert response.test?
  end

  def test_successful_update
    store_response = @gateway.store(@credit_card, @options)
    token = store_response.params["token"]
    credit_card = credit_card('4111111111111111', :month => 10)
    assert response = @gateway.update(token, credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_update
    assert response = @gateway.update('ABC123', @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid Token', response.message
    assert response.test?
  end

  def test_successful_purchase_with_token
    store_response = @gateway.store(@credit_card, @options)
    token = store_response.params["token"]
    assert response = @gateway.purchase(@amount, token, @options)
    assert_success response
    assert response.test?
    assert_equal 'APPROVAL', response.message
  end

  def test_successful_purchase_with_token
    assert response = @gateway.purchase(@amount, 'ABC123', @options)
    assert_failure response
    assert response.test?
    assert_equal 'The token supplied in the authorization request appears to be invalid', response.message
  end
end
