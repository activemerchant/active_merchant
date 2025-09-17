require 'test_helper'

class RemoteLoanPaymentProTest < Test::Unit::TestCase
  def setup
    @gateway = LoanPaymentProGateway.new(fixtures(:loan_payment_pro))

    @amount = 500
    @credit_card = credit_card('4000100011112224', month: 9, year: 2025, verification_value: '123')
    @declined_card = credit_card('4000100011112385')
    @bank_account = check(routing_number: '122187238', account_number: '123456', name: 'Ted Tester')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      order_id: SecureRandom.alphanumeric(12)
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved.', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid Test Payment Instrument', response.message
  end

  def test_successful_purchase_ach
    response = @gateway.purchase(@amount, @bank_account, @options)
    assert_success response
    assert_equal 'Transaction processed.', response.message
  end

  def test_successful_void_ach
    auth = @gateway.purchase(@amount, @bank_account, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Transaction Cancelled.', void.message
  end

  def test_successful_refund_ach
    omit "Status is 'Accepted', but only 'Funded' or 'Refunded' transactions may be refunded."

    sale = @gateway.purchase(@amount, @bank_account, @options)
    assert_success sale

    assert refund = @gateway.refund(@amount, sale.authorization)
    assert_success refund
    assert_equal 'Transaction Cancelled.', refund.message
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Authorization Successful', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Authorization Captured Successfully', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid Test Payment Instrument', response.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 'xxxx')
    assert_failure response
    assert_equal 'A transaction with that ID could not be found.', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Transaction voided successfully.', void.message
  end

  def test_failed_void
    response = @gateway.void('xxxx')
    assert_failure response
    assert_equal 'A transaction with that ID could not be found.', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Transaction Approved.', refund.message
  end

  def test_partial_refund
    omit 'Partial refund params are supported but API Returns error'

    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 100, purchase.authorization)
    assert_success refund
    assert_equal 'Transaction Approved.', refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, 'xxxx')
    assert_failure response
    assert_equal 'A transaction with that ID could not be found.', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Payment method validated.', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 'Invalid card number.', response.message
  end

  def test_storing_credit_card
    store = @gateway.store(@credit_card, @options)
    assert_success store
    assert_equal 'Payment method added successfully.', store.message
  end

  def test_unstore
    store = @gateway.store(@credit_card, @options)
    assert_success store

    unstore = @gateway.unstore(store.authorization)
    assert_success unstore
    assert_equal 'Payment method was removed successfully.', unstore.message
  end

  def test_authorize_with_stored_credit_card
    store = @gateway.store(@credit_card, @options)
    assert_success store

    response = @gateway.authorize(@amount, store.authorization, @options)
    assert_success response
    assert_equal 'Authorization Successful', response.message
  end

  def test_purchase_with_stored_credit_card
    store = @gateway.store(@credit_card, @options)
    assert_success store

    @options.delete(:billing_address)
    response = @gateway.purchase(@amount, store.authorization, @options)
    assert_success response
    assert_equal 'Transaction Approved.', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:transaction_key], transcript)
  end
end
