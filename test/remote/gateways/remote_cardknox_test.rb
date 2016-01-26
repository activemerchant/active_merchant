require 'test_helper'

class RemoteCardknoxTest < Test::Unit::TestCase
  def setup
    @gateway = CardknoxGateway.new(fixtures(:cardknox))

    @amount = rand(100..499)
    @declined_amount = 500
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220', verification_value: '518')
    @check = check(number: rand(0..100000))

    @more_options = {
      billing_address: address,
      shipping_address: address,
      order_id: generate_unique_id,
      invoice: generate_unique_id,
      name: 'Jim Smith',
      ip: "127.0.0.1",
      email: "joe@example.com",
      tip: 2,
      tax: 3,
      custom02: 'mycustom',
      custom13: 'spelled right',
      custom25: 'test 25',
      pin: '312lkjasdnotvalid',
      address: {
        address1: '19 Laurel Valley Dr',
        address2: 'Apt 1',
        company: 'Widgets Inc',
        city: 'Brownsburg',
        state: 'IN',
        zip: '46112',
        country: 'US',
        phone: '(555)555-5555',
        fax: '(555)555-6666',
      }
    }

     @options = {}
  end

  def test_successful_credit_card_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_credit_card_purchase_with_more_options
    response = @gateway.purchase(@amount, @credit_card, @more_options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_credit_card_track_data_purchase
    response = @gateway.purchase(@amount, credit_card_with_track_data, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_credit_card_token_purchase
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message

    assert purchase = @gateway.purchase(@amount, response.authorization, @options)
    assert_success purchase
    assert_equal 'Success', purchase.message
  end

  def test_successful_check_purchase_with_options
    response = @gateway.purchase(@amount, @check, @more_options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_check_token_purchase
    response = @gateway.store(@check, @options)
    assert_success response
    assert_equal 'Success', response.message

    assert purchase = @gateway.purchase(@amount, response.authorization)
    assert_success purchase
    assert_equal 'Success', purchase.message
  end

  def test_failed_credit_card_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid CVV', response.message
  end

  def test_successful_credit_card_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Success', auth.message
  end

  def test_successful_cardknox_token_authorize_and_capture
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message

    auth = @gateway.authorize(@amount, response.authorization, @options)
    assert_success auth
    assert_equal 'Success', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Success', auth.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid CVV', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Original transaction not specified', response.message
  end

  def test_credit_card_purchase_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_credit_card_authorize_partial_refund
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert refund = @gateway.refund(@amount-1, auth.authorization)
    assert_failure refund
    assert_equal 'Refund not allowed on non-captured auth.', refund.message

  end

  def test_failed_partial_check_refund # the gate way does not support this transaction
    purchase = @gateway.purchase(@amount, @check, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_failure refund
    assert_equal "Transaction is in a state that cannot be refunded\nParameter name: originalReferenceNumber", refund.message # "Only allowed to refund transactions that have settled.  This is the best we can do for now testing wise."
  end

  def test_credit_card_capture_partial_refund
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    assert refund = @gateway.refund(@amount-1, capture.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'UNSUPPORTED CARD TYPE', response.message
  end

  def test_successful_credit_card_authorize_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization, @options)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_successful_credit_card_capture_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture

    assert void = @gateway.void(capture.authorization, @options)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_successful_credit_card_purchase_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization, @options)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_successful_credit_card_refund_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    assert refund = @gateway.refund(@amount-1, capture.authorization)
    assert_success refund

    assert void = @gateway.void(refund.authorization, @options)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_successful_check_void
    purchase = @gateway.purchase(@amount, @check, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization, @options)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'Original transaction not specified', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Success}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{Invalid CVV}, response.message
  end

  def test_successful_credit_card_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_credit_card_token_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message

    assert store = @gateway.store(response.authorization)
    assert_success store
    assert_equal 'Success', store.message
  end

  def test_successful_check_store
    response = @gateway.store(@check, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_store
    response = @gateway.store('', @options)
    assert_failure response
    assert_equal 'Card or Magstripe Required', response.message
  end

  def test_invalid_login
    gateway = CardknoxGateway.new(api_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Required: xKey}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
      @gateway.purchase(@amount, @check, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@check.routing_number, transcript)
    assert_scrubbed(@check.account_number, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end
end
