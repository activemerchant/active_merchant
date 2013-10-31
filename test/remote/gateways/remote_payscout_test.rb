require 'test_helper'

class RemotePayscoutTest < Test::Unit::TestCase
  def setup
    @gateway = PayscoutGateway.new(fixtures(:payscout))

    @amount = 100
    @credit_card = credit_card('4111111111111111', verification_value: 999)
    @declined_card = credit_card('34343')

    @options = {
      :order_id => '1',
      :description => 'Store Purchase',
      :billing_address => address
    }
  end

  ########## Purchase ##########

  def test_cvv_fail_purchase
    @credit_card = credit_card('4111111111111111')
    assert response = @gateway.purchase(@amount, @credit_card, @options)


    assert_success response
    assert_equal 'The transaction has been approved', response.message
    assert_equal 'N', response.cvv_result['code']
  end


  def test_approved_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'The transaction has been approved', response.message
  end

  def test_declined_purchase
    @amount = 60
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The transaction has been declined', response.message
  end

  ########## Authorize ##########

  def test_approved_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'The transaction has been approved', response.message
  end

  def test_declined_authorization
    @amount = 60
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The transaction has been declined', response.message
  end

  ########## Capture ##########

  def test_approved_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'The transaction has been approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_invalid_amount_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'The transaction has been approved', auth.message
    assert auth.authorization
    amount = 200
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_failure capture
    assert_match 'The specified amount of 2.00 exceeds the authorization amount of 1.00', capture.message
  end

  def test_not_found_transaction_id_capture
    assert capture = @gateway.capture(@amount, '1234567890')
    assert_failure capture
    assert_match 'Transaction not found', capture.message
  end

  def test_invalid_transaction_id_capture
    assert capture = @gateway.capture(@amount, '')
    assert_failure capture
    assert_match 'Invalid Transaction ID', capture.message
  end

  ########## Refund ##########

  def test_approved_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal "The transaction has been approved", refund.message
  end

  def test_not_found_transaction_id_refund
    assert refund = @gateway.refund(@amount, '1234567890')
    assert_failure refund
    assert_match "Transaction not found", refund.message
  end

  def test_invalid_transaction_id_refund
    assert refund = @gateway.refund(@amount, '')
    assert_failure refund
    assert_match "Invalid Transaction ID", refund.message
  end

  def test_invalid_amount_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert refund = @gateway.refund(200, purchase.authorization)
    assert_failure refund
    assert_match "Refund amount may not exceed the transaction balance", refund.message
  end

  ########## Void ##########

  def test_approved_void_purchase
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal "The transaction has been approved", void.message
  end

  def test_approved_void_authorization
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal "The transaction has been approved", void.message
  end

  def test_invalid_transaction_id_void
    assert void = @gateway.void('')
    assert_failure void
    assert_match "Invalid Transaction ID", void.message
  end

  def test_not_found_transaction_id_void
    assert void = @gateway.void('1234567890')
    assert_failure void
    assert_match "Transaction not found", void.message
  end

  def test_invalid_credentials
    gateway = PayscoutGateway.new(
      :username => 'xxx',
      :password => 'xxx'
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Authentication Failed', response.message
  end
end
