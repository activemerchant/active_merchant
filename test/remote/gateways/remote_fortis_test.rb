require 'test_helper'

class RemoteFortisTest < Test::Unit::TestCase
  def setup
    @gateway = FortisGateway.new(fixtures(:fortis))
    @amount = 100
    @credit_card = credit_card('5454545454545454', verification_value: '999')
    @incomplete_credit_card = credit_card('54545454545454')
    @billing_address = {
      name:     'John Doe',
      address1: '1 Market St',
      city:     'san francisco',
      state:    'CA',
      zip:      '94105',
      country:  'US',
      phone:    '4158880000'
    }
    @options = {
      order_id: generate_unique_id,
      currency: 'USD',
      email: 'test@cybs.com'
    }
    @complete_options = {
      billing_address: @address,
      description: 'Store Purchase'
    }
  end

  def test_invalid_login
    gateway = FortisGateway.new(
      user_id: 'abc123',
      user_api_key: 'abc123',
      developer_id: 'abc123',
      location_id: @gateway.options[:location_id]
    )

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'Unauthorized', response.message
  end

  def test_successful_authorize
    response = @gateway.authorize(0, @credit_card, @options)
    assert_success response
    assert_equal 'CC - Approved / ACH - Accepted', response.message
    assert_equal 'Y', response.avs_result['postal_match']
    assert_equal 'Y', response.avs_result['street_match']
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'CC - Approved / ACH - Accepted', response.message
  end

  def test_successful_reference_purchase
    purchase1 = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase1

    assert purchase = @gateway.purchase(@amount, purchase1.authorization)
    assert_success purchase
    assert_equal 'CC - Approved / ACH - Accepted', purchase.message
  end

  def test_successful_reference_authorize
    authorize1 = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize1

    assert authorize = @gateway.authorize(@amount, authorize1.authorization)
    assert_success authorize
    assert_equal 'CC - Approved / ACH - Accepted', authorize.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'AuthCompleted', capture.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 'abc123')
    assert_failure response
    assert_match %r{"transaction_id" with value "abc123" fails to match the Fortis}, response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(1000, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(800, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize_declined
    response = @gateway.authorize(622, @credit_card, @options)
    assert_failure response
    assert_equal 'Card Expired', response.message
  end

  def test_failed_authorize_generic_fail
    response = @gateway.authorize(601, @credit_card, @options)
    assert_failure response
    assert_equal 'Generic Decline', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(622, @credit_card, @options)
    assert_failure response
    assert_equal 'Card Expired', response.message
  end

  def test_successful_purchase_with_more_options
    response = @gateway.purchase(@amount, @credit_card, @complete_options)
    assert_success response
    assert_equal 'CC - Approved / ACH - Accepted', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'CC - Approved / ACH - Accepted', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Voided', void.message
  end

  def test_failed_void
    response = @gateway.void('abc123')
    assert_failure response
    assert_match %r{"transaction_id" with value "abc123" fails to match the Fortis}, response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'CC - Approved / ACH - Accepted', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(1000, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(800, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, 'abc123')
    assert_failure response
    assert_match %r{"transaction_id" with value "abc123" fails to match the Fortis}, response.message
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @complete_options)
    assert_success response
    assert_equal 'CC - Approved / ACH - Accepted', response.message
  end

  def test_failed_credit
    response = @gateway.credit(622, @credit_card, @options)
    assert_failure response
    assert_equal 'Card Expired', response.message
  end

  def test_storing_credit_card
    store = @gateway.store(@credit_card, @options)
    assert_success store
  end

  def test_storing_credit_card_with_location_as_option
    @gateway = FortisGateway.new(fixtures(:fortis).except(:location_id))
    @options[:location_id] = fixtures(:fortis)[:location_id]

    store = @gateway.store(@credit_card, @options)
    assert_success store
  end

  def test_failded_store_credit_card
    response = @gateway.store(@incomplete_credit_card, @options)
    assert_failure response
    assert_equal '"account_number" must be a credit card', response.message
  end

  def test_authorize_with_stored_credit_card
    store = @gateway.store(@credit_card, @options)
    assert_success store

    response = @gateway.authorize(@amount, store.authorization, @options)
    assert_success response
    assert_equal 'CC - Approved / ACH - Accepted', response.message
  end

  def test_unstore
    store = @gateway.store(@credit_card, @options)
    assert_success store

    unstore = @gateway.unstore(store.authorization)
    assert_success unstore
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@gateway.options[:user_api_key], transcript)
    assert_scrubbed(@gateway.options[:developer_id], transcript)
  end
end
