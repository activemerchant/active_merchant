require 'test_helper'

class RemoteSageTest < Test::Unit::TestCase

  def setup
    @gateway = SageGateway.new(fixtures(:sage))

    @amount = 100

    @visa        = credit_card("4111111111111111")
    @check       = check
    @mastercard  = credit_card("5499740000000057")
    @discover    = credit_card("6011000993026909")
    @amex        = credit_card("371449635392376")

    @declined_card = credit_card('4000')

    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :shipping_address => address,
      :email => 'longbob@example.com'
    }
  end

  def test_successful_visa_purchase
    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end

  def test_declined_visa_purchase
    @amount = 200

    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_mastercard_purchase
    assert response = @gateway.purchase(@amount, @mastercard, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end

  def test_successful_discover_purchase
    assert response = @gateway.purchase(@amount, @discover, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end

  def test_successful_amex_purchase
    assert response = @gateway.purchase(@amount, @amex, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end

  def test_successful_check_purchase
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end

  def test_successful_visa_authorization
    assert response = @gateway.authorize(@amount, @visa, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end

  def test_successful_with_minimal_options
    assert response = @gateway.purchase(@amount, @visa, billing_address: address)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end

  def test_successful_purchase_with_blank_state
    assert response = @gateway.purchase(@amount, @visa, billing_address: address(state: ""))
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end

  def test_authorization_and_capture
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'INVALID T_REFERENCE', response.message
  end

  def test_visa_authorization_and_void
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    assert response = @gateway.void('')
    assert_failure response
    assert_equal 'INVALID T_REFERENCE', response.message
  end

  def test_check_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @check, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end

  def test_visa_credit
    assert response = @gateway.credit(@amount, @visa, @options)
    assert_success response
    assert response.test?
  end

  def test_check_credit
    assert response = @gateway.credit(@amount, @check, @options)
    assert_success response
    assert response.test?
  end

  def test_visa_refund
    purchase = @gateway.purchase(@amount, @visa, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal "APPROVED", refund.message
  end

  def test_visa_failed_refund
    purchase = @gateway.purchase(@amount, @visa, @options)
    assert_success purchase

    response = @gateway.refund(@amount, "UnknownReference", @options)
    assert_failure response
    assert_equal "INVALID T_REFERENCE", response.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @visa, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization, @options)
    assert_success refund
    assert_equal "APPROVED", refund.message
  end

  def test_store_visa
    assert response = @gateway.store(@visa, @options)
    assert_success response
    assert auth = response.authorization,
      "Store card authorization should not be nil"
    assert_not_nil response.message
  end

  def test_failed_store
    assert response = @gateway.store(@declined_card, @options)
    assert_failure response
    assert_nil response.authorization
  end

  def test_unstore_visa
    assert auth = @gateway.store(@visa, @options).authorization,
      "Unstore card authorization should not be nil"
    assert response = @gateway.unstore(auth, @options)
    assert_success response
  end

  def test_failed_unstore_visa
    assert auth = @gateway.store(@visa, @options).authorization,
      "Unstore card authorization should not be nil"
    assert response = @gateway.unstore(auth, @options)
    assert_success response
  end

  def test_invalid_login
    gateway = SageGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @visa, @options)
    assert_failure response
    assert_equal 'SECURITY VIOLATION', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @visa, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@visa.number, transcript)
    assert_scrubbed(@visa.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_transcript_scrubbing_store
    transcript = capture_transcript(@gateway) do
      @gateway.store(@visa, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@visa.number, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_echeck_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @check, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.account_number, transcript)
    assert_scrubbed(@check.routing_number, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

end
