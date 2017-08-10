require 'test_helper'

class RemoteDigitzsTest < Test::Unit::TestCase
  def setup
    @gateway = DigitzsGateway.new(fixtures(:digitzs))

    @amount = 500
    @credit_card = credit_card('4747474747474747', verification_value: '999')
    @declined_card = credit_card('4616161616161616')
    @options = {
      merchant_id: 'spreedly-susanswidg-32268973-2091076-148408385',
      billing_address: address,
      description: 'Store Purchase'
    }

    @options_card_split = {
      merchant_id: 'spreedly-susanswidg-32268973-2091076-148408385',
      billing_address: address,
      description: 'Split Purchase',
      payment_type: 'card_split',
      split_amount: 100,
      split_merchant_id: 'spreedly-susanswidg-32270590-2095203-148657924'
    }

    @options_token_split = {
      merchant_id: 'spreedly-susanswidg-32268973-2091076-148408385',
      billing_address: address,
      description: 'Token Split Purchase',
      payment_type: 'token_split',
      split_amount: 100,
      split_merchant_id: 'spreedly-susanswidg-32270590-2095203-148657924'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_token_purchase
    assert store = @gateway.store(@credit_card, @options)
    assert_success store

    response = @gateway.purchase(@amount, store.authorization, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_token_split_purchase
    assert store = @gateway.store(@credit_card, @options)
    assert_success store

    response = @gateway.purchase(@amount, store.authorization, @options_token_split)
    assert_success response
    assert_equal 'Success', response.message
    assert response.params["data"]["attributes"]["split"]["splitId"]
  end

  def test_successful_card_split_purchase
    response = @gateway.purchase(@amount, @credit_card, @options_card_split)
    assert_success response
    assert_equal 'Success', response.message
    assert response.params["data"]["attributes"]["split"]["splitId"]
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Partner error: Credit card declined (transaction element shows reason for decline)', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal 'Success', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization, @options)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '', @options)
    assert_failure response
    assert_equal '"id" is not allowed to be empty', response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_successful_store_without_billing_address
    assert response = @gateway.store(@credit_card, {merchant_id: 'spreedly-susanswidg-32268973-2091076-148408385'})
    assert_success response
  end

  def test_store_adds_card_to_existing_customer
    assert response = @gateway.store(@credit_card, @options.merge({customer_id: "spreedly-susanswidg-32268973-2091076-148408385-5980208887457495-148700575"}))
    assert_success response
  end

  def test_store_creates_new_customer_and_adds_card
    assert response = @gateway.store(@credit_card, @options.merge({customer_id: "nonexistant"}))
    assert_success response
  end

  def test_invalid_login
    gateway = DigitzsGateway.new(app_key: '', api_key: '', merchant_id: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Forbidden}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
    assert_scrubbed(@gateway.options[:app_key], transcript)
  end

end
