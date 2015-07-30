require 'test_helper'

class RemoteQuickPayV10Test < Test::Unit::TestCase

  def setup
    @gateway = QuickpayGateway.new(fixtures(:quickpay_v10_api_key))
    @amount = 100
    @options = {
      :order_id => generate_unique_id[0...10],
      :billing_address => address(country: 'DNK')
    }

    @valid_card    = credit_card('1000000000000008')
    @invalid_card  = credit_card('1000000000000016')
    @expeired_card = credit_card('1000000000000024')

    @valid_address   = address(:phone => '4500000001')
    @invalid_address = address(:phone => '4500000002')
  end

  def card_brand response
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
    options = @options.merge({order_id: "#1001.1"})
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
    assert_match /Rejected by acquirer/, response.message
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
    assert_equal 'Validation error: Unknown acquirer name', response.message
  end

  def test_unsuccessful_authorize_with_invalid_card
    assert response = @gateway.authorize(@amount, @invalid_card, @options)
    assert_failure response
    assert_match /Rejected by acquirer/, response.message
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

  def test_failed_capture
    assert response = @gateway.capture(@amount, '*****')
    assert_failure response
    assert_equal 'Validation error', response.message
    assert_equal 'is invalid', response.params['errors']['id'][0]
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

  def test_successful_store
    assert response = @gateway.store(@valid_card, @options.merge(:description => 'test'))
    assert_success response
  end

  def test_successful_unstore
    assert response = @gateway.store(@valid_card, @options.merge(:description => 'test'))
    assert_success response

    assert response = @gateway.unstore(response.authorization)
    assert_success response
  end

  def test_invalid_login
    gateway = QuickpayGateway.new(login: 0, api_key: '**')
    assert response = gateway.purchase(@amount, @valid_card, @options)
    assert_equal 'Invalid API key', response.message
    assert_failure response
  end

end
