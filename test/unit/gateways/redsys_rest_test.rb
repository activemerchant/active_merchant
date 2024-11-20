require 'test_helper'

class RedsysRestTest < Test::Unit::TestCase
  include CommStub

  def setup
    @credentials = {
      login: '091952713',
      secret_key: 'sq7HjrUOBfKmC576ILgskD5srU870gJ7',
      terminal: '201'
    }
    @gateway = RedsysRestGateway.new(@credentials)
    @credit_card = credit_card
    @amount = 100

    @nt_credit_card = network_tokenization_credit_card(
      '4895370015293175',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      eci: '07',
      source: :network_token,
      verification_value: '737',
      brand: 'visa'
    )

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
        network_transaction_id:
      }
    }

    res = @gateway.purchase(123, credit_card, used_options)
    assert_success res
    assert_equal 'Transaction Approved', res.message
    assert_equal '446527', res.params['ds_authorisationcode']
  end

  def test_successful_purchase_with_execute_threed
    @gateway.expects(:ssl_post).returns(succcessful_3ds_auth_response_with_threeds_url)
    @options.merge!(execute_threed: true)
    res = @gateway.purchase(123, credit_card, @options)

    assert_equal res.success?, true
    assert_equal res.message, 'CardConfiguration'
    assert_equal res.params.include?('ds_emv3ds'), true
  end

  def test_successful_purchase_with_network_token
    stub_comms(@gateway, :commit) do
      @gateway.purchase(100, @nt_credit_card, @options)
    end.check_request do |post, _options|
      assert_equal post[:DS_MERCHANT_TRANSACTIONTYPE], '0'
      assert_equal post[:DS_MERCHANT_AMOUNT], @amount.to_s
      assert_equal post[:DS_MERCHANT_CURRENCY], '978'
      assert_equal post[:DS_MERCHANT_ORDER], @options[:order_id]
      assert_equal post[:Ds_Merchant_TokenData][:token], @nt_credit_card.number
      assert_equal post[:Ds_Merchant_TokenData][:tokenCryptogram], @nt_credit_card.payment_cryptogram
      assert_equal post[:Ds_Merchant_TokenData][:expirationDate], '2509'
      assert_equal post[:DS_MERCHANT_PRODUCTDESCRIPTION], 'Store+Purchase'
      assert_equal post[:DS_MERCHANT_DIRECTPAYMENT], true
    end.respond_with(successful_purchase_response_with_network_token)
  end

  def test_use_of_add_threeds
    post = {}
    @gateway.send(:add_threeds, post, @options)
    assert_equal post, {}

    execute3ds_post = {}
    execute3ds = @options.merge(execute_threed: true)
    @gateway.send(:add_threeds, execute3ds_post, execute3ds)
    assert_equal execute3ds_post.dig(:DS_MERCHANT_EMV3DS, :threeDSInfo), 'CardData'

    threeds_post = {}
    execute3ds[:execute_threed] = false
    execute3ds[:three_ds_2] = {
      browser_info: {
        accept_header: 'unknown',
        depth: 100,
        java: false,
        language: 'US',
        height: 1000,
        width: 500,
        timezone: '-120',
        user_agent: 'unknown'
      }
    }
    @gateway.send(:add_threeds, threeds_post, execute3ds)
    assert_equal post.dig(:DS_MERCHANT_EMV3DS, :browserAcceptHeader), execute3ds.dig(:three_ds_2, :accept_header)
    assert_equal post.dig(:DS_MERCHANT_EMV3DS, :browserScreenHeight), execute3ds.dig(:three_ds_2, :height)
  end

  def test_use_of_add_stored_credentials_cit
    stored_credentials_post = {}
    options = {
      stored_credential: {
        network_transaction_id: nil,
        initial_transaction: true,
        reason_type: 'recurring',
        initiator: 'cardholder'
      }
    }
    @gateway.send(:add_stored_credentials, stored_credentials_post, options)
    assert_equal stored_credentials_post[:DS_MERCHANT_IDENTIFIER], 'REQUIRED'
    assert_equal stored_credentials_post[:DS_MERCHANT_COF_TYPE], 'R'
    assert_equal stored_credentials_post[:DS_MERCHANT_COF_INI], 'S'
  end

  def test_use_of_add_stored_credentials_mit
    stored_credentials_post = {}
    options = {
      stored_credential: {
        network_transaction_id: '9999999999',
        initial_transaction: false,
        reason_type: 'recurring',
        initiator: 'merchant'
      }
    }
    @gateway.send(:add_stored_credentials, stored_credentials_post, options)
    assert_equal stored_credentials_post[:DS_MERCHANT_COF_TYPE], 'R'
    assert_equal stored_credentials_post[:DS_MERCHANT_COF_INI], 'N'
    assert_equal stored_credentials_post[:DS_MERCHANT_COF_TXNID], options[:stored_credential][:network_transaction_id]
  end

  def test_use_of_three_ds_exemption
    post = {}
    options = { three_ds_exemption_type: 'low_value' }
    @gateway.send(:add_threeds_exemption_data, post, options)
    assert_equal post[:DS_MERCHANT_EXCEP_SCA], 'LWV'
  end

  def test_use_of_three_ds_exemption_moto_option
    post = {}
    options = { three_ds_exemption_type: 'moto' }
    @gateway.send(:add_threeds_exemption_data, post, options)
    assert_equal post[:DS_MERCHANT_DIRECTPAYMENT], 'MOTO'
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
    @gateway.expects(:ssl_post).returns(successful_verify_response)
    response = @gateway.verify(credit_card, @options)
    assert_success response
  end

  def test_unsuccessful_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)
    response = @gateway.verify(credit_card, @options)
    assert_failure response
  end

  def test_unknown_currency
    assert_raise ArgumentError do
      @gateway.purchase(123, credit_card, @options.merge(currency: 'HUH WUT'))
    end
  end

  def test_default_currency
    assert_equal 'EUR', RedsysRestGateway.default_currency
  end

  def test_supported_countries
    assert_equal ['ES'], RedsysRestGateway.supported_countries
  end

  def test_supported_cardtypes
    assert_equal %i[visa master american_express jcb diners_club unionpay patagonia_365], RedsysRestGateway.supported_cardtypes
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

  def successful_verify_response
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19BbW91bnQiOiIwIiwiRHNfQ3VycmVuY3kiOiI5NzgiLCJEc19PcmRlciI6IjE3MDEzNjk0NzQ1NCIsIkRzX01lcmNoYW50Q29kZSI6Ijk5OTAwODg4MSIsIkRzX1Rlcm1pbmFsIjoiMjAxIiwiRHNfUmVzcG9uc2UiOiIwMDAwIiwiRHNfQXV0aG9yaXNhdGlvbkNvZGUiOiI1NDE4MTMiLCJEc19UcmFuc2FjdGlvblR5cGUiOiI3IiwiRHNfU2VjdXJlUGF5bWVudCI6IjAiLCJEc19MYW5ndWFnZSI6IjEiLCJEc19DYXJkTnVtYmVyIjoiNDU0ODgxKioqKioqMDAwNCIsIkRzX01lcmNoYW50RGF0YSI6IiIsIkRzX0NhcmRfQ291bnRyeSI6IjcyNCIsIkRzX0NhcmRfQnJhbmQiOiIxIiwiRHNfUHJvY2Vzc2VkUGF5TWV0aG9kIjoiMyIsIkRzX0NvbnRyb2xfMTcwMTM2OTQ3Njc2OCI6IjE3MDEzNjk0NzY3NjgifQ==\",\"Ds_Signature\":\"uoS0PJelg5_c4_7UgkYEJyatDuS3p2a-uJ3tB7SZPL4=\"}]
  end

  def failed_verify_response
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19BbW91bnQiOiIwIiwiRHNfQ3VycmVuY3kiOiI5NzgiLCJEc19PcmRlciI6IjE3MDEzNjk2NDI4NyIsIkRzX01lcmNoYW50Q29kZSI6Ijk5OTAwODg4MSIsIkRzX1Rlcm1pbmFsIjoiMjAxIiwiRHNfUmVzcG9uc2UiOiIwMTkwIiwiRHNfQXV0aG9yaXNhdGlvbkNvZGUiOiIiLCJEc19UcmFuc2FjdGlvblR5cGUiOiI3IiwiRHNfU2VjdXJlUGF5bWVudCI6IjAiLCJEc19MYW5ndWFnZSI6IjEiLCJEc19DYXJkTnVtYmVyIjoiNDI0MjQyKioqKioqNDI0MiIsIkRzX01lcmNoYW50RGF0YSI6IiIsIkRzX0NhcmRfQ291bnRyeSI6IjgyNiIsIkRzX1Byb2Nlc3NlZFBheU1ldGhvZCI6IjMiLCJEc19Db250cm9sXzE3MDEzNjk2NDUxMjIiOiIxNzAxMzY5NjQ1MTIyIn0=\",\"Ds_Signature\":\"oaS6-Zuz6v6l-Jgs5hKDZ0tn01W9Z3gKNfhmfAGdfMo=\"}]
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

  def succcessful_3ds_auth_response_with_threeds_url
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19PcmRlciI6IjAzMTNTZHFrQTcxUSIsIkRzX01lcmNoYW50Q29kZSI6Ijk5OTAwODg4MSIsIkRzX1Rlcm1pbmFsIjoiMjAxIiwiRHNfVHJhbnNhY3Rpb25UeXBlIjoiMCIsIkRzX0VNVjNEUyI6eyJwcm90b2NvbFZlcnNpb24iOiIyLjEuMCIsInRocmVlRFNTZXJ2ZXJUcmFuc0lEIjoiZjEzZTRmNWUtNzcwYS00M2ZhLThhZTktY2M3ZjEwNDVkZWFiIiwidGhyZWVEU0luZm8iOiJDYXJkQ29uZmlndXJhdGlvbiIsInRocmVlRFNNZXRob2RVUkwiOiJodHRwczovL3Npcy1kLnJlZHN5cy5lcy9zaXMtc2ltdWxhZG9yLXdlYi90aHJlZURzTWV0aG9kLmpzcCJ9LCJEc19DYXJkX1BTRDIiOiJZIn0=\",\"Ds_Signature\":\"eDXoo9vInPQtJThDg1hH2ohASsUNKxd9ly8cLeK5vm0=\"}]
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

  def successful_purchase_response_with_network_token
    %[{\"Ds_SignatureVersion\":\"HMAC_SHA256_V1\",\"Ds_MerchantParameters\":\"eyJEc19BbW91bnQiOiIxMDAiLCJEc19DdXJyZW5jeSI6Ijk3OCIsIkRzX09yZGVyIjoiMTc3ODY4ODM3LjMzIiwiRHNfTWVyY2hhbnRDb2RlIjoiOTk5MDA4ODgxIiwiRHNfVGVybWluYWwiOiIxIiwiRHNfUmVzcG9uc2UiOiIwMTk1IiwiRHNfQXV0aG9yaXNhdGlvbkNvZGUiOiIiLCJEc19UcmFuc2FjdGlvblR5cGUiOiIwIiwiRHNfU2VjdXJlUGF5bWVudCI6IjAiLCJEc19MYW5ndWFnZSI6IjEiLCJEc19DYXJkTnVtYmVyIjoiNDU0ODgxKioqKioqMDAwNCIsIkRzX01lcmNoYW50RGF0YSI6IiIsIkRzX0NhcmRfQ291bnRyeSI6IjcyNCIsIkRzX1Byb2Nlc3NlZFBheU1ldGhvZCI6IjMiLCJEc19Db250cm9sXzE3MzE1MTEzMjQ1MzYiOiIxNzMxNTExMzI0NTM2IiwiRHNfRUNJIjoiMDciLCJEc19SZXNwb25zZV9EZXNjcmlwdGlvbiI6IkVNSVNPUiBFWElHRSBBVVRFTlRJQ0FDScOTTiJ9\",\"Ds_Signature\":\"rn7nE_-I6V3cbxGN_0EK7SM8CcaMud7bssHzP97OOs8=\"}]
  end
end
