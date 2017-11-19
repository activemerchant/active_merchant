require 'test_helper'

class RemotePayeezyTest < Test::Unit::TestCase
  def setup
    @gateway = PayeezyGateway.new(fixtures(:payeezy))
    @credit_card = credit_card
    @bad_credit_card = credit_card('4111111111111113')
    @check = check
    @amount = 100
    @options = {
      :billing_address => address,
      :merchant_ref => 'Store Purchase',
      :ta_token => '123'
    }
    @options_mdd = {
      soft_descriptors: {
        dba_name: "Caddyshack",
        street: "1234 Any Street",
        city: "Durham",
        region: "North Carolina",
        mid: "mid_1234",
        mcc: "mcc_5678",
        postal_code: "27701",
        country_code: "US",
        merchant_contact_info: "8885551212"
      }
    }
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card,
                                     @options.merge(js_security_key: 'js-f4c4b54f08d6c44c8cad3ea80bbf92c4f4c4b54f08d6c44c'))
    assert_success response
    assert_equal 'Token successfully created.', response.message
    assert response.authorization
  end

  def test_successful_store_and_purchase
    assert response = @gateway.store(@credit_card,
                                     @options.merge(js_security_key: 'js-f4c4b54f08d6c44c8cad3ea80bbf92c4f4c4b54f08d6c44c'))
    assert_success response
    assert !response.authorization.blank?
    assert purchase = @gateway.purchase(@amount, response.authorization, @options)
    assert_success purchase
  end

  def test_unsuccessful_store
    assert response = @gateway.store(@bad_credit_card,
                                     @options.merge(js_security_key: 'js-f4c4b54f08d6c44c8cad3ea80bbf92c4f4c4b54f08d6c44c'))
    assert_failure response
    assert_equal 'The credit card number check failed', response.message
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, response.message)
    assert_success response
  end

  def test_successful_purchase_with_echeck
    options = @options.merge({customer_id_type: "1", customer_id_number: "1", client_email: "test@example.com"})
    assert response = @gateway.purchase(@amount, @check, options)
    assert_match(/Transaction Normal/, response.message)
    assert_success response
  end

  def test_successful_purchase_with_soft_descriptors
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(@options_mdd))
    assert_match(/Transaction Normal/, response.message)
    assert_success response
  end

  def test_failed_purchase
    @amount = 501300
    assert response = @gateway.purchase(@amount, @credit_card, @options )
    assert_match(/Transaction not approved/, response.message)
    assert_failure response
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    @amount = 501300
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure auth
    assert auth.authorization
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '1|1')
    assert_failure response
  end

  def test_successful_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, purchase.message)
    assert_success purchase

    assert response = @gateway.refund(50, purchase.authorization)
    assert_success response
    assert_match(/Transaction Normal/, response.message)
    assert response.authorization
  end

  def test_successful_refund_with_echeck
    assert purchase = @gateway.purchase(@amount, @check, @options)
    assert_match(/Transaction Normal/, purchase.message)
    assert_success purchase

    assert response = @gateway.refund(50, purchase.authorization)
    assert_success response
    assert_match(/Transaction Normal/, response.message)
    assert response.authorization
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, purchase.message)
    assert_success purchase

    assert response = @gateway.refund(50, "bad-authorization")
    assert_failure response
    assert_match(/The transaction tag is not provided/, response.message)
    assert response.authorization
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Transaction Normal - Approved', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'The transaction id is not provided', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Transaction Normal - Approved}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@bad_credit_card, @options)
    assert_failure response
    assert_match %r{The credit card number check failed}, response.message
  end

  def test_bad_creditcard_number
    assert response = @gateway.purchase(@amount, @bad_credit_card, @options)
    assert_failure response
    assert_equal response.error_code, "invalid_card_number"
  end

  def test_invalid_login
    gateway = PayeezyGateway.new(apikey: "NotARealUser", apisecret: "NotARealPassword", token: "token")
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_match %r{Invalid Api Key}, response.message
    assert_failure response
  end

  def test_response_contains_cvv_and_avs_results
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'M', response.cvv_result["code"]
    assert_equal '4', response.avs_result["code"]
  end

  def test_trans_error
    # ask for error 42 (unable to send trans) as the cents bit...
    @amount = 500042
    assert response = @gateway.purchase(@amount, @credit_card, @options )
    assert_match(/Server Error/, response.message) # 42 is 'unable to send trans'
    assert_failure response
    assert_equal "500", response.error_code
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:token], transcript)
  end

  def test_transcript_scrubbing_echeck
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @check, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.account_number, transcript)
    assert_scrubbed(@check.routing_number, transcript)
    assert_scrubbed(@gateway.options[:token], transcript)
  end
end
