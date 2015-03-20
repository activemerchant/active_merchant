require 'test_helper'

class RemoteSecurionPayTest < Test::Unit::TestCase
  CHARGE_ID_REGEX = /char_[a-zA-Z\d]+/
  TOKEN_ID_REGEX  = /tok_[a-zA-Z\d]+/

  def setup
    @gateway = SecurionPayGateway.new(fixtures(:securion_pay))

    @amount = 2000
    @refund_amount = 300
    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4916018475814056')
    @new_credit_card = credit_card('4012888888881881')
    @invalid_token = 'tok_invalid'

    @options = {
      description: 'ActiveMerchant test charge',
      email: 'foo@example.com'
    }
  end

  def test_dump_transcript
    skip("Transcript scrubbing for this gateway has been tested.")
    dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:secret_key], transcript)
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["objectType"]
    assert_equal "ActiveMerchant test charge", response.params["description"]
    assert_equal "foo@example.com", response.params["metadata"]["email"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match %r{The card was declined for other reason.}, response.message
    assert_match Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_purchase_with_token
    # Create token
    assert response = @gateway.create_token(@credit_card)
    assert_success response
    token = response.authorization
    assert_match TOKEN_ID_REGEX, token

    # Charge
    assert response = @gateway.purchase(@amount, token, @options)
    assert_success response
    assert_equal "charge", response.params["objectType"]
    assert_equal "ActiveMerchant test charge", response.params["description"]
    assert_equal "foo@example.com", response.params["metadata"]["email"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_unsuccessful_purchase_with_token
    assert response = @gateway.purchase(@amount, @invalid_token, @options)
    assert_failure response
    assert_match %r{Wrong token or already used}, response.message
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert !authorization.params["captured"]
    assert_equal @options[:description], authorization.params["description"]
    assert_equal @options[:email], authorization.params["metadata"]["email"]

    assert response = @gateway.capture(@amount, authorization.authorization)
    assert_success response
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_partial_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_failure capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, 'invalid_authorization_token')
    assert_failure response
    assert_match %r{Requested Charge does not exist}, response.message
  end

  def test_successful_full_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund

    assert refund.params["refunded"]
    assert_equal 0, refund.params["amount"]
    assert_equal 1, refund.params["refunds"].size
    assert_equal @amount, refund.params["refunds"].map{|r| r["amount"]}.sum

    assert refund.authorization
  end

  def test_successful_partially_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization

    assert first_refund = @gateway.refund(@refund_amount, purchase.authorization)
    assert_success first_refund

    assert second_refund = @gateway.refund(@refund_amount, purchase.authorization)
    assert_success second_refund
    assert second_refund.params["refunded"]
    assert_equal @amount - 2 * @refund_amount, second_refund.params["amount"]
    assert_equal 2, second_refund.params["refunds"].size
    assert_equal 2 * @refund_amount, second_refund.params["refunds"].map{|r| r["amount"]}.sum
    assert second_refund.authorization
  end

  def test_unsuccessful_authorize_refund
    assert response = @gateway.refund(@amount, 'invalid_authorization_token')
    assert_failure response
    assert_match %r{Requested Charge does not exist}, response.message
  end

  def test_unsuccessful_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization

    assert refund = @gateway.refund(@amount + 1, purchase.authorization, @options)
    assert_failure refund
    assert_match %r{Wrong Refund data}, refund.message
  end

  def test_successful_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization

    assert void = @gateway.void(purchase.authorization, @options)
    assert_success void
    assert void.params["refunded"]
    assert_equal 0, void.params["amount"]
    assert_equal 1, void.params["refunds"].size
    assert_equal @amount, void.params["refunds"].map{|r| r["amount"]}.sum
    assert void.authorization
  end

  def test_failed_void
    assert response = @gateway.void('invalid_authorization_token', @options)
    assert_failure response
    assert_match %r{Requested Charge does not exist}, response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Transaction approved}, response.responses.last.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{The card was declined for other reason.}, response.message
    assert_match Gateway::STANDARD_ERROR_CODE[:card_declined], response.primary_response.error_code
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, { description: "Customer Test", email: "email@example.com" })
    assert_success response
    assert_equal 3, response.responses.size
    store_response = response.responses.last
    assert_equal "customer", store_response.params["objectType"]
    assert_equal "Customer Test", store_response.params["description"]
    assert_equal "email@example.com", store_response.params["email"]
    first_card = store_response.params["cards"].first
    assert_equal store_response.params["defaultCardId"], first_card["id"]
    assert_equal @credit_card.last_digits, first_card["last4"]
  end

  def test_successful_store_with_existing_customer
    assert response = @gateway.store(@credit_card, { description: "Customer Test", email: "email@example.com" })
    assert_success response
    assert_equal 3, response.responses.size
    store_response = response.responses.last

    assert response = @gateway.store(@new_credit_card, { customer: store_response.params['id'], description: "Test Customer Update" })
    assert_success response

    assert_equal 2, response.params['cards'].size
    first_card, second_card = response.params['cards']
    assert_equal "card", first_card["objectType"]
    assert_equal "card", second_card["objectType"]
    assert_equal @new_credit_card.last_digits, second_card["last4"]

    assert_equal "customer", response.params["objectType"]
    assert_equal "Test Customer Update", response.params["description"]
    assert_equal "email@example.com", response.params["email"]
    assert_equal response.params["defaultCardId"], second_card['id']
  end

  def test_successful_unstore_card
    response = @gateway.store(@credit_card, { description: "Active Merchant Unstore Customer", email: "email@example.pl" })
    assert_success response
    customer = response.responses.last
    customer_id = customer.params['id']
    card_id = customer.params['cards'].first['id']

    # Unstore the card
    assert response = @gateway.unstore(customer_id, { card_id: card_id })
    assert_success response
    assert_equal card_id, response.params['id']

    # Unstore the customer
    assert response = @gateway.unstore(customer_id)
    assert_success response
    assert_equal customer_id, response.params['id']
  end

  def test_successful_update
    response = @gateway.store(@credit_card, { description: "Active Merchant Credit Card", email: "email@example.pl" })
    customer = response.responses.last
    customer_id = customer.params['id']
    card_id     = customer.params['cards'].first['id']

    assert response = @gateway.update(customer_id, card_id, {
      cardholderName: "John Doe",
      addressLine1: "123 Main Street",
      addressCity: "Pleasantville",
      addressState: "NY",
      addressZip: "12345",
      expYear: Time.now.year + 2,
      expMonth: 6
    })
    assert_success response
    assert_equal "John Doe",               response.params["cardholderName"]
    assert_equal "123 Main Street",        response.params["addressLine1"]
    assert_equal "Pleasantville",          response.params["addressCity"]
    assert_equal "NY",                     response.params["addressState"]
    assert_equal "12345",                  response.params["addressZip"]
    assert_equal (Time.now.year + 2).to_s, response.params["expYear"]
    assert_equal "6",                        response.params["expMonth"]
  end

  def test_incorrect_number_for_purchase
    card = credit_card('4242424242424241')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_invalid_login
    gateway = SecurionPayGateway.new(secret_key: 'active_merchant_test')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match "Provided API key is invalid", response.message
  end

  def test_invalid_number_for_purchase
    card = credit_card('-1')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_invalid_expiry_month_for_purchase
    card = credit_card('4242424242424242', month: 16)
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_expiry_date], response.error_code
  end

  def test_invalid_expiry_year_for_purchase
    card = credit_card('4242424242424242', year: 'xx')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_expiry_date], response.error_code
  end

  def test_expired_card_for_purchase
    card = credit_card('4916487051294548')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:expired_card], response.error_code
  end

  def test_invalid_cvc_for_purchase
    card = credit_card('4242424242424242', verification_value: -1)
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_cvc], response.error_code
  end

  def test_incorrect_cvc_for_purchase
    card = credit_card('4024007134364842')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:incorrect_cvc], response.error_code
  end

  def test_processing_error
    card = credit_card('4024007114166316')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_incorrect_zip
    card = credit_card('4929225021529113')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:incorrect_zip], response.error_code
  end

  def test_card_declined
    card = credit_card('4916018475814056')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end
end
