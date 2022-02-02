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
end
