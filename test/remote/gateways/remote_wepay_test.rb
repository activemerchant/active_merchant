require 'test_helper'

class RemoteWepayTest < Test::Unit::TestCase
  def setup
    @gateway = WepayGateway.new(fixtures(:wepay))

    @amount = 2000
    @credit_card = credit_card('5496198584584769')
    @declined_card = credit_card('')

    @options = {
      billing_address: address,
      email: "test@example.com"
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_purchase_with_token
    store = @gateway.store(@credit_card, @options)
    assert_success store

    response = @gateway.purchase(@amount, store.authorization, @options)
    assert_success response
  end

  def test_successful_purchase_sans_cvv
    @options[:recurring] = true
    store = @gateway.store(@credit_card, @options)
    assert_success store

    response = @gateway.purchase(@amount, store.authorization, @options)
    assert_success response
  end

  def test_successful_purchase_with_few_options
    options = { address: { zip: "27701" }, email: "test@example.com" }
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase_sans_ccv
    @credit_card.verification_value = nil
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_failed_purchase_with_token
    response = @gateway.purchase(@amount, "12345", @options)
    assert_failure response
  end

  def test_successful_purchase_with_fee
    response = @gateway.purchase(@amount, @credit_card, @options.merge(application_fee: 3, fee_payer: "payee"))
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end
  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_successful_store_via_transfer_without_cvv
    # special permission required
    # POST /credit_card/transfer
    response = @gateway.store(@credit_card_without_cvv, @options.merge(recurring: true))
    assert_success response
  end

  def test_unsuccessful_store_via_create_with_cvv
    response = @gateway.store(@credit_card_without_cvv, @options)

    assert_failure response
    assert_equal('This app does not have permissions to create credit cards without a cvv', response.message)
  end

  # # Requires commenting out `unless options[:recurring]` when building post hash in `store` method.
  # def test_unsuccessful_store_via_transfer_with_cvv
  #   response = @gateway.store(@credit_card, @options.merge(recurring: true))
  #
  #   assert_failure response
  #   assert_equal('cvv parameter is unexpected', response.message)
  # end

  def test_successful_store_with_defaulted_email
    response = @gateway.store(@credit_card, { billing_address: address })
    assert_success response
  end

  def test_failed_store
    response = @gateway.store(@declined_card, @options)
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    sleep 30 # Wait for purchase to clear. Doesn't always work.
    response = @gateway.refund(@amount - 100, purchase.authorization)
    assert_success response
  end

  def test_successful_full_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    sleep 30 # Wait for purchase to clear. Doesn't always work.
    response = @gateway.refund(@amount, purchase.authorization)
    assert_success response
  end

  def test_failed_capture
    response = @gateway.capture(nil, '123')
    assert_failure response
  end

  def test_failed_void
    response = @gateway.void('123')
    assert_failure response
  end

  def test_authorize_and_capture
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    sleep 30  # Wait for authorization to clear. Doesn't always work.
    assert capture = @gateway.capture(nil, authorize.authorization)
    assert_success capture
  end

  def test_authorize_and_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    void = @gateway.void(authorize.authorization, cancel_reason: "Cancel")
    assert_success void
  end

  def test_invalid_login
    gateway = WepayGateway.new(
      client_id: 12515,
      account_id: 'abc',
      access_token: 'def'
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
