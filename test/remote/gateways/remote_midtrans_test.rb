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
  end

  def test_purchase_when_valid_card_then_success
    response = @gateway.purchase(@amount, @accepted_card, @card_payment_options)
    assert_success response
    assert_equal response.params["status_code"], "200"
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
end
