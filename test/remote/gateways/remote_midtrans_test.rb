require 'test_helper'
require 'securerandom'

class RemoteMidtransTest < Test::Unit::TestCase
  def setup
    @gateway = MidtransGateway.new(fixtures(:midtrans))

    @amount = 200
    @accepted_card = credit_card("4811111111111114")
    @declined_card = credit_card("4911111111111113")
    @card_payment_options = {
      payment_type: 'credit_card',
      order_id: SecureRandom.uuid
    }
    @gopay_payment_options = {
      payment_type: 'gopay',
      order_id: SecureRandom.uuid,
      notification_url: 'dummyurl.com',
      callback_url: 'dummy://callback'
    }
    @qris_gopay_payment_options = {
      payment_type: 'qris',
      order_id: SecureRandom.uuid,
      acquirer: 'gopay',
      notification_url: 'dummyurl.com'
    }
    @shopeepay_payment_options = {
      payment_type: 'shopeepay',
      order_id: SecureRandom.uuid,
      notification_url: 'dummyurl.com',
      callback_url: 'dummy://callback'
    }
    @qris_shopeepay_payment_options = {
      payment_type: 'qris',
      order_id: SecureRandom.uuid,
      acquirer: 'airpay shopee',
      notification_url: 'dummyurl.com'
    }
  end

  def test_purchase_when_valid_card_then_success
    response = @gateway.purchase(@amount, @accepted_card, @card_payment_options)
    assert_success response
    assert_equal response.params["status_code"], "200"
  end

  def test_purchase_when_gopay_valid_request_then_success
    response = @gateway.purchase(@amount, {}, @gopay_payment_options)
    assert_success response
    assert_equal response.params["status_code"], "201"
    assert_equal response.params["transaction_status"], MidtransGateway::TRANSACTION_STATUS_MAPPING[:pending]
    assert_equal response.params["status_message"], "GoPay transaction is created"
    assert_equal response.params["actions"][0]["name"], "generate-qr-code"
    assert_equal response.params["actions"][1]["name"], "deeplink-redirect"
  end

  def test_purchase_with_gopay_when_incorrect_amount_then_failure
    response = @gateway.purchase(39.10, {}, @gopay_payment_options)
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[400]
    assert_equal response.message, "One or more parameters in the payload is invalid."
  end

  def test_purchase_with_gopay_when_missing_order_id_then_validation_error
    response = @gateway.purchase(@amount, {}, {payment_type: 'gopay'})
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[400]
    assert_equal response.message, "One or more parameters in the payload is invalid."
  end

  def test_purchase_with_gopay_when_duplicated_order_id_then_failure
    options = @gopay_payment_options
    response = @gateway.purchase(@amount, {}, options)
    assert_success response

    response = @gateway.purchase(@amount, {}, options)
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[406]
    assert_equal response.message, "The request could not be completed due to a conflict with the current state of the target resource, please try again"
  end

  def test_purchase_when_qris_gopay_valid_request_then_success
    response = @gateway.purchase(@amount, {}, @qris_gopay_payment_options)
    assert_success response
    assert_equal "201", response.params["status_code"]
    assert_equal MidtransGateway::TRANSACTION_STATUS_MAPPING[:pending], response.params["transaction_status"]
    assert_equal "QRIS transaction is created", response.message
    assert_equal "gopay", response.params["acquirer"]
    assert response.params["qr_string"].present?
  end

  def test_purchase_with_qris_gopay_when_incorrect_amount_then_failure
    response = @gateway.purchase(39.10, {}, @qris_gopay_payment_options)
    assert_failure response
    assert_equal MidtransGateway::STATUS_CODE_MAPPING[400], response.error_code
    assert_equal "One or more parameters in the payload is invalid.", response.message
  end

  def test_purchase_with_qris_gopay_when_missing_order_id_then_validation_error
    response = @gateway.purchase(@amount, {}, {payment_type: 'qris'})
    assert_failure response
    assert_equal MidtransGateway::STATUS_CODE_MAPPING[400], response.error_code
    assert_equal "One or more parameters in the payload is invalid.", response.message
  end

  def test_purchase_with_qris_gopay_when_duplicated_order_id_then_failure
    options = @qris_gopay_payment_options
    response = @gateway.purchase(@amount, {}, options)
    assert_success response

    response = @gateway.purchase(@amount, {}, options)
    assert_failure response
    assert_equal MidtransGateway::STATUS_CODE_MAPPING[406], response.error_code
    assert_equal "The request could not be completed due to a conflict with the current state of the target resource, please try again", response.message
  end

  def test_purchase_when_declined_card_then_failure
    response = @gateway.purchase(@amount, @declined_card, @card_payment_options)
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[202]
    assert_equal response.message, "Deny by Bank [CIMB] with code [05] and message [Do not honour]"
  end

  def test_purchase_when_incorrect_amount_then_failure
    response = @gateway.purchase(39.10, @accepted_card, @card_payment_options)
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[400]
    assert_equal response.message, "One or more parameters in the payload is invalid."
  end

  def test_purchase_when_missing_order_id_then_validation_error
    response = @gateway.purchase(@amount, @accepted_card, {payment_type: 'credit_card'})
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[400]
    assert_equal response.message, "One or more parameters in the payload is invalid."
  end

  def test_purchase_when_duplicated_order_id_then_failure
    options = @card_payment_options
    response = @gateway.purchase(@amount, @accepted_card, options)
    assert_success response

    response = @gateway.purchase(@amount, @accepted_card, options)
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[406]
    assert_equal response.message, "The request could not be completed due to a conflict with the current state of the target resource, please try again"
  end

  def test_purchase_when_shopeepay_valid_request_then_success
    response = @gateway.purchase(@amount, {}, @shopeepay_payment_options)
    assert_success response
    assert_equal "201", response.params["status_code"]
    assert_equal MidtransGateway::TRANSACTION_STATUS_MAPPING[:pending], response.params["transaction_status"]
    assert_equal "ShopeePay transaction is created", response.params["status_message"]
    assert_equal "deeplink-redirect", response.params["actions"][0]["name"]
  end

  def test_purchase_with_shopeepay_when_incorrect_amount_then_failure
    response = @gateway.purchase(39.10, {}, @shopeepay_payment_options)
    assert_failure response
    assert_equal MidtransGateway::STATUS_CODE_MAPPING[400], response.error_code
    assert_equal "One or more parameters in the payload is invalid.", response.message
  end

  def test_purchase_with_shopeepay_when_missing_order_id_then_validation_error
    response = @gateway.purchase(@amount, {}, {payment_type: 'shopeepay'})
    assert_failure response
    assert_equal MidtransGateway::STATUS_CODE_MAPPING[400], response.error_code
    assert_equal "One or more parameters in the payload is invalid.", response.message
  end

  def test_purchase_with_shopeepay_when_duplicated_order_id_then_failure
    options = @shopeepay_payment_options
    response = @gateway.purchase(@amount, {}, options)
    assert_success response

    response = @gateway.purchase(@amount, {}, options)
    assert_failure response
    assert_equal MidtransGateway::STATUS_CODE_MAPPING[406], response.error_code
    assert_equal "The request could not be completed due to a conflict with the current state of the target resource, please try again", response.message
  end

  def test_purchase_when_qris_shopeepay_valid_request_then_success
    response = @gateway.purchase(@amount, {}, @qris_shopeepay_payment_options)
    assert_success response
    assert_equal "201", response.params["status_code"]
    assert_equal MidtransGateway::TRANSACTION_STATUS_MAPPING[:pending], response.params["transaction_status"]
    assert_equal "QRIS transaction is created", response.message
    assert_equal "airpay shopee", response.params["acquirer"]
    assert response.params["qr_string"].present?
  end

  def test_purchase_with_qris_shopeepay_when_incorrect_amount_then_failure
    response = @gateway.purchase(39.10, {}, @qris_shopeepay_payment_options)
    assert_failure response
    assert_equal MidtransGateway::STATUS_CODE_MAPPING[400], response.error_code
    assert_equal "One or more parameters in the payload is invalid.", response.message
  end

  def test_purchase_with_qris_shopeepay_when_missing_order_id_then_validation_error
    response = @gateway.purchase(@amount, {}, {payment_type: 'qris'})
    assert_failure response
    assert_equal MidtransGateway::STATUS_CODE_MAPPING[400], response.error_code
    assert_equal "One or more parameters in the payload is invalid.", response.message
  end

  def test_purchase_with_qris_shopeepay_when_duplicated_order_id_then_failure
    options = @qris_shopeepay_payment_options
    response = @gateway.purchase(@amount, {}, options)
    assert_success response

    response = @gateway.purchase(@amount, {}, options)
    assert_failure response
    assert_equal MidtransGateway::STATUS_CODE_MAPPING[406], response.error_code
    assert_equal "The request could not be completed due to a conflict with the current state of the target resource, please try again", response.message
  end

  def test_authorize_when_valid_card_then_success
    response = @gateway.authorize(@amount, @accepted_card, @card_payment_options)
    assert_success response
    assert_equal response.params["transaction_status"], MidtransGateway::TRANSACTION_STATUS_MAPPING[:authorize]
    assert_equal response.message, "Success, Credit Card transaction is successful"
  end

  def test_authorize_when_declined_card_then_failure
    response = @gateway.authorize(@amount, @declined_card, @card_payment_options)
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[202]
    assert_equal response.message, "Deny by Bank [MANDIRI] with code [05] and message [Do not honour]"
  end

  def test_authorize_when_incorrect_amount_then_failure
    response = @gateway.authorize(39.10, @accepted_card, @card_payment_options)
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[400]
    assert_equal response.message, "One or more parameters in the payload is invalid."
  end

  def test_authorize_when_missing_order_id_then_failure
    response = @gateway.authorize(@amount, @accepted_card, {payment_type: 'credit_card'})
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[400]
    assert_equal response.message, "One or more parameters in the payload is invalid."
  end

  def test_authorize_when_duplicated_order_id_then_failure
    options = @card_payment_options
    response = @gateway.authorize(@amount, @accepted_card, options)
    assert_success response

    response = @gateway.authorize(@amount, @accepted_card, options)
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[406]
    assert_equal response.message, "The request could not be completed due to a conflict with the current state of the target resource, please try again"
  end

  def test_capture_when_full_amount_then_success
    auth_response = @gateway.authorize(@amount, @accepted_card, @card_payment_options)
    assert_success auth_response
    assert_equal auth_response.params["transaction_status"], MidtransGateway::TRANSACTION_STATUS_MAPPING[:authorize]

    assert capture_response = @gateway.capture(@amount, auth_response.authorization, {})
    assert_success capture_response
    assert_equal capture_response.params["transaction_status"], MidtransGateway::TRANSACTION_STATUS_MAPPING[:capture]
  end

  def test_capture_when_id_nil_then_failure
    assert_raise(ArgumentError) do
      @gateway.capture(@amount, nil)
    end
  end

  def test_capture_when_invalid_id_then_failure
    assert capture_response = @gateway.capture(@amount, 'invalid_tx')
    assert_failure capture_response
    assert_equal capture_response.error_code, MidtransGateway::STATUS_CODE_MAPPING[404]
  end

  def test_capture_when_partial_amount_then_success
    auth_response = @gateway.authorize(@amount, @accepted_card, @card_payment_options)
    assert_success auth_response
    assert_equal auth_response.params["transaction_status"], MidtransGateway::TRANSACTION_STATUS_MAPPING[:authorize]

    assert capture_response = @gateway.capture(@amount - 1, auth_response.authorization)
    assert_success capture_response
    assert_equal capture_response.params["transaction_status"], MidtransGateway::TRANSACTION_STATUS_MAPPING[:capture]
  end

  def test_capture_malformed_syntax_error
    response = @gateway.capture(@amount, {})
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[413]
  end

  def test_void_when_valid_tx_then_success
    authorize_response = @gateway.authorize(@amount, @accepted_card, @card_payment_options)
    assert_success authorize_response
    assert_equal authorize_response.params["transaction_status"], MidtransGateway::TRANSACTION_STATUS_MAPPING[:authorize]

    assert void_response = @gateway.void(authorize_response.authorization)
    assert_success void_response
    assert_equal void_response.params["transaction_status"], MidtransGateway::TRANSACTION_STATUS_MAPPING[:cancel]
  end

  def test_void_when_invalid_tx_then_failure
    response = @gateway.void('invalid_tx')
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[404]
  end

  def test_void_when_id_nil_then_failure
    assert_raise(ArgumentError) do
      @gateway.void(nil)
    end
  end

  def test_refund_when_valid_tx_then_success
    purchase_response = @gateway.purchase(@amount, @accepted_card, @card_payment_options)
    assert_success purchase_response

    assert refund_response = @gateway.refund(@amount, purchase_response.authorization, {})
    # The created charge ios only in settling state hence added assertion for checking failure message and code
    assert_failure refund_response
    assert_equal refund_response.error_code, "CANNOT_MODIFY_TRANSACTION"
    assert_equal refund_response.message, "Transaction status cannot be updated."
    assert_equal refund_response.params["status_code"], "412"
  end

  def test_refund_when_invalid_tx_then_failure
    response = @gateway.refund(@amount, 'invalid_tx')
    assert_failure response
    assert_equal response.error_code, MidtransGateway::STATUS_CODE_MAPPING[404]
  end

  def test_refund_when_id_nil_then_failure
    assert_raise(ArgumentError) do
      @gateway.refund(@amount, nil)
    end
  end

  def test_store_card_when_valid_card_then_success
    response = @gateway.store(@accepted_card)
    assert_success response
    assert_equal response.params["status_code"], "200"
  end

  def test_store_card_when_invalid_card_then_failure
    card = @accepted_card
    card.number = "4242"
    response = @gateway.store(card)
    assert_failure response
    assert_equal response.params["status_code"], "400"
    assert_equal response.error_code, "VALIDATION_ERROR"
    assert_equal response.message, "CARD_TOKEN_CREATION_FAILED"
  end

  def test_payment_using_token_when_valid_then_success
    response = @gateway.store(@accepted_card)
    assert_success response
    assert_equal response.params["status_code"], "200"

    # Trying a payment using the token
    @token_payment = WalletToken.new(
      token: response.authorization
    )
    card_payment_options = @card_payment_options
    charge_response = @gateway.purchase(@amount, @token_payment, card_payment_options)
    assert_success charge_response
    assert_equal charge_response.params["status_code"], "200"

    # Trying out another payment with the same token just to be sure
    card_payment_options[:order_id] = SecureRandom.uuid 
    charge_response = @gateway.purchase(@amount, @token_payment, card_payment_options)
    assert_success charge_response
    assert_equal charge_response.params["status_code"], "200"
  end

  def test_payment_using_token_when_invalid_token_then_failure
    @token_payment = WalletToken.new(
      token: "dummy-token"
    )
    charge_response = @gateway.purchase(@amount, @token_payment, @card_payment_options)
    assert_failure charge_response
    assert_equal charge_response.error_code, "MISSING_TOKEN_ID"
    assert_equal charge_response.params["status_code"], "411"
    assert_equal charge_response.message, "Credit card token is no longer available. Please create a new one."
  end

  def test_authorize_using_token_when_valid_then_success
    response = @gateway.store(@accepted_card)
    assert_success response
    assert_equal response.params["status_code"], "200"

    # Trying a payment using the token
    @token_payment = WalletToken.new(
      token: response.authorization
    )
    card_payment_options = @card_payment_options
    authorize_response = @gateway.authorize(@amount, @token_payment, card_payment_options)
    assert_success authorize_response
    assert_equal authorize_response.params["status_code"], "200"

    # Trying out another payment with the same token, just to be sure!
    card_payment_options[:order_id] = SecureRandom.uuid 
    authorize_response = @gateway.authorize(@amount, @token_payment, card_payment_options)
    assert_success authorize_response
    assert_equal authorize_response.params["status_code"], "200"
  end

  def test_authorize_using_token_when_invalid_token_then_failure
    @token_payment = WalletToken.new(
      token: "dummy-token"
    )
    authorize_response = @gateway.purchase(@amount, @token_payment, @card_payment_options)
    assert_failure authorize_response
    assert_equal authorize_response.error_code, "MISSING_TOKEN_ID"
    assert_equal authorize_response.params["status_code"], "411"
    assert_equal authorize_response.message, "Credit card token is no longer available. Please create a new one."
  end

  def test_verify_credentials_when_valid_creds_then_success
    response = @gateway.verify_credentials()
    assert_success response
  end

  def test_verify_credentials_when_invalid_creds_then_failure
    # Invalid server key
    invalid_gateway = MidtransGateway.new(
      :client_key => fixtures(:midtrans)[:client_key],
      :server_key => "dummy"
    )
    response = invalid_gateway.verify_credentials()
    assert_failure response

    # Invalid client key
    invalid_gateway = MidtransGateway.new(
      :client_key => "dummy",
      :server_key => fixtures(:midtrans)[:server_key]
    )
    response = invalid_gateway.verify_credentials()
    assert_failure response
  end
end
