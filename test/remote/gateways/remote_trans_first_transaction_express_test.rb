require "test_helper"

class RemoteTransFirstTransactionExpressTest < Test::Unit::TestCase

  def setup
    @gateway = TransFirstTransactionExpressGateway.new(fixtures(:trans_first_transaction_express))

    @amount = 100
    @declined_amount = 21
    @credit_card = credit_card("4485896261017708")
    @check = check

    billing_address = address({
      address1: "450 Main",
      address2: "Suite 100",
      city: "Broomfield",
      state: "CO",
      zip: "85284",
      phone: "(333) 444-5555",
    })

    @options = {
      order_id: generate_unique_id,
      company_name: "Acme",
      title: "QA Manager",
      billing_address: billing_address,
      shipping_address: billing_address,
      email: "example@example.com",
      description: "Store Purchase"
    }
  end

  def test_invalid_login
    gateway = TransFirstTransactionExpressGateway.new(gateway_id: "", reg_key: "")
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_not_nil response.avs_result
    assert_not_nil response.cvv_result
    assert_equal "Street address does not match, but 5-digit postal code matches.", response.avs_result["message"]
    assert_equal "CVV matches", response.cvv_result["message"]
  end
 
  def test_successful_purchase_no_avs
    options = @options.dup
    options[:shipping_address] = nil
    options[:billing_address] = nil
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_only_required
    # Test the purchase with only the required billing and shipping information
    options = @options.dup
    options[:shipping_address] = {
      address1: "450 Main",
      zip: "85284",
    }

    options[:billing_address] = {
      address1: "450 Main",
      zip: "85284",
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_not_nil response.avs_result
    assert_not_nil response.cvv_result
    assert_equal "Street address does not match, but 5-digit postal code matches.", response.avs_result["message"]
    assert_equal "CVV matches", response.cvv_result["message"]
  end


  def test_successful_purchase_without_cvv
    credit_card_opts = {
      :number => 4485896261017708,
      :month => Date.new((Time.now.year + 1), 9, 30).month,
      :year => Date.new((Time.now.year + 1), 9, 30).year,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :brand => 'visa'
    }

    credit_card = CreditCard.new(credit_card_opts)
    response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_successful_purchase_with_empty_string_cvv
    credit_card_opts = {
      :number => 4485896261017708,
      :month => Date.new((Time.now.year + 1), 9, 30).month,
      :year => Date.new((Time.now.year + 1), 9, 30).year,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :verification_value => '',
      :brand => 'visa'
    }

    credit_card = CreditCard.new(credit_card_opts)
    response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_successful_purchase_with_echeck
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal "Not sufficient funds", response.message
    assert_equal "51", response.params["rspCode"]
  end

  def test_failed_purchase_with_echeck
    assert response = @gateway.purchase(@amount, check(routing_number: "121042883"), @options)
    assert_failure response
    assert_equal 'Error. Bank routing number validation negative (ABA).', response.message
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^authorize\|\d+$), response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal "Not sufficient funds", response.message
    assert_equal "51", response.error_code
  end

  def test_failed_capture
    authorize = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure authorize

    response = @gateway.capture(@amount, authorize.authorization)
    assert_failure response
    assert_equal "Invalid transaction", response.message
    assert_equal "12", response.error_code
  end

  def test_successful_purchase_void
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_successful_authorization_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    void = @gateway.void(authorize.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_successful_capture_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    capture = @gateway.capture(@amount, authorize.authorization)
    assert_success capture

    void = @gateway.void(capture.authorization, void_type: :void_capture)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_failed_void
    response = @gateway.void("purchase|000015212561")
    assert_failure response
    assert_equal "Invalid transaction", response.message
    assert_equal "12", response.error_code
  end

  def test_successful_echeck_purchase_void
    response = @gateway.purchase(@amount, @check, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  # gateway does not settle fast enough to test refunds
  # def test_successful_refund
  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success response

  #   refund = @gateway.refund(@amount, response.authorization)
  #   assert_success refund
  #   assert_equal "Succeeded", refund.message
  # end

  def test_helpful_message_when_refunding_unsettled_purchase
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization)

    assert_failure refund
    assert_equal "Invalid transaction. Declined Post – Credit linked to unextracted settle transaction", refund.message
  end

  def test_failed_refund
    response = @gateway.refund(nil, "")
    assert_failure response
    assert_equal "Validation Failure", response.message
    assert_equal "50011", response.error_code
  end

  def test_successful_refund_with_echeck
    purchase = @gateway.purchase(@amount, @check, @options)
    assert_success purchase
    assert_match /purchase_echeck/, purchase.authorization

    refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund_with_echeck
    refund = @gateway.refund(@amount, 'purchase_echeck|000028706091')
    assert_failure refund
    assert_equal "Invalid transaction", refund.message
  end

  # Credit is only supported with specific approval from Transaction Express
  # def test_successful_credit
  #   response = @gateway.credit(@amount, @credit_card, @options)
  #   assert_success response
  #   assert_equal "Succeeded", response.message
  # end

  def test_failed_credit
    response = @gateway.credit(0, @credit_card, @options)
    assert_failure response
    assert_equal "51334", response.error_code
    assert_equal "Validation Error", response.message
  end

  def test_successful_verify
    visa = credit_card("4485896261017708")
    amex = credit_card("371449635392376", verification_value: 1234)
    mastercard = credit_card("5499740000000057")
    discover = credit_card("6011000991001201")

    [visa, amex, mastercard, discover].each do |credit_card|
      response = @gateway.verify(credit_card, @options)
      assert_success response
      assert_match "Succeeded", response.message
    end
  end

  def test_failed_verify
    response = @gateway.verify(credit_card(""), @options)
    assert_failure response
    assert_equal "Validation Failure", response.message
    assert_equal "51308", response.error_code
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert response.authorization
  end

  def test_successful_authorize_using_stored_card
    assert response = @gateway.store(@credit_card)
    assert_success response

    response = @gateway.authorize(@amount, response.authorization, @options)
    assert_success response
    assert_match "Succeeded", response.message
  end

  def test_failed_authorize_using_stored_card
    assert response = @gateway.store(@credit_card)
    assert_success response

    response = @gateway.authorize(@declined_amount, response.authorization, @options)
    assert_failure response
    assert_match "Not sufficient funds", response.message
  end

  def test_successful_purchase_using_stored_card
    assert response = @gateway.store(@credit_card)
    assert_success response

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
    assert_match "Succeeded", response.message
  end

  def test_failed_purchase_using_stored_card
    assert response = @gateway.store(@credit_card)
    assert_success response

    response = @gateway.purchase(@declined_amount, response.authorization, @options)
    assert_failure response
    assert_match "Not sufficient funds", response.message
  end

  def test_failed_store
    response = @gateway.store(credit_card("123"), @options)
    assert_failure response
    assert_equal "Validation Failure", response.message
    assert_equal "51308", response.error_code
  end

  # def test_dump_transcript
  #   skip("Transcript scrubbing for this gateway has been tested.")
  #   # This test will run a purchase transaction on your gateway
  #   # and dump a transcript of the HTTP conversation so that
  #   # you can use that transcript as a reference while
  #   # implementing your scrubbing logic
  #   dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  # end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:gateway_id], clean_transcript)
    assert_scrubbed(@gateway.options[:reg_key], clean_transcript)
  end
end
