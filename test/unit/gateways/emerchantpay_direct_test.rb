require 'test_helper'

class EmerchantpayDirectTest < Test::Unit::TestCase

  include CommStub

  RESPONSE_SUCCESS_MSG            = 'TESTMODE: No real money will be transferred!'.freeze
  RESPONSE_SUCCESS_TECH_MSG       = 'TESTMODE: No real money will be transferred!'.freeze
  RESPONSE_SUCCESS_UNQ_ID         = '4f01752204eef8eba95d2b657f8ab853'.freeze
  RESPONSE_SUCCESS_TXN_ID         = '02b7a37b92eb7838a105c3d3a503e096'.freeze
  RESPONSE_SUCCESS_REF_TXN_UNQ_ID = '2d53f63ba8543e10be851b0718b6ab2a'.freeze
  RESPONSE_SUCCESS_REF_TXN_ID     = 'ab2ad283bd49986cb9f0ffab9816aefd'.freeze

  RESPONSE_FAILED_MSG_CARD_INVALID      = 'Credit card number is invalid.'.freeze
  RESPONSE_FAILED_TECH_MSG_CARD_INVALID = 'card_number is invalid or missing'.freeze
  RESPONSE_FAILED_MSG_INVALID_REF_TXN   = 'Reference Transaction could not be found!'.freeze
  RESPONSE_FAILED_UNQ_ID                = 'ab8a9131307d6706ae6fc51bf80e7bdf'.freeze
  RESPONSE_FAILED_TXN_ID                = 'c275ff95680dd38f2ae297985a39dc21'.freeze

  RESPONSE_MSG_CONTACT_SUPPORT = 'Please, try again or contact support!'.freeze
  RESPONSE_MODE                = 'test'.freeze
  RESPONSE_DESCRIPTOR          = 'test'.freeze

  EmerchantpayDirectGateway::RESPONSE_ERROR_CODES.each do |key, _|
    name = "response_code_#{key}"
    define_method(name) { EmerchantpayDirectGateway::RESPONSE_ERROR_CODES[key] }
  end

  EmerchantpayDirectGateway::ISSUER_RESPONSE_ERROR_CODES.each do |key, _|
    name = "issuer_code_#{key}"
    define_method(name) { EmerchantpayDirectGateway::ISSUER_RESPONSE_ERROR_CODES[key] }
  end

  def setup
    @gateway = EmerchantpayDirectGateway.new(
      username: 'username',
      password: 'password',
      token:    'token'
    )

    prepare_shared_test_data
  end

  def test_successful_authorize
    response = build_initial_auth_trx

    expect_successful_response(response,
                               transaction_type: EmerchantpayDirectGateway::AUTHORIZE,
                               unique_id:        RESPONSE_SUCCESS_UNQ_ID)
  end

  def test_failed_authorize
    failed_auth_response = failed_init_trx_response(EmerchantpayDirectGateway::AUTHORIZE)

    @gateway.expects(:ssl_post).returns(failed_auth_response)

    response = @gateway.authorize(@amount, @credit_card, @options)

    expect_failed_response(response,
                           status:           EmerchantpayDirectGateway::DECLINED,
                           transaction_type: EmerchantpayDirectGateway::AUTHORIZE,
                           unique_id:        RESPONSE_FAILED_UNQ_ID,
                           code:             response_code_invalid_card_error)
  end

  def test_successful_capture
    successful_capture_response = successful_ref_trx_response(EmerchantpayDirectGateway::CAPTURE)

    @gateway.expects(:ssl_post).returns(successful_capture_response)

    capture = @gateway.capture(@amount, build_initial_auth_trx.authorization, @options)

    expect_successful_response(capture,
                               transaction_type: EmerchantpayDirectGateway::CAPTURE,
                               unique_id:        RESPONSE_SUCCESS_REF_TXN_UNQ_ID)
  end

  def test_failed_capture
    failed_capture_response = failed_ref_trx_response(EmerchantpayDirectGateway::CAPTURE)

    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, '', @options)

    expect_failed_response(response,
                           status:           EmerchantpayDirectGateway::ERROR,
                           transaction_type: EmerchantpayDirectGateway::CAPTURE,
                           code:             response_code_txn_not_found_error)
  end

  def test_successful_purchase
    successful_purchase_response = successful_init_trx_response(EmerchantpayDirectGateway::SALE)

    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    expect_successful_response(response,
                               transaction_type: EmerchantpayDirectGateway::SALE,
                               unique_id:        RESPONSE_SUCCESS_UNQ_ID)
  end

  def test_failed_purchase
    failed_purchase_response = failed_init_trx_response(EmerchantpayDirectGateway::SALE)

    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    expect_failed_response(response,
                           status:           EmerchantpayDirectGateway::DECLINED,
                           transaction_type: EmerchantpayDirectGateway::SALE,
                           unique_id:        RESPONSE_FAILED_UNQ_ID,
                           code:             response_code_invalid_card_error)
  end

  def test_successful_refund
    successful_refund_response = successful_ref_trx_response(EmerchantpayDirectGateway::REFUND)

    @gateway.expects(:ssl_post).returns(successful_refund_response)

    refund = @gateway.refund(@amount, build_initial_purchase_trx.authorization, @options)

    expect_successful_response(refund,
                               transaction_type: EmerchantpayDirectGateway::REFUND)
  end

  def test_failed_refund
    failed_refund_response = failed_ref_trx_response(EmerchantpayDirectGateway::REFUND)

    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, '', @options)

    expect_failed_response(response,
                           status:           EmerchantpayDirectGateway::ERROR,
                           transaction_type: EmerchantpayDirectGateway::REFUND,
                           code:             response_code_txn_not_found_error)
  end

  def test_successful_verify
    successful_auth_response = successful_init_trx_response(EmerchantpayDirectGateway::AUTHORIZE)
    successful_void_response = successful_ref_trx_response(EmerchantpayDirectGateway::VOID)

    response = stub_comms(@gateway, :ssl_post) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_auth_response, successful_void_response)

    assert_success response
    expect_successful_response(response,
                               transaction_type: EmerchantpayDirectGateway::AUTHORIZE,
                               unique_id:        RESPONSE_SUCCESS_UNQ_ID)
  end

  def test_failed_verify
    failed_auth_response = failed_init_trx_response(EmerchantpayDirectGateway::AUTHORIZE)
    failed_void_response = failed_ref_trx_response(EmerchantpayDirectGateway::VOID)

    response = stub_comms(@gateway, :ssl_post) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_auth_response, failed_void_response)

    expect_failed_response(response,
                           status:           EmerchantpayDirectGateway::DECLINED,
                           transaction_type: EmerchantpayDirectGateway::AUTHORIZE,
                           unique_id:        nil,
                           code:             response_code_invalid_card_error)
  end

  def test_successful_void
    successful_void_response = successful_ref_trx_response(EmerchantpayDirectGateway::VOID)

    @gateway.expects(:ssl_post).returns(successful_void_response)

    void = @gateway.void(build_initial_auth_trx.authorization, @options)

    expect_successful_response(void,
                               transaction_type: EmerchantpayDirectGateway::VOID)
  end

  def test_failed_void
    failed_void_response = failed_ref_trx_response(EmerchantpayDirectGateway::VOID)

    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('', @options)

    expect_failed_response(response,
                           status:           EmerchantpayDirectGateway::ERROR,
                           transaction_type: EmerchantpayDirectGateway::VOID,
                           code:             response_code_txn_not_found_error)
  end

  def test_scrub
    assert_equal true, @gateway.supports_scrubbing?
  end

  private

  def prepare_shared_test_data
    @credit_card     = credit_card
    @amount          = 100

    @options = {
      order_id:        1,
      billing_address: address,
      description:     'Store Purchase'
    }
  end

  def expect_successful_response(response, expected_params)
    assert_success response

    response_params = response.params

    assert_nil response_params['code']
    assert_nil response.error_code

    assert_equal response_params['transaction_type'], expected_params[:transaction_type]
    assert_equal response_params['response_code'], issuer_code_approved

    assert response.message

    assert_equal response.authorization, expected_params[:unique_id]

    expect_response_params(response, expected_params)

    assert response.test?
  end

  def expect_failed_response(response, expected_params)
    assert_failure response

    expect_response_params(response, expected_params)

    assert response.message
    assert response.error_code

    assert_mapped_response_code(response, expected_params)
    assert_nil response.authorization
  end

  def expect_response_params(response, expected_params)
    return unless expected_params

    expected_params.each do |key, value|
      assert_equal(value, response.params[key.to_s]) if value.present?
    end
  end

  def assert_mapped_response_code(response, items)
    response_params = response.params

    return unless items.include?('code') && response_params.key?('code')

    mapped_response_error_code = @gateway.map_error_code(response_params['code'])

    assert_equal mapped_response_error_code, response.error_code
  end

  def build_initial_purchase_trx
    successful_purchase_response = successful_init_trx_response(EmerchantpayDirectGateway::SALE)

    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def build_initial_auth_trx
    successful_auth_response = successful_init_trx_response(EmerchantpayDirectGateway::AUTHORIZE)

    @gateway.expects(:ssl_post).returns(successful_auth_response)

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def successful_init_trx_response(trx_type)
    <<-SUCCESSFUL_RESPONSE
{
    "unique_id":          "#{RESPONSE_SUCCESS_UNQ_ID}",
    "authorization_code": #{random_authorization_code},
    "transaction_id":     "#{RESPONSE_SUCCESS_TXN_ID}",
    "timestamp":          "#{response_timestamp}",
    "mode":               "#{RESPONSE_MODE}",
    "descriptor":         "#{RESPONSE_DESCRIPTOR}",
    "amount":             #{response_amount},
    "currency":           "#{currency_code}",
    "transaction_type":   "#{trx_type}",
    "status":             "#{EmerchantpayDirectGateway::APPROVED}",
    "response_code":      "00",
    "technical_message":  "#{RESPONSE_SUCCESS_TECH_MSG}",
    "message":            "#{RESPONSE_SUCCESS_MSG}"
}
    SUCCESSFUL_RESPONSE
  end

  def failed_init_trx_response(trx_type)
    <<-FAILED_RESPONSE
{
    "unique_id":          "#{RESPONSE_FAILED_UNQ_ID}",
    "authorization_code": #{random_authorization_code},
    "transaction_id":     "#{RESPONSE_FAILED_TXN_ID}",
    "timestamp":          "#{response_timestamp}",
    "mode":               "#{RESPONSE_MODE}",
    "descriptor":         "#{RESPONSE_DESCRIPTOR}",
    "transaction_type":   "#{trx_type}",
    "technical_message":  "#{RESPONSE_FAILED_TECH_MSG_CARD_INVALID}",
    "message":            "#{RESPONSE_FAILED_MSG_CARD_INVALID}",
    "amount":             #{response_amount},
    "currency":           "#{currency_code}",
    "code":               510,
    "status":             "#{EmerchantpayDirectGateway::DECLINED}",
    "response_code":      "01"
}
    FAILED_RESPONSE
  end

  def successful_ref_trx_response(trx_type)
    <<-SUCCESSFUL_RESPONSE
{
    "unique_id":         "#{RESPONSE_SUCCESS_REF_TXN_UNQ_ID}",
    "transaction_id":    "#{RESPONSE_SUCCESS_REF_TXN_ID}",
    "timestamp":         "#{response_timestamp}",
    "mode":              "#{RESPONSE_MODE}",
    "descriptor":        "#{RESPONSE_DESCRIPTOR}",
    "amount":            #{response_amount},
    "currency":          "#{currency_code}",
    "transaction_type":  "#{trx_type}",
    "status":            "#{EmerchantpayDirectGateway::APPROVED}",
    "response_code":     "00",
    "technical_message": "#{RESPONSE_SUCCESS_TECH_MSG}",
    "message":           "#{RESPONSE_SUCCESS_MSG}"
}
    SUCCESSFUL_RESPONSE
  end

  def failed_ref_trx_response(trx_type)
    message = "#{RESPONSE_FAILED_MSG_INVALID_REF_TXN} #{RESPONSE_MSG_CONTACT_SUPPORT}"
    <<-FAILED_RESPONSE
{
    "code":             460,
    "status":           "#{EmerchantpayDirectGateway::ERROR}",
    "message":          "#{message}",
    "transaction_type": "#{trx_type}"
}
    FAILED_RESPONSE
  end

  def random_authorization_code
    rand(100_000..999_999)
  end

  def response_amount
    @amount
  end

  def response_timestamp
    Time.now.utc.iso8601
  end

  def currency_code
    @gateway.default_currency
  end
end
