require 'test_helper'

class RemoteDeepstackTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @gateway = DeepstackGateway.new(fixtures(:deepstack))

    @credit_card = credit_card
    @amount = 100

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      number: '4111111111111111',
      verification_value: '999',
      month: '01',
      year: '2029',
      first_name: 'Bob',
      last_name: 'Bobby'
    )

    @invalid_card = ActiveMerchant::Billing::CreditCard.new(
      number: '5146315000000051',
      verification_value: '999',
      month: '01',
      year: '2029',
      first_name: 'Failure',
      last_name: 'Fail'
    )

    address = {
      address1: '123 Some st',
      address2: '',
      first_name: 'Bob',
      last_name: 'Bobberson',
      city: 'Some City',
      state: 'CA',
      zip: '12345',
      country: 'USA',
      phone: '1231231234',
      email: 'test@test.com'
    }

    shipping_address = {
      address1: '321 Some st',
      address2: '#9',
      first_name: 'Jane',
      last_name: 'Doe',
      city: 'Other City',
      state: 'CA',
      zip: '12345',
      country: 'USA',
      phone: '1231231234',
      email: 'test@test.com'
    }

    @options = {
      order_id: '1',
      billing_address: address,
      shipping_address: shipping_address,
      description: 'Store Purchase'
    }
  end

  def test_successful_token
    response = @gateway.get_token(@credit_card, @options)
    assert_success response

    sale = @gateway.purchase(@amount, response.authorization, @options)
    assert_success sale
    assert_equal 'Approved', sale.message
  end

  def test_failed_token
    response = @gateway.get_token(@invalid_card, @options)
    assert_failure response
    assert_equal 'InvalidRequestException: Card number is invalid.', response.message
  end

  # Feature currently gated. Will be released in future version
  # def test_successful_vault

  #   response = @gateway.gettoken(@credit_card, @options)
  #   assert_success response

  #   vault = @gateway.store(response.authorization, @options)
  #   assert_success vault

  #   sale = @gateway.purchase(@amount, vault.authorization, @options)
  #   assert_success sale

  # end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_true response.params['captured']
  end

  def test_successful_purchase_with_more_options
    additional_options = {
      ip: '127.0.0.1',
      email: 'joe@example.com'
    }

    sent_options = @options.merge(additional_options)

    response = @gateway.purchase(@amount, @credit_card, sent_options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @invalid_card, @options)
    assert_failure response
    assert_not_equal 'Approved', response.message
  end

  def test_successful_authorize
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @invalid_card, @options)
    assert_failure response
    assert_not_equal 'Approved', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Current transaction does not exist or is in an invalid state.', response.message
  end

  # This test will always void because we determine void/refund based on settlement status of the charge request (i.e can't refund a transaction that was just created)
  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Approved', refund.message
  end

  # This test will always void because we determine void/refund based on settlement status of the charge request (i.e can't refund a transaction that was just created)
  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.params['id'])
    assert_success refund
    assert_equal @amount - 1, refund.params['amount']
  end

  # This test always be a void because we determine void/refund based on settlement status of the charge request (i.e can't refund a transaction that was just created)
  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'Specified transaction does not exist.', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(0, auth.params['id'])
    assert_success void
    assert_equal 'Approved', void.message
  end

  def test_failed_void
    response = @gateway.void(0, '')
    assert_failure response
    assert_equal 'Specified transaction does not exist.', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Approved}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@invalid_card, @options)
    assert_failure response
    assert_match %r{Invalid Request: Card number is invalid.}, response.message
  end

  def test_invalid_login
    gateway = DeepstackGateway.new(publishable_api_key: '', app_id: '', shared_secret: '', sandbox: true)

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'Specified transaction does not exist', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    expiration = '%02d%02d' % [@credit_card.month, @credit_card.year % 100]
    assert_scrubbed(expiration, transcript)

    transcript = capture_transcript(@gateway) do
      @gateway.get_token(@credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)
    assert_scrubbed('pk_test_XQS71KYAW9HW7XQOGAJIY4ENHZYZEO0C', transcript)
  end
end
