require 'test_helper'

class RemoteQuickpayV7Test < Test::Unit::TestCase
  # These test assumes that you have not added your development IP in
  # the Quickpay Manager.
  def setup
    @gateway = QuickpayGateway.new(fixtures(:quickpay_with_api_key))

    @amount = 100
    @options = {
      :order_id => generate_unique_id[0...10],
      :billing_address => address
    }

    @visa_no_cvv2   = credit_card('4000300011112220', :verification_value => nil)
    @visa           = credit_card('4000100011112224')
    @dankort        = credit_card('5019717010103742')
    @visa_dankort   = credit_card('4571100000000000')
    @electron_dk    = credit_card('4175001000000000')
    @diners_club    = credit_card('30401000000000')
    @diners_club_dk = credit_card('36148010000000')
    @maestro        = credit_card('5020100000000000')
    @maestro_dk     = credit_card('6769271000000000')
    @mastercard_dk  = credit_card('5413031000000000')
    @amex_dk        = credit_card('3747100000000000')
    @amex           = credit_card('3700100000000000')
    @fbg1886        = credit_card('6007221000000000')
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_equal 'OK', response.message
    assert_equal 'DKK', response.params['currency']
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_purchase_with_all_fraud_parameters
    @options[:ip] = '127.0.0.1' # will set :fraud_remote_addr
    @options[:fraud_http_referer] = 'http://www.excample.com'
    @options[:fraud_http_accept] = 'foo'
    @options[:fraud_http_accept_language] = "DK"
    @options[:fraud_http_accept_encoding] = "UFT8"
    @options[:fraud_http_accept_charset] = "Latin"
    @options[:fraud_http_user_agent] = "Safari"

    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_equal 'OK', response.message
    assert_equal 'DKK', response.params['currency']
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_usd_purchase
    assert response = @gateway.purchase(@amount, @visa, @options.update(:currency => 'USD'))
    assert_equal 'OK', response.message
    assert_equal 'USD', response.params['currency']
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_purchase_with_acquirers
    assert response = @gateway.purchase(@amount, @visa, @options.update(:acquirers => "nets"))
    assert_equal 'OK', response.message
    assert_success response
  end

  def test_unsuccessful_purchase_with_invalid_acquirers
    assert response = @gateway.purchase(@amount, @visa, @options.update(:acquirers => "invalid"))
    assert_equal 'Error in field: acquirers', response.message
    assert_failure response
  end

  def test_successful_dankort_authorization
    assert response = @gateway.authorize(@amount, @dankort, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'dankort', response.params['cardtype']
  end

  def test_successful_visa_dankort_authorization
    assert response = @gateway.authorize(@amount, @visa_dankort, @options)
    assert_success response
    assert !response.authorization.blank?
    # A Visa-Dankort is considered a Dankort when processed by Nets
    assert_equal 'dankort', response.params['cardtype']
  end

  def test_successful_visa_electron_authorization
    assert response = @gateway.authorize(@amount, @electron_dk, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'visa-electron-dk', response.params['cardtype']
  end

  def test_successful_diners_club_authorization
    assert response = @gateway.authorize(@amount, @diners_club, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'diners', response.params['cardtype']
  end

  def test_successful_diners_club_dk_authorization
    assert response = @gateway.authorize(@amount, @diners_club_dk, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'diners-dk', response.params['cardtype']
  end

  def test_successful_maestro_authorization
    assert response = @gateway.authorize(@amount, @maestro, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'maestro', response.params['cardtype']
  end

  def test_successful_maestro_dk_authorization
    assert response = @gateway.authorize(@amount, @maestro_dk, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'maestro-dk', response.params['cardtype']
  end

  def test_successful_mastercard_dk_authorization
    assert response = @gateway.authorize(@amount, @mastercard_dk, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'mastercard-dk', response.params['cardtype']
  end

  def test_successful_american_express_dk_authorization
    assert response = @gateway.authorize(@amount, @amex_dk, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'american-express-dk', response.params['cardtype']
  end

  def test_successful_american_express_authorization
    assert response = @gateway.authorize(@amount, @amex, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'american-express', response.params['cardtype']
  end

  def test_successful_forbrugsforeningen_authorization
    assert response = @gateway.authorize(@amount, @fbg1886, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'fbg1886', response.params['cardtype']
  end

  def test_unsuccessful_purchase_with_missing_cvv2
    assert response = @gateway.purchase(@amount, @visa_no_cvv2, @options)
    # Quickpay has made the cvd field optional in order to support forbrugsforeningen cards which don't have them
    assert_equal 'OK', response.message
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth
    assert_equal 'OK', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'OK', capture.message
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Missing field: transaction', response.message
  end

  def test_successful_purchase_and_void
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth
    assert_equal 'OK', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'OK', void.message
  end

  def test_successful_authorization_capture_and_credit
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert credit = @gateway.refund(@amount, auth.authorization)
    assert_success credit
    assert_equal 'OK', credit.message
  end

  def test_successful_purchase_and_credit
    assert purchase = @gateway.purchase(@amount, @visa, @options)
    assert_success purchase
    assert credit = @gateway.refund(@amount, purchase.authorization)
    assert_success credit
  end

  def test_successful_store_and_reference_purchase
    assert store = @gateway.store(@visa, @options.merge(:description => "New subscription"))
    assert_success store
    assert purchase = @gateway.purchase(@amount, store.authorization, @options.merge(:order_id => generate_unique_id[0...10]))
    assert_success purchase
  end

  def test_successful_store_with_acquirers
    assert store = @gateway.store(@visa, @options.merge(:description => "New subscription", :acquirers => "nets"))
    assert_success store
  end

  def test_invalid_login
    gateway = QuickpayGateway.new(
        :login => '999999999',
        :password => ''
    )
    assert response = gateway.purchase(@amount, @visa, @options)
    assert_equal 'Invalid merchant id', response.message
    assert_failure response
  end
end
