require 'test_helper'

class RemoteBlueSnapTest < Test::Unit::TestCase
  def setup
    @gateway = BlueSnapGateway.new(fixtures(:blue_snap))

    @amount = 100
    @credit_card = credit_card('4263982640269299')
    @declined_card = credit_card('4917484589897107', month: 1, year: 2018)
    @options = { billing_address: address }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_sans_options
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_more_options
    more_options = @options.merge({
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com",
      description: "Product Description",
      soft_descriptor: "OnCardStatement"
    })

    response = @gateway.purchase(@amount, @credit_card, more_options)
    assert_success response
    assert_equal "Success", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match /Authorization has failed for this transaction/, response.message
    assert_equal "14002", response.error_code
  end

  def test_cvv_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "CVV not processed", response.cvv_result["message"]
    assert_equal "P", response.cvv_result["code"]
  end

  def test_avs_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Address not verified.", response.avs_result["message"]
    assert_equal "I", response.avs_result["code"]
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal "Success", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_match /Authorization has failed for this transaction/, response.message
  end

  def test_partial_capture_succeeds_even_though_amount_is_ignored_by_gateway
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_match /due to missing transaction ID/, response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal "Success", refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_failure refund
    assert_match /failed because the financial transaction was created less than 24 hours ago/, refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_match /cannot be completed due to missing transaction ID/, response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal "Success", void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_match /cannot be completed due to missing transaction ID/, response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "Success", response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match /Authorization has failed for this transaction/, response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @options)

    assert_success response
    assert_equal "Success", response.message
    assert response.authorization
    assert_equal "I", response.avs_result["code"]
    assert_equal "P", response.cvv_result["code"]
    assert_match /services\/2\/vaulted-shoppers/, response.params["content-location-header"]
  end

  def test_failed_store
    assert response = @gateway.store(@declined_card, @options)

    assert_failure response
    assert_match /Transaction failed  because of payment processing failure/, response.message
    assert_equal "14002", response.error_code
  end

  def test_successful_purchase_using_stored_card
    assert store_response = @gateway.store(@credit_card, @options)
    assert_success store_response

    response = @gateway.purchase(@amount, store_response.authorization, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_authorize_using_stored_card
    assert store_response = @gateway.store(@credit_card, @options)
    assert_success store_response

    response = @gateway.authorize(@amount, store_response.authorization, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_invalid_login
    gateway = BlueSnapGateway.new(api_username: 'unknown', api_password: 'unknown')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match "Unable to authenticate.  Please check your credentials.", response.message
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = BlueSnapGateway.new(api_username: 'unknown', api_password: 'unknown')
    assert !gateway.verify_credentials
  end


  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:api_password], transcript)
  end

end
