# encoding: utf-8

require 'test_helper'

class RemoteIridiumTest < Test::Unit::TestCase
  def setup
    @gateway = IridiumGateway.new(fixtures(:iridium))

    @amount = 100
    @avs_card = credit_card('4921810000005462', {:verification_value => '441'})
    @cv2_card = credit_card('4976000000003436', {:verification_value => '777'})
    @avs_cv2_card = credit_card('4921810000005462', {:verification_value => '777'})
    @credit_card = credit_card('4976000000003436', {:verification_value => '452'})
    @declined_card = credit_card('4221690000004963')

    our_address = address(:address1 => "32 Edward Street",
                          :address2 => "Camborne",
                          :state => "Cornwall",
                          :zip => "TR14 8PA",
                          :country => "826")
    @options = {
      :order_id => generate_unique_id,
      :billing_address => our_address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization, response.authorization
    assert response.message[/AuthCode/], response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match %r{Card declined}i, response.message
  end

  def test_avs_failure
    assert response = @gateway.purchase(@amount, @avs_card, @options)
    assert_failure response
    assert_equal response.avs_result["street_match"], "N"
    assert_equal response.avs_result["postal_match"], "N"
  end

  def test_cv2_failure
    assert response = @gateway.purchase(@amount, @cv2_card, @options)
    assert_failure response
    assert_equal response.cvv_result["code"], "N"
  end

  def test_avs_cv2_failure
    assert response = @gateway.purchase(@amount, @avs_cv2_card, @options)
    assert_failure response
    assert_equal response.avs_result["street_match"], "N"
    assert_equal response.avs_result["postal_match"], "N"
    assert_equal response.cvv_result["code"], "N"
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert auth.message[/AuthCode/], auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_match %r{Input Variable Errors}i, response.message
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert response.message[/AuthCode/], response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_failed_authorization
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert response.test?
    assert_match %r{Card declined}i, response.message
    assert_equal false,  response.success?
  end

  def test_successful_authorization_and_failed_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert auth.message[/AuthCode/], auth.message

    assert capture = @gateway.capture(@amount + 10, auth.authorization, @options)
    assert_failure capture
    assert capture.message[/Amount exceeds that available for collection/]
  end

  def test_failed_capture_bad_auth_info
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert capture = @gateway.capture(@amount, "a;b;c", @options)
    assert_failure capture
  end

  def test_successful_purchase_by_reference
    assert response = @gateway.authorize(1, @credit_card, @options)
    assert_success response
    assert(reference = response.authorization)

    assert response = @gateway.purchase(@amount, reference, {:order_id => generate_unique_id})
    assert_success response
  end

  def test_failed_purchase_by_reference
    assert response = @gateway.authorize(1, @credit_card, @options)
    assert_success response
    assert(reference = response.authorization)

    assert response = @gateway.purchase(@amount, 'bogusref', {:order_id => generate_unique_id})
    assert_failure response
  end

  def test_successful_authorize_by_reference
    assert response = @gateway.authorize(1, @credit_card, @options)
    assert_success response
    assert(reference = response.authorization)

    assert response = @gateway.authorize(@amount, reference, {:order_id => generate_unique_id})
    assert_success response
  end

  def test_successful_credit
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert response = @gateway.credit(@amount, response.authorization)
    assert_success response
  end

  def test_failed_credit
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert response = @gateway.credit(@amount*2, response.authorization)
    assert_failure response
  end

  def test_successful_void
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert response = @gateway.void(response.authorization)
    assert_success response
  end

  def test_failed_void
    assert response = @gateway.void("bogus")
    assert_failure response
  end

  def test_invalid_login
    gateway = IridiumGateway.new(
                :login => '',
                :password => ''
              )

    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Input Variable Errors}i, response.message
  end

  def test_successful_purchase_with_no_verification_value
    @credit_card.verification_value = nil
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization, response.authorization
    assert response.message[/AuthCode/], response.message
  end

  def test_successful_authorize_with_no_address
    @options.delete(:billing_address)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end
end
