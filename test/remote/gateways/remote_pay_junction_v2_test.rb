require 'test_helper'

class RemotePayJunctionV2Test < Test::Unit::TestCase
  def setup
    @gateway = PayJunctionV2Gateway.new(fixtures(:pay_junction_v2))

    @amount = 99
    @credit_card = credit_card('4444333322221111', month: 01, year: 2021, verification_value: 999)
    @options = {
      order_id: generate_unique_id,
      billing_address: address()
    }
  end

  def test_invalid_login
    gateway = PayJunctionV2Gateway.new(api_login: '', api_password: '', api_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{invalid application key}, response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert response.test?

    assert_match @options[:billing_address][:company], response.params['billing']['companyName']
    assert_match @options[:billing_address][:address1], response.params['billing']['address']['address']
    assert_match @options[:billing_address][:city], response.params['billing']['address']['city']
    assert_match @options[:billing_address][:state], response.params['billing']['address']['state']
    assert_match @options[:billing_address][:country], response.params['billing']['address']['country']
    assert_match @options[:billing_address][:zip], response.params['billing']['address']['zip']
  end

  def test_successful_purchase_sans_options
    amount = SecureRandom.random_number(100) + 100
    response = @gateway.purchase(amount, @credit_card)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase
    amount = 5
    response = @gateway.purchase(amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined (do not honor)', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_failed_authorize
    amount = 10
    response = @gateway.authorize(amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined (restricted)', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
    assert_equal sprintf('%.2f', (@amount - 1).to_f / 100), capture.params['amountTotal']
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 'invalid_authorization')
    assert_failure response
    assert_equal '404 Not Found|', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Approved', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount + 50, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Approved', refund.message
    assert_equal sprintf('%.2f', @amount.to_f / 100), refund.params['amountTotal']
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '0000')
    assert_failure response
    assert_match %r{Transaction Id 0 does not exist}, response.message
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_credit
    amount = 0
    response = @gateway.credit(amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Amount Base must be greater than 0.|', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Approved', void.message
  end

  def test_failed_void
    response = @gateway.void('invalid_authorization')
    assert_failure response
    assert_equal '404 Not Found|', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_verify
    credit_card = credit_card('444433332222111')
    response = @gateway.verify(credit_card, @options)
    assert_failure response
    assert_match %r{Card Number is not a valid card number}, response.message
  end

  def test_successful_store_and_purchase
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert response.authorization
    assert_equal 'Approved', response.message

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_store
    credit_card = credit_card('444433332222111')
    response = @gateway.store(credit_card, @options)
    assert_failure response
    assert_match %r{Card Number is not a valid card number}, response.message
  end

  def test_transcript_scrubbing
    assert @gateway.supports_scrubbing?

    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end
end
