require 'test_helper'

class RemoteElavonTest < Test::Unit::TestCase
  def setup
    @gateway = ElavonGateway.new(fixtures(:elavon))

    @credit_card = credit_card('4222222222222')
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
    assert_equal 'The refund amount exceeds the original transaction amount.', refund.message
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
end
