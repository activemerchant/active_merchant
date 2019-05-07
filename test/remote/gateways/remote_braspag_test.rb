require 'test_helper'

class RemoteBraspagTest < Test::Unit::TestCase
  def setup
    @gateway = BraspagGateway.new(fixtures(:braspag))

    @amount = 100

    @credit_card = credit_card('4539704859539511',
      :first_name => 'John',
      :last_name => 'Doe',
      :verification_value => '737',
      :brand => 'visa'
    )

    @declined_card = credit_card('4000300011112222')

    @options = {
      order_id: generate_unique_id,
      customer: 'John Doe',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Successful', response.message
  end

  def test_successful_purchase_with_more_options
    options = @options.merge(
      email: 'john.doe@example.com',
      currency: 'BRL',
      birthdate: '1973-12-21',
      installments: 2
    )

    response = @gateway.purchase(@amount, @credit_card, options)

    assert_success response
    assert_equal 'Successful', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)

    assert_failure response
    assert_equal 'Denied', response.message
  end

  def test_successful_authorize
    auth = @gateway.authorize(@amount, @credit_card, @options)

    assert_success auth
    assert_equal 'Successful', auth.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)

    assert_failure response
    assert_equal 'Denied', response.message
  end

  def test_successful_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)

    assert_success capture
  end

  def test_failed_capture
   auth = @gateway.authorize(@amount, @declined_card, @options)
   assert_failure auth

   assert capture = @gateway.capture(@amount, auth.authorization)

   assert_failure capture
   assert_equal '308: Transaction not available to capture', capture.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)

    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)

    assert_success refund
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)

    assert_failure refund
    assert_equal '309: Transaction not available to void', refund.message
  end

  def test_successful_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization)

    assert_success void
  end

  def test_failed_void
    purchase = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure purchase

    assert void = @gateway.void(purchase.authorization)

    assert_failure void
    assert_equal '309: Transaction not available to void', void.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)

    assert_success response

    _, token, brand = response.authorization.split('|')
    refute token.nil?
    assert_equal 'Visa', brand
  end

  def test_failed_store
    response = @gateway.store(credit_card('5332312827342798'), @options)

    assert_failure response
    assert_equal 'ProblemsWithCreditCard', response.message
    assert_equal '12', response.error_code
  end

  def test_successful_purchase_with_tokenized_card
    assert store = @gateway.store(@credit_card, @options)
    assert_success store

    assert purchase = @gateway.purchase(@amount, store.authorization, @options)

    assert_success purchase
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)

    assert_success response
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)

    assert_failure response
    assert_equal 'Denied', response.message
  end

  def test_invalid_login
    gateway = BraspagGateway.new(merchant_id: '', merchant_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_equal '114: The provided MerchantId is not in correct format', response.message
  end

  def test_invalid_card_number_for_purchase
    assert response = @gateway.purchase(@amount, credit_card('abc'), @options)
    assert_failure response
    assert_equal '127: You must provide CreditCard Number, PaymentToken, Token or Alias', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:merchant_id], transcript)
    assert_scrubbed(@gateway.options[:merchant_key], transcript)
  end
end
