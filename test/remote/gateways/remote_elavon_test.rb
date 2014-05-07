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
    assert_success response
    assert response = @gateway.void(purchase.authorization)
    assert_failure response
    assert_equal 'The transaction ID is invalid for this transaction type', response.message
  end

  def test_successful_recurring
    @options[:billing_cycle] = 'DAILY'
    @options[:next_payment_date] = Time.now.strftime("%m/%d/%Y")
    assert recurring = @gateway.recurring(@amount, @credit_card, @options)

    assert_equal 'SUCCESS', recurring.message
    assert_success recurring
  end

  def test_unsuccessful_recurring
    @options[:billing_cycle] = 'JUNK_PERIOD'
    @options[:next_payment_date] = Time.now.strftime("%m/%d/%Y")
    assert recurring = @gateway.recurring(@amount, @credit_card, @options)
    assert_failure recurring
    assert_equal 'Billing Cycle specified is not a valid entry.', recurring.message
  end

  def test_successful_cancel_recurring
    @options[:billing_cycle] = 'DAILY'
    @options[:next_payment_date] = Time.now.strftime("%m/%d/%Y")
    assert add_recurring = @gateway.recurring(@amount, @credit_card, @options)
    assert_success add_recurring

    assert cancel_recurring = @gateway.cancel_recurring(add_recurring.params['recurring_id'], @options)

    assert_equal 'SUCCESS', cancel_recurring.message
    assert_success cancel_recurring
  end

  def test_successful_update_recurring_money
    @options[:billing_cycle] = 'MONTHLY'
    @options[:next_payment_date] = Time.now.strftime("%m/%d/%Y")
    assert recurring = @gateway.recurring(@amount, @credit_card, @options)
    assert_success recurring

    @options = {}
    @options[:recurring_id] = recurring.params['recurring_id']
    @amount = 200

    assert update = @gateway.update_recurring(@amount, nil, @options)
    assert_success update
  end

  def test_successful_update_recurring_cycle
    @options[:billing_cycle] = 'MONTHLY'
    @options[:next_payment_date] = Time.now.strftime("%m/%d/%Y")
    assert recurring = @gateway.recurring(@amount, @credit_card, @options)
    assert_success recurring

    @options = {}
    @options[:recurring_id] = recurring.params['recurring_id']
    @options[:billing_cycle] = 'DAILY'

    assert update = @gateway.update_recurring(nil, nil, @options)
    assert_success update
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)

    assert_success response
    assert_equal 'M', response.cvv_result['code']
    assert_equal 'Y', response.avs_result['code']
  end
 
  def test_unsuccessful_verify
    @credit_card.verification_value = '0000'
    assert response = @gateway.verify(@credit_card, @options)

    assert_failure response
    assert_equal '5021', response.errorCode
  end
end
