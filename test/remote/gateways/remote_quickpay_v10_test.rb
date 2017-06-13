require 'test_helper'

class RemoteQuickPayV10Test < Test::Unit::TestCase

  def setup
    @gateway = QuickpayV10Gateway.new(fixtures(:quickpay_v10_api_key))
    @amount = 100
    @options = {
      :order_id => generate_unique_id[0...10],
      :billing_address => address(country: 'DNK')
    }

    @valid_card    = credit_card('1000000000000008')
    @invalid_card  = credit_card('1000000000000016')
    @expired_card = credit_card('1000000000000024')
    @capture_rejected_card = credit_card('1000000000000032')
    @refund_rejected_card = credit_card('1000000000000040')

    @valid_address   = address(:phone => '4500000001')
    @invalid_address = address(:phone => '4500000002')
  end

  def card_brand(response)
    response.params['metadata']['brand']
  end

  def test_successful_purchase_with_short_country
    options = @options.merge({billing_address: address(country: 'DK')})
    assert response = @gateway.purchase(@amount, @valid_card, options)

    assert_equal 'OK', response.message
    assert_equal 'DKK', response.params['currency']
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_purchase_with_order_id_format
    options = @options.merge({order_id: "##{Time.new.to_f}"})
    assert response = @gateway.purchase(@amount, @valid_card, options)

    assert_equal 'OK', response.message
    assert_equal 'DKK', response.params['currency']
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @valid_card, @options)

    assert_equal 'OK', response.message
    assert_equal 'DKK', response.params['currency']
    assert_success response
    assert !response.authorization.blank?
  end

  def test_unsuccessful_purchase_with_invalid_card
    assert response = @gateway.purchase(@amount, @invalid_card, @options)
    assert_failure response
    assert_match(/Rejected test operation/, response.message)
  end

  def test_successful_usd_purchase
    assert response = @gateway.purchase(@amount, @valid_card, @options.update(:currency => 'USD'))
    assert_equal 'OK',  response.message
    assert_equal 'USD', response.params['currency']
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_purchase_with_acquirers
    assert response = @gateway.purchase(@amount, @valid_card, @options.update(:acquirer => "nets"))
    assert_equal 'OK', response.message
    assert_success response
  end

  def test_unsuccessful_purchase_with_invalid_acquirers
    assert response = @gateway.purchase(@amount, @valid_card, @options.update(:acquirer => "invalid"))
    assert_failure response
    assert_equal 'Validation error', response.message
  end

  def test_unsuccessful_authorize_with_invalid_card
    assert response = @gateway.authorize(@amount, @invalid_card, @options)
    assert_failure response
    assert_match /Rejected test operation/, response.message
  end

  def test_successful_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @valid_card, @options)
    assert_success auth
    assert_equal 'OK', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'OK', capture.message
  end

  def test_unsuccessful_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @capture_rejected_card, @options)
    assert_success auth
    assert_equal 'OK', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_failure capture
    assert_equal 'Rejected test operation', capture.message
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '1111')
    assert_failure response
    assert_equal 'Not found: No Payment with id 1111', response.message
  end

  def test_successful_purchase_and_void
    assert auth = @gateway.authorize(@amount, @valid_card, @options)
    assert_success auth
    assert_equal 'OK', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'OK', void.message
  end

  def test_unsuccessful_void
    assert void = @gateway.void('123')
    assert_failure void
    assert_equal 'Not found: No Payment with id 123', void.message
  end

  def test_successful_authorization_capture_and_credit
    assert auth = @gateway.authorize(@amount, @valid_card, @options)
    assert_success auth
    assert !auth.authorization.blank?
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert credit = @gateway.refund(@amount, auth.authorization)
    assert_success credit
    assert_equal 'OK', credit.message
  end

  def test_successful_purchase_and_credit
    assert purchase = @gateway.purchase(@amount, @valid_card, @options)
    assert_success purchase
    assert credit = @gateway.refund(@amount, purchase.authorization)
    assert_success credit
  end

  def test_unsuccessful_authorization_capture_and_credit
    assert auth = @gateway.authorize(@amount, @refund_rejected_card, @options)
    assert_success auth
    assert !auth.authorization.blank?
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert refund = @gateway.refund(@amount, auth.authorization)
    assert_failure refund
    assert_equal 'Rejected test operation', refund.message
  end

  def test_successful_verify
    response = @gateway.verify(@valid_card, @options)
    assert_success response
    assert_match %r{OK}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@invalid_card, @options)
    assert_failure response
    assert_equal "Rejected test operation", response.message
  end

  def test_successful_store
    assert response = @gateway.store(@valid_card, @options)
    assert_success response
  end

  def test_successful_store_and_reference_purchase
    assert store = @gateway.store(@valid_card, @options)
    assert_success store
    assert purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase
  end

  def test_successful_store_and_reference_recurring_purchase
    assert store = @gateway.store(@valid_card, @options)
    assert_success store
    assert signup = @gateway.purchase(@amount, store.authorization, @options)
    assert_success signup
    @options[:order_id] = generate_unique_id[0...10]
    assert renewal = @gateway.purchase(@amount, store.authorization, @options)
    assert_success renewal
  end

  def test_successful_store_and_reference_authorize
    assert store = @gateway.store(@valid_card, @options)
    assert_success store
    assert authorization = @gateway.authorize(@amount, store.authorization, @options)
    assert_success authorization
  end

  def test_successful_store_and_credit
    assert store = @gateway.store(@valid_card, @options)
    assert_success store
    assert purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase
    assert credit = @gateway.refund(@amount, purchase.authorization)
    assert_success credit
  end

  def test_unsuccessful_store_and_credit
    assert store = @gateway.store(@refund_rejected_card, @options)
    assert_success store
    assert purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase
    assert credit = @gateway.refund(@amount, purchase.authorization)
    assert_failure credit
    assert_match(/Rejected test operation/, credit.message)
  end

  def test_successful_store_and_void_authorize
    assert store = @gateway.store(@valid_card, @options)
    assert_success store
    assert authorize = @gateway.authorize(@amount, store.authorization, @options)
    assert_success authorize
    assert void = @gateway.void(authorize.authorization)
    assert_success void
    assert_equal 'OK', void.message
  end

  def test_successful_unstore
    assert response = @gateway.store(@valid_card, @options)
    assert_success response

    assert response = @gateway.unstore(response.authorization)
    assert_success response
  end

  def test_invalid_login
    gateway = QuickpayV10Gateway.new(api_key: '**')
    assert response = gateway.purchase(@amount, @valid_card, @options)
    assert_equal 'Invalid API key', response.message
    assert_failure response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @valid_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@valid_card.number, clean_transcript)
    assert_scrubbed(@valid_card.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:api_key], clean_transcript)
  end

end
