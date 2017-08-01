require 'test_helper'

class RemoteWorldpayTest < Test::Unit::TestCase

  def setup
    @gateway = WorldpayGateway.new(fixtures(:world_pay_gateway))
    @cftgateway = WorldpayGateway.new(fixtures(:world_pay_gateway_cft))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4111111111111111', :first_name => nil, :last_name => 'REFUSED')

    @options = {order_id: generate_unique_id, email: "wow@example.com"}
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_hcg_additional_data
    @options.merge!(hcg_additional_data: {
      key1: "value1",
      key2: "value2",
      key3: "value3"
    })

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal '5', response.error_code
    assert_equal 'REFUSED', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_authorize_and_capture_by_reference
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    assert reference = auth.authorization
    @options[:order_id] = generate_unique_id
    assert auth = @gateway.authorize(@amount, reference, @options)
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_authorize_and_purchase_by_reference
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    assert reference = auth.authorization
    @options[:order_id] = generate_unique_id
    assert auth = @gateway.authorize(@amount, reference, @options)
    @options[:order_id] = generate_unique_id
    assert capture = @gateway.purchase(@amount, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, 'bogus')
    assert_failure response
    assert_equal 'Could not find payment for order', response.message
  end

  def test_billing_address
    assert_success @gateway.authorize(@amount, @credit_card, @options.merge(:billing_address => address))
  end

  def test_partial_address
    billing_address = address
    billing_address.delete(:address1)
    billing_address.delete(:zip)
    billing_address.delete(:country)
    assert_success @gateway.authorize(@amount, @credit_card, @options.merge(:billing_address => billing_address))
  end

  def test_ip_address
    assert_success @gateway.authorize(@amount, @credit_card, @options.merge(ip: "192.18.123.12"))
  end

  def test_void
    assert_success(response = @gateway.authorize(@amount, @credit_card, @options))
    assert_success (void = @gateway.void(response.authorization))
    assert_equal "SUCCESS", void.message
    assert void.params["cancel_received_order_code"]
  end

  def test_void_nonexistent_transaction
    assert_failure response = @gateway.void('non_existent_authorization')
    assert_equal "Could not find payment for order", response.message
  end

  def test_authorize_fractional_currency
    assert_success(result = @gateway.authorize(1234, @credit_card, @options.merge(:currency => 'USD')))
    assert_equal "USD", result.params['amount_currency_code']
    assert_equal "1234", result.params['amount_value']
    assert_equal "2", result.params['amount_exponent']
  end

  def test_authorize_nonfractional_currency
    assert_success(result = @gateway.authorize(1234, @credit_card, @options.merge(:currency => 'IDR')))
    assert_equal "IDR", result.params['amount_currency_code']
    assert_equal "12", result.params['amount_value']
    assert_equal "0", result.params['amount_exponent']
  end

  def test_authorize_three_decimal_currency
    assert_success(result = @gateway.authorize(1234, @credit_card, @options.merge(:currency => 'OMR')))
    assert_equal "OMR", result.params['amount_currency_code']
    assert_equal "1234", result.params['amount_value']
    assert_equal "3", result.params['amount_exponent']
  end

  def test_reference_transaction
    assert_success(original = @gateway.authorize(100, @credit_card, @options))
    assert_success(@gateway.authorize(200, original.authorization, :order_id => generate_unique_id))
  end

  def test_invalid_login
    gateway = WorldpayGateway.new(:login => '', :password => '')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid credentials', response.message
  end

  def test_refund_fails_unless_status_is_captured
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success(response)

    assert refund = @gateway.refund(30, response.authorization)
    assert_failure refund
    assert_equal "A transaction status of 'CAPTURED' or 'SETTLED' or 'SETTLED_BY_MERCHANT' is required.", refund.message
  end

  def test_refund_nonexistent_transaction
    assert_failure response = @gateway.refund(@amount, "non_existent_authorization")
    assert_equal "Could not find payment for order", response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{SUCCESS}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{REFUSED}, response.message
  end

  def test_successful_credit_on_cft_gateway
    credit = @cftgateway.credit(@amount, @credit_card, @options)
    assert_success credit
    assert_equal "SUCCESS", credit.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card,  @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end


  # Worldpay has a delay between asking for a transaction to be captured and actually marking it as captured
  # These 2 tests work if you get authorizations from a purchase, wait some time and then perform the refund/void operation.

  # def get_authorization
  #   assert_success(response = @gateway.purchase(@amount, @credit_card, @options))
  #   assert response.authorization
  #   puts "auth: " + response.authorization
  # end

  # def test_refund
  #   refund = @gateway.refund(@amount, 'replace_with_authorization')
  #   assert_success refund
  #   assert_equal "SUCCESS", refund.message
  # end

  # def test_void_fails_unless_status_is_authorised
  #   response = @gateway.void('replace_with_authorization') # existing transaction in CAPTURED state
  #   assert_failure response
  #   assert_equal "A transaction status of 'AUTHORISED' is required.", response.message
  # end

end
