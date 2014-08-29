require 'test_helper'

class RemoteAuthorizeNetTest < Test::Unit::TestCase
  def setup
    @gateway = AuthorizeNetGateway.new(fixtures(:authorize_net))
    @gateway.class.duplicate_window = 0

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @check = check
    @declined_card = credit_card('400030001111222')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def teardown
    @gateway.class.duplicate_window = nil
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_minimal_options
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The credit card number is invalid', response.message
  end

  def test_successful_echeck_purchase
    response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_card_present_purchase_with_no_data
    no_data_credit_card = ActiveMerchant::Billing::CreditCard.new
    response = @gateway.purchase(@amount, no_data_credit_card, @options)
    assert_failure response
    assert_match %r{invalid}, response.message
  end

  def test_expired_credit_card
    @credit_card.year = 2004
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'The credit card has expired', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'This transaction has been approved', auth.message

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_with_email_and_ip
    options = @options.merge({email: 'hello@example.com', ip: '127.0.0.1'})
    auth = @gateway.authorize(@amount, @credit_card, options)
    assert_success auth

    assert_equal 'This transaction has been approved', auth.message

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The credit card number is invalid', response.message
  end

  def test_card_present_authorize_and_capture_with_track_data_only
    track_credit_card = ActiveMerchant::Billing::CreditCard.new(:track_data => '%B378282246310005^LONGSON/LONGBOB^1705101130504392?')
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture

    assert_equal 'This transaction has been approved', capture.message
  end

  def test_successful_echeck_authorization
    response = @gateway.authorize(@amount, @check, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_failed_echeck_authorization
    response = @gateway.authorize(@amount, check(routing_number: "121042883"), @options)
    assert_failure response
    assert_equal 'The ABA code is invalid', response.message
    assert response.authorization
  end

  def test_card_present_purchase_with_track_data_only
    track_credit_card = ActiveMerchant::Billing::CreditCard.new(:track_data => '%B378282246310005^LONGSON/LONGBOB^1705101130504392?')
    response = @gateway.purchase(@amount, track_credit_card, @options)
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal 'This transaction has been approved', capture.message
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'This transaction has been approved', void.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "This transaction has been approved", response.message
    assert_success response.responses.last, "The void should succeed"
  end

  def test_failed_verify
    bogus_card = credit_card('4424222222222222')
    response = @gateway.verify(bogus_card, @options)
    assert_failure response
    assert_match %r{The credit card number is invalid}, response.message
  end

  def test_bad_login
    gateway = AuthorizeNetGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    response = gateway.purchase(@amount, @credit_card)
    assert_failure response

    assert_equal %w(
      account_number
      action
      authorization_code
      avs_result_code
      card_code
      cardholder_authentication_code
      response_code
      response_reason_code
      response_reason_text
      transaction_id
    ), response.params.keys.sort

    assert_equal "User authentication failed due to invalid authentication values", response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(20, '23124#1234')
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  def test_failed_refund
    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_purchase_with_solution_id
    ActiveMerchant::Billing::AuthorizeNetGateway.application_id = 'A1000000'
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  ensure
    ActiveMerchant::Billing::AuthorizeNetGateway.application_id = nil
  end

  def test_bad_currency
    response = @gateway.purchase(@amount, @credit_card, currency: "XYZ")
    assert_failure response
    assert_equal 'The supplied currency code is either invalid, not supported, not allowed for this merchant or doesn\'t have an exchange rate', response.message
  end

  def test_usd_currency
    @options[:currency] = "USD"
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
  end
end
