require 'test_helper'

class SwipeCheckoutTest < Test::Unit::TestCase
  def setup
    @gateway = SwipeCheckoutGateway.new(
                 :login => '0000000000000',
                 :api_key => '0000000000000000000000000000000000000000000000000000000000000000',
                 :region => 'NZ'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_supported_countries
    assert @gateway.supported_countries == ['NZ', 'CA']
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).twice.returns(successful_currency_codes_for_nz)
      .then.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert response.test?
  end

  def test_successful_test_purchase
    @gateway.expects(:ssl_post).twice.returns(successful_currency_codes_for_nz)
      .then.returns(successful_test_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response

    # "test-accepted" should be interpreted as success in test mode, and as failure otherwise
    assert_success response
    assert response.test?
  end

  def test_purchase_with_unsupported_currency
    @gateway.expects(:ssl_post).returns(successful_currency_codes_for_nz)

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:currency => 'FJD'))
    assert_failure response
    assert_equal 'Unsupported currency "FJD"', response.message
    assert response.test?
  end

  def test_purchase_with_supported_currency
    @gateway.expects(:ssl_post).twice.returns(successful_currency_codes_for_nz)
      .then.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:currency => 'JPY'))
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).twice.returns(successful_currency_codes_for_nz)
      .then.returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_test_purchase
    @gateway.expects(:ssl_post).twice.returns(successful_currency_codes_for_nz)
      .then.returns(failed_test_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_request_invalid_card
    @gateway.expects(:ssl_post).twice.returns(successful_currency_codes_for_nz)
      .then.returns(failed_purchase_response_invalid_card)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_request_system_error
    @gateway.expects(:ssl_post).twice.returns(successful_currency_codes_for_nz)
      .then.returns(failed_purchase_response_system_error)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_request_incorrect_amount
    @gateway.expects(:ssl_post).twice.returns(successful_currency_codes_for_nz)
      .then.returns(failed_purchase_response_incorrect_amount)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_request_access_denied
    @gateway.expects(:ssl_post).twice.returns(successful_currency_codes_for_nz)
      .then.returns(failed_purchase_response_access_denied)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_request_not_enough_parameters
    @gateway.expects(:ssl_post).twice.returns(successful_currency_codes_for_nz)
      .then.returns(failed_purchase_response_not_enough_parameters)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_request_invalid_json_in_response
    @gateway.expects(:ssl_post).twice.returns(successful_currency_codes_for_nz)
      .then.returns(response_with_invalid_json)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_ensure_does_not_respond_to_authorize
    assert !@gateway.respond_to?(:authorize)
  end

  def test_ensure_does_not_respond_to_void
    assert !@gateway.respond_to?(:void)
  end

  def test_ensure_does_not_respond_to_credit
    assert !@gateway.respond_to?(:credit)
  end

  def test_ensure_does_not_respond_to_unstore
    assert !@gateway.respond_to?(:unstore)
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    '{"response_code": 200, "message": "OK", "data": {"tx_transaction_id": "00000000000000", "result": "accepted"}}'
  end

  def successful_test_purchase_response
    '{"response_code": 200, "message": "OK", "data": {"tx_transaction_id": "00000000000000", "result": "test-accepted"}}'
  end

  def successful_currency_codes_for_nz
    '{"response_code": 200, "message": "OK", "data": {"0": "NZD", "1": "AUD", "2": "JPY"}}'  # stub
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    '{"response_code": 200, "message": "OK", "data": {"tx_transaction_id": "00000000000000", "result": "declined"}}'
  end

  def failed_test_purchase_response
    '{"response_code": 200, "message": "OK", "data": {"tx_transaction_id": "00000000000000", "result": "test-declined"}}'
  end

  def failed_purchase_response_invalid_card
    build_failed_response 303, 'Invalid card data'
  end

  def failed_purchase_response_system_error
    build_failed_response 402, 'System error'
  end

  def failed_purchase_response_incorrect_amount
    build_failed_response 302, 'Incorrect amount'
  end

  def failed_purchase_response_access_denied
    build_failed_response 400, 'System error'
  end

  def failed_purchase_response_not_enough_parameters
    build_failed_response 403, 'Not enough parameters'
  end

  def response_with_invalid_json
    '{"response_code": '
  end

  def build_failed_response(code, message)
    "{\"response_code\": #{code}, \"message\": \"#{message}\"}"
  end
end
