require 'test_helper'

class RedsysRestTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = RedsysRestGateway.new(fixtures(:redsys))
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1001',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    res = @gateway.purchase(123, credit_card, @options)
    assert_success res
    assert_equal 'Transaction Approved', res.message
    assert_equal '164513224019|100|978', res.authorization
    assert_equal '164513224019', res.params['ds_order']
  end

  def test_successful_purchase_requesting_credit_card_token
    @gateway.expects(:ssl_post).returns(successful_purchase_response_with_credit_card_token)
    res = @gateway.purchase(123, credit_card, @options)
    assert_success res
    assert_equal 'Transaction Approved', res.message
    assert_equal '164522070945|100|978', res.authorization
    assert_equal '164522070945', res.params['ds_order']
    assert_equal '2202182245100', res.params['ds_merchant_cof_txnid']
  end

  def test_successful_purchase_with_stored_credentials
    @gateway.expects(:ssl_post).returns(successful_purchase_initial_stored_credential_response)
    initial_options = @options.merge(
      stored_credential: {
        initial_transaction: true,
        reason_type: 'recurring'
      }
    )
    initial_res = @gateway.purchase(123, credit_card, initial_options)
    assert_success initial_res
    assert_equal 'Transaction Approved', initial_res.message
    assert_equal '2205022148020', initial_res.params['ds_merchant_cof_txnid']
    network_transaction_id = initial_res.params['Ds_Merchant_Cof_Txnid']

    @gateway.expects(:ssl_post).returns(successful_purchase_used_stored_credential_response)
    used_options = {
      order_id: '1002',
      stored_credential: {
        initial_transaction: false,
        reason_type: 'unscheduled',
        network_transaction_id: network_transaction_id
      }
    }
    res = @gateway.purchase(123, credit_card, used_options)
    assert_success res
    assert_equal 'Transaction Approved', res.message
    assert_equal '446527', res.params['ds_authorisationcode']
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    res = @gateway.purchase(123, credit_card, @options)
    assert_failure res
    assert_equal 'Refusal with no specific reason', res.message
    assert_equal '164513457405', res.params['ds_order']
  end

  def test_purchase_without_order_id
    assert_raise ArgumentError do
      @gateway.purchase(123, credit_card)
    end
  end

  def test_error_purchase
    @gateway.expects(:ssl_post).returns(error_purchase_response)
    res = @gateway.purchase(123, credit_card, @options)
    assert_failure res
    assert_equal 'SIS0051 ERROR', res.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    res = @gateway.authorize(123, credit_card, @options)
    assert_success res
    assert_equal 'Transaction Approved', res.message
    assert_equal '165125433469|100|978', res.authorization
    assert_equal '165125433469', res.params['ds_order']
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    res = @gateway.authorize(123, credit_card, @options)
    assert_failure res
    assert_equal 'Refusal with no specific reason', res.message
    assert_equal '165125669647', res.params['ds_order']
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    res = @gateway.capture(123, '165125709531|100|978', @options)
    assert_success res
    assert_equal 'Refund / Confirmation approved', res.message
    assert_equal '165125709531|100|978', res.authorization
    assert_equal '165125709531', res.params['ds_order']
  end

  def test_error_capture
    @gateway.expects(:ssl_post).returns(error_capture_response)
    res = @gateway.capture(123, '165125709531|100|978', @options)
    assert_failure res
    assert_equal 'SIS0062 ERROR', res.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    res = @gateway.refund(123, '165126074048|100|978', @options)
    assert_success res
    assert_equal 'Refund / Confirmation approved', res.message
    assert_equal '165126074048|100|978', res.authorization
    assert_equal '165126074048', res.params['ds_order']
  end

  def test_error_refund
    @gateway.expects(:ssl_post).returns(error_refund_response)
    res = @gateway.refund(123, '165126074048|100|978', @options)
    assert_failure res
    assert_equal 'SIS0057 ERROR', res.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    res = @gateway.void('165126313156|100|978', @options)
    assert_success res
    assert_equal 'Cancellation Accepted', res.message
    assert_equal '165126313156|100|978', res.authorization
    assert_equal '165126313156', res.params['ds_order']
  end

  def test_error_void
    @gateway.expects(:ssl_post).returns(error_void_response)
    res = @gateway.void('165126074048|100|978', @options)
    assert_failure res
    assert_equal 'SIS0222 ERROR', res.message
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response).then.returns(successful_void_response)
    response = @gateway.verify(credit_card, @options)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response).then.returns(error_void_response)
    response = @gateway.verify(credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_unsuccessful_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    response = @gateway.verify(credit_card, @options)
    assert_failure response
    assert_equal 'Refusal with no specific reason', response.message
  end

  def test_unknown_currency
    assert_raise ArgumentError do
      @gateway.purchase(123, credit_card, @options.merge(currency: 'HUH WUT'))
    end
  end

  def test_default_currency
    assert_equal 'EUR', RedsysGateway.default_currency
  end

  def test_supported_countries
    assert_equal ['ES'], RedsysGateway.supported_countries
  end

  def test_supported_cardtypes
    assert_equal %i[visa master american_express jcb diners_club unionpay], RedsysGateway.supported_cardtypes
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    '
      merchant_parameters: {"DS_MERCHANT_CURRENCY"=>"978", "DS_MERCHANT_AMOUNT"=>"100", "DS_MERCHANT_ORDER"=>"165126475243", "DS_MERCHANT_TRANSACTIONTYPE"=>"1", "DS_MERCHANT_PRODUCTDESCRIPTION"=>"", "DS_MERCHANT_TERMINAL"=>"3", "DS_MERCHANT_MERCHANTCODE"=>"327234688", "DS_MERCHANT_TITULAR"=>"Longbob Longsen", "DS_MERCHANT_PAN"=>"4242424242424242", "DS_MERCHANT_EXPIRYDATE"=>"2309", "DS_MERCHANT_CVV2"=>"123"}
    '
  end

  def post_scrubbed
    '
      merchant_parameters: {"DS_MERCHANT_CURRENCY"=>"978", "DS_MERCHANT_AMOUNT"=>"100", "DS_MERCHANT_ORDER"=>"165126475243", "DS_MERCHANT_TRANSACTIONTYPE"=>"1", "DS_MERCHANT_PRODUCTDESCRIPTION"=>"", "DS_MERCHANT_TERMINAL"=>"3", "DS_MERCHANT_MERCHANTCODE"=>"327234688", "DS_MERCHANT_TITULAR"=>"Longbob Longsen", "DS_MERCHANT_PAN"=>"[FILTERED]", "DS_MERCHANT_EXPIRYDATE"=>"2309", "DS_MERCHANT_CVV2"=>"[FILTERED]"}
    '
  end

  def successful_purchase_response
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19BbW91bnQiOiIxMDAiLCJEc19DdXJyZW5jeSI6Ijk3OCIsIkRzX09yZGVyIjoiMTY0NTEzMjI0MDE5IiwiRHNfTWVyY2hhbnRDb2RlIjoiMzI3MjM0Njg4IiwiRHNfVGVybWluYWwiOiIzIiwiRHNfUmVzcG9uc2UiOiIwMDAwIiwiRHNfQXV0aG9yaXNhdGlvbkNvZGUiOiI0ODgxODUiLCJEc19UcmFuc2FjdGlvblR5cGUiOiIwIiwiRHNfU2VjdXJlUGF5bWVudCI6IjAiLCJEc19MYW5ndWFnZSI6IjEiLCJEc19NZXJjaGFudERhdGEiOiIiLCJEc19DYXJkX0NvdW50cnkiOiI3MjQiLCJEc19DYXJkX0JyYW5kIjoiMSIsIkRzX1Byb2Nlc3NlZFBheU1ldGhvZCI6IjMiLCJEc19Db250cm9sXzE2NDUxMzIyNDE0NDkiOiIxNjQ1MTMyMjQxNDQ5In0=\",\"Ds_Signature\":\"63UXUOSVheJiBWxaWKih5yaVvfOSeOXAuoRUZyHBwJo=\"}]
  end

  def successful_purchase_response_with_credit_card_token
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19BbW91bnQiOiIxMDAiLCJEc19DdXJyZW5jeSI6Ijk3OCIsIkRzX09yZGVyIjoiMTY0NTIyMDcwOTQ1IiwiRHNfTWVyY2hhbnRDb2RlIjoiMzI3MjM0Njg4IiwiRHNfVGVybWluYWwiOiIzIiwiRHNfUmVzcG9uc2UiOiIwMDAwIiwiRHNfQXV0aG9yaXNhdGlvbkNvZGUiOiI0ODk5MTciLCJEc19UcmFuc2FjdGlvblR5cGUiOiIwIiwiRHNfU2VjdXJlUGF5bWVudCI6IjAiLCJEc19MYW5ndWFnZSI6IjEiLCJEc19NZXJjaGFudERhdGEiOiIiLCJEc19DYXJkX0NvdW50cnkiOiI3MjQiLCJEc19DYXJkX0JyYW5kIjoiMSIsIkRzX01lcmNoYW50X0NvZl9UeG5pZCI6IjIyMDIxODIyNDUxMDAiLCJEc19Qcm9jZXNzZWRQYXlNZXRob2QiOiIzIiwiRHNfQ29udHJvbF8xNjQ1MjIwNzEwNDcyIjoiMTY0NTIyMDcxMDQ3MiJ9\",\"Ds_Signature\":\"YV6W2Ym-p84q5246GK--hc-1L6Sz0tHOcMLYZtDIf-s=\"}]
  end

  def successful_purchase_initial_stored_credential_response
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19BbW91bnQiOiIxMDAiLCJEc19DdXJyZW5jeSI6Ijk3OCIsIkRzX09yZGVyIjoiMTY1MTUyMDg4MTM3IiwiRHNfTWVyY2hhbnRDb2RlIjoiMzI3MjM0Njg4IiwiRHNfVGVybWluYWwiOiIzIiwiRHNfUmVzcG9uc2UiOiIwMDAwIiwiRHNfQXV0aG9yaXNhdGlvbkNvZGUiOiI0NTk5MjIiLCJEc19UcmFuc2FjdGlvblR5cGUiOiIwIiwiRHNfU2VjdXJlUGF5bWVudCI6IjAiLCJEc19MYW5ndWFnZSI6IjEiLCJEc19NZXJjaGFudERhdGEiOiIiLCJEc19DYXJkX0NvdW50cnkiOiI3MjQiLCJEc19DYXJkX0JyYW5kIjoiMSIsIkRzX01lcmNoYW50X0NvZl9UeG5pZCI6IjIyMDUwMjIxNDgwMjAiLCJEc19Qcm9jZXNzZWRQYXlNZXRob2QiOiIzIiwiRHNfQ29udHJvbF8xNjUxNTIwODgyNDA5IjoiMTY1MTUyMDg4MjQwOSJ9\",\"Ds_Signature\":\"gIQ6ebPg-nXwCZ0Vld7LbSoKBXizlmaVe1djVDuVF4s=\"}]
  end

  def successful_purchase_used_stored_credential_response
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19BbW91bnQiOiIxMDAiLCJEc19DdXJyZW5jeSI6Ijk3OCIsIkRzX09yZGVyIjoiMTY1MTUyMDg4MjQ0IiwiRHNfTWVyY2hhbnRDb2RlIjoiMzI3MjM0Njg4IiwiRHNfVGVybWluYWwiOiIzIiwiRHNfUmVzcG9uc2UiOiIwMDAwIiwiRHNfQXV0aG9yaXNhdGlvbkNvZGUiOiI0NDY1MjciLCJEc19UcmFuc2FjdGlvblR5cGUiOiIwIiwiRHNfU2VjdXJlUGF5bWVudCI6IjAiLCJEc19MYW5ndWFnZSI6IjEiLCJEc19NZXJjaGFudERhdGEiOiIiLCJEc19DYXJkX0NvdW50cnkiOiI3MjQiLCJEc19DYXJkX0JyYW5kIjoiMSIsIkRzX1Byb2Nlc3NlZFBheU1ldGhvZCI6IjMiLCJEc19Db250cm9sXzE2NTE1MjA4ODMzMDMiOiIxNjUxNTIwODgzMzAzIn0=\",\"Ds_Signature\":\"BC3UB0Q0IgOyuXbEe8eJddK_H77XJv7d2MQr50d4v2o=\"}]
  end

  def failed_purchase_response
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19BbW91bnQiOiIxMDAiLCJEc19DdXJyZW5jeSI6Ijk3OCIsIkRzX09yZGVyIjoiMTY0NTEzNDU3NDA1IiwiRHNfTWVyY2hhbnRDb2RlIjoiMzI3MjM0Njg4IiwiRHNfVGVybWluYWwiOiIzIiwiRHNfUmVzcG9uc2UiOiIwMTkwIiwiRHNfQXV0aG9yaXNhdGlvbkNvZGUiOiIiLCJEc19UcmFuc2FjdGlvblR5cGUiOiIwIiwiRHNfU2VjdXJlUGF5bWVudCI6IjAiLCJEc19MYW5ndWFnZSI6IjEiLCJEc19NZXJjaGFudERhdGEiOiIiLCJEc19DYXJkX0NvdW50cnkiOiI4MjYiLCJEc19Qcm9jZXNzZWRQYXlNZXRob2QiOiIzIiwiRHNfQ29udHJvbF8xNjQ1MTM0NTc1MzU1IjoiMTY0NTEzNDU3NTM1NSJ9\",\"Ds_Signature\":\"zm3FCtPPhf5Do7FzlB4DbGDgkFcNFhXQCikc-batUW0=\"}]
  end

  def error_purchase_response
    %[{\"errorCode\":\"SIS0051\"}]
  end

  def successful_authorize_response
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19BbW91bnQiOiIxMDAiLCJEc19DdXJyZW5jeSI6Ijk3OCIsIkRzX09yZGVyIjoiMTY1MTI1NDMzNDY5IiwiRHNfTWVyY2hhbnRDb2RlIjoiMzI3MjM0Njg4IiwiRHNfVGVybWluYWwiOiIzIiwiRHNfUmVzcG9uc2UiOiIwMDAwIiwiRHNfQXV0aG9yaXNhdGlvbkNvZGUiOiI0NTgyNjAiLCJEc19UcmFuc2FjdGlvblR5cGUiOiIxIiwiRHNfU2VjdXJlUGF5bWVudCI6IjAiLCJEc19MYW5ndWFnZSI6IjEiLCJEc19NZXJjaGFudERhdGEiOiIiLCJEc19DYXJkX0NvdW50cnkiOiI3MjQiLCJEc19DYXJkX0JyYW5kIjoiMSIsIkRzX1Byb2Nlc3NlZFBheU1ldGhvZCI6IjMiLCJEc19Db250cm9sXzE2NTEyNTQzMzYzMTEiOiIxNjUxMjU0MzM2MzExIn0=\",\"Ds_Signature\":\"8H7F04WLREFYi67DxusWJX12NZOrMrmtDOVWYA-604M=\"}]
  end

  def failed_authorize_response
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19BbW91bnQiOiIxMDAiLCJEc19DdXJyZW5jeSI6Ijk3OCIsIkRzX09yZGVyIjoiMTY1MTI1NjY5NjQ3IiwiRHNfTWVyY2hhbnRDb2RlIjoiMzI3MjM0Njg4IiwiRHNfVGVybWluYWwiOiIzIiwiRHNfUmVzcG9uc2UiOiIwMTkwIiwiRHNfQXV0aG9yaXNhdGlvbkNvZGUiOiIiLCJEc19UcmFuc2FjdGlvblR5cGUiOiIxIiwiRHNfU2VjdXJlUGF5bWVudCI6IjAiLCJEc19MYW5ndWFnZSI6IjEiLCJEc19NZXJjaGFudERhdGEiOiIiLCJEc19DYXJkX0NvdW50cnkiOiI4MjYiLCJEc19Qcm9jZXNzZWRQYXlNZXRob2QiOiIzIiwiRHNfQ29udHJvbF8xNjUxMjU2Njk4MDE0IjoiMTY1MTI1NjY5ODAxNCJ9\",\"Ds_Signature\":\"abBYZFLtYloFRQDTnMhXASMcS-4SLxEBNpTfBVCBtuc=\"}]
  end

  def successful_capture_response
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19BbW91bnQiOiIxMDAiLCJEc19DdXJyZW5jeSI6Ijk3OCIsIkRzX09yZGVyIjoiMTY1MTI1NzA5NTMxIiwiRHNfTWVyY2hhbnRDb2RlIjoiMzI3MjM0Njg4IiwiRHNfVGVybWluYWwiOiIzIiwiRHNfUmVzcG9uc2UiOiIwOTAwIiwiRHNfQXV0aG9yaXNhdGlvbkNvZGUiOiI0NDQ5NTIiLCJEc19UcmFuc2FjdGlvblR5cGUiOiIyIiwiRHNfU2VjdXJlUGF5bWVudCI6IjAiLCJEc19MYW5ndWFnZSI6IjEiLCJEc19NZXJjaGFudERhdGEiOiIiLCJEc19DYXJkX0NvdW50cnkiOiI3MjQiLCJEc19DYXJkX0JyYW5kIjoiMSIsIkRzX1Byb2Nlc3NlZFBheU1ldGhvZCI6IjMiLCJEc19Db250cm9sXzE2NTEyNTcwOTc5NjIiOiIxNjUxMjU3MDk3OTYyIn0=\",\"Ds_Signature\":\"9lKWSe94kdviKN_ApUV9nQAS6VQc7gPeARyhpbN3sXA=\"}]
  end

  def error_capture_response
    %[{\"errorCode\":\"SIS0062\"}]
  end

  def successful_refund_response
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19BbW91bnQiOiIxMDAiLCJEc19DdXJyZW5jeSI6Ijk3OCIsIkRzX09yZGVyIjoiMTY1MTI2MDc0MDQ4IiwiRHNfTWVyY2hhbnRDb2RlIjoiMzI3MjM0Njg4IiwiRHNfVGVybWluYWwiOiIzIiwiRHNfUmVzcG9uc2UiOiIwOTAwIiwiRHNfQXV0aG9yaXNhdGlvbkNvZGUiOiI0NDQ5NjQiLCJEc19UcmFuc2FjdGlvblR5cGUiOiIzIiwiRHNfU2VjdXJlUGF5bWVudCI6IjAiLCJEc19MYW5ndWFnZSI6IjEiLCJEc19NZXJjaGFudERhdGEiOiIiLCJEc19DYXJkX0NvdW50cnkiOiI3MjQiLCJEc19DYXJkX0JyYW5kIjoiMSIsIkRzX1Byb2Nlc3NlZFBheU1ldGhvZCI6IjMiLCJEc19Db250cm9sXzE2NTEyNjA3NDM0NjAiOiIxNjUxMjYwNzQzNDYwIn0=\",\"Ds_Signature\":\"iGhvjtqbV-b3cvEoJxIwp3kE1b65onfZnF9Kb5JWWhw=\"}]
  end

  def error_refund_response
    %[{\"errorCode\":\"SIS0057\"}]
  end

  def successful_void_response
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19BbW91bnQiOiIxMDAiLCJEc19DdXJyZW5jeSI6Ijk3OCIsIkRzX09yZGVyIjoiMTY1MTI2MzEzMTU2IiwiRHNfTWVyY2hhbnRDb2RlIjoiMzI3MjM0Njg4IiwiRHNfVGVybWluYWwiOiIzIiwiRHNfUmVzcG9uc2UiOiIwNDAwIiwiRHNfQXV0aG9yaXNhdGlvbkNvZGUiOiI0NTgzMDQiLCJEc19UcmFuc2FjdGlvblR5cGUiOiI5IiwiRHNfU2VjdXJlUGF5bWVudCI6IjAiLCJEc19MYW5ndWFnZSI6IjEiLCJEc19NZXJjaGFudERhdGEiOiIiLCJEc19DYXJkX0NvdW50cnkiOiI3MjQiLCJEc19DYXJkX0JyYW5kIjoiMSIsIkRzX1Byb2Nlc3NlZFBheU1ldGhvZCI6IjMiLCJEc19Db250cm9sXzE2NTEyNjMxMzQzMzUiOiIxNjUxMjYzMTM0MzM1In0=\",\"Ds_Signature\":\"retARpDayWGhU-pa3OEBIT7b4iG91Mi98jHGB3EyD6c=\"}]
  end

  def error_void_response
    %[{\"errorCode\":\"SIS0222\"}]
  end
end
