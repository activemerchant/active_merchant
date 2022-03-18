require 'test_helper'

class NuveiTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = NuveiGateway.new(
      merchantId: '12345',
      merchantSiteId: '67890',
      secret: 'secretkey',
    )

    @options = {
      orderId: '1',
      billingAddress: address,
      description: 'Store Purchase'
    }
    @amount = 100
    @credit_card = credit_card
  end

  def test_successful_authorize
    expect_session
    
    @gateway.expects(:ssl_post)
      .with("https://ppp-test.safecharge.com/ppp/api/v1/initPayment.do", anything, anything)
      .returns(successful_initPayment_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '#7914775043909934#', response.authorization
    assert_equal 'R', response.avs_result['code']
    assert_equal 'M', response.cvv_result['code']
    assert response.test?
  end

  # def test_successful_authorize_bank_account
  #   @gateway.expects(:ssl_post).returns(successful_authorize_response)

  #   response = @gateway.authorize(@amount, @bank_account, @options)
  #   assert_success response

  #   assert_equal '#7914775043909934#', response.authorization
  #   assert_equal 'R', response.avs_result['code']
  #   assert_equal 'M', response.cvv_result['code']
  #   assert response.test?
  # end

  # def test_successful_authorize_with_3ds
  #   @gateway.expects(:ssl_post).returns(successful_authorize_with_3ds_response)

  #   response = @gateway.authorize(@amount, @three_ds_enrolled_card, @options.merge(execute_threed: true))
  #   assert response.test?
  #   refute response.authorization.blank?
  #   assert_equal '#8835440446784145#', response.authorization
  #   assert_equal response.params['resultCode'], 'RedirectShopper'
  #   refute response.params['issuerUrl'].blank?
  #   refute response.params['md'].blank?
  #   refute response.params['paRequest'].blank?
  # end

  # def test_failed_authorize_with_unexpected_3ds
  #   @gateway.expects(:ssl_post).returns(successful_authorize_with_3ds_response)
  #   response = @gateway.authorize(@amount, @three_ds_enrolled_card, @options)
  #   assert_failure response
  #   assert_match 'Received unexpected 3DS authentication response', response.message
  # end

  # def test_successful_authorize_with_recurring_contract_type
  #   stub_comms do
  #     @gateway.authorize(100, @credit_card, @options.merge({ recurring_contract_type: 'ONECLICK' }))
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'ONECLICK', JSON.parse(data)['recurring']['contract']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_adds_3ds1_standalone_fields
  #   eci = '05'
  #   cavv = '3q2+78r+ur7erb7vyv66vv\/\/\/\/8='
  #   cavv_algorithm = '1'
  #   xid = 'ODUzNTYzOTcwODU5NzY3Qw=='
  #   enrolled = 'Y'
  #   authentication_response_status = 'Y'
  #   options_with_3ds1_standalone = @options.merge(
  #     three_d_secure: {
  #       eci: eci,
  #       cavv: cavv,
  #       cavv_algorithm: cavv_algorithm,
  #       xid: xid,
  #       enrolled: enrolled,
  #       authentication_response_status: authentication_response_status
  #     }
  #   )
  #   stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options_with_3ds1_standalone)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal eci, JSON.parse(data)['mpiData']['eci']
  #     assert_equal cavv, JSON.parse(data)['mpiData']['cavv']
  #     assert_equal cavv_algorithm, JSON.parse(data)['mpiData']['cavvAlgorithm']
  #     assert_equal xid, JSON.parse(data)['mpiData']['xid']
  #     assert_equal enrolled, JSON.parse(data)['mpiData']['directoryResponse']
  #     assert_equal authentication_response_status, JSON.parse(data)['mpiData']['authenticationResponse']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_adds_3ds2_standalone_fields
  #   version = '2.1.0'
  #   eci = '02'
  #   cavv = 'jJ81HADVRtXfCBATEp01CJUAAAA='
  #   ds_transaction_id = '97267598-FAE6-48F2-8083-C23433990FBC'
  #   directory_response_status = 'C'
  #   authentication_response_status = 'Y'
  #   options_with_3ds2_standalone = @options.merge(
  #     three_d_secure: {
  #       version: version,
  #       eci: eci,
  #       cavv: cavv,
  #       ds_transaction_id: ds_transaction_id,
  #       directory_response_status: directory_response_status,
  #       authentication_response_status: authentication_response_status
  #     }
  #   )
  #   stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options_with_3ds2_standalone)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal version, JSON.parse(data)['mpiData']['threeDSVersion']
  #     assert_equal eci, JSON.parse(data)['mpiData']['eci']
  #     assert_equal cavv, JSON.parse(data)['mpiData']['cavv']
  #     assert_equal ds_transaction_id, JSON.parse(data)['mpiData']['dsTransID']
  #     assert_equal directory_response_status, JSON.parse(data)['mpiData']['directoryResponse']
  #     assert_equal authentication_response_status, JSON.parse(data)['mpiData']['authenticationResponse']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_failed_authorize
  #   @gateway.expects(:ssl_post).returns(failed_authorize_response)

  #   response = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_equal 'Expired Card', response.message
  #   assert_failure response
  # end

  # def test_failed_authorise3d
  #   @gateway.expects(:ssl_post).returns(failed_authorize_response)

  #   response = @gateway.send(:commit, 'authorise3d', {}, {})

  #   assert_equal 'Expired Card', response.message
  #   assert_failure response
  # end

  # def test_failed_authorise3ds2
  #   @gateway.expects(:ssl_post).returns(failed_authorize_3ds2_response)

  #   response = @gateway.send(:commit, 'authorise3ds2', {}, {})

  #   assert_equal '3D Not Authenticated', response.message
  #   assert_failure response
  # end

  # def test_successful_capture
  #   @gateway.expects(:ssl_post).returns(successful_capture_response)
  #   response = @gateway.capture(@amount, '7914775043909934')
  #   assert_equal '7914775043909934#8814775564188305#', response.authorization
  #   assert_success response
  #   assert response.test?
  # end

  # def test_failed_capture
  #   @gateway.expects(:ssl_post).returns(failed_capture_response)
  #   response = @gateway.capture(nil, '')
  #   assert_nil response.authorization
  #   assert_equal 'Original pspReference required for this operation', response.message
  #   assert_failure response
  # end

  # def test_successful_purchase_with_credit_card
  #   response = stub_comms do
  #     @gateway.purchase(@amount, @credit_card, @options)
  #   end.respond_with(successful_authorize_response, successful_capture_response)
  #   assert_success response
  #   assert_equal '7914775043909934#8814775564188305#', response.authorization
  #   assert response.test?
  # end

  # def test_successful_purchase_with_bank_account
  #   response = stub_comms do
  #     @gateway.purchase(@amount, @bank_account, @options)
  #   end.respond_with(successful_authorize_response, successful_capture_response)
  #   assert_success response
  #   assert_equal '7914775043909934#8814775564188305#', response.authorization
  #   assert response.test?
  # end

  # def test_successful_purchase_with_elo_card
  #   response = stub_comms do
  #     @gateway.purchase(@amount, @elo_credit_card, @options)
  #   end.respond_with(simple_successful_authorize_response, simple_successful_capture_repsonse)
  #   assert_success response
  #   assert_equal '8835511210681145#8835511210689965#', response.authorization
  #   assert response.test?
  # end

  # def test_successful_purchase_with_cabal_card
  #   response = stub_comms do
  #     @gateway.purchase(@amount, @cabal_credit_card, @options)
  #   end.respond_with(simple_successful_authorize_response, simple_successful_capture_repsonse)
  #   assert_success response
  #   assert_equal '8835511210681145#8835511210689965#', response.authorization
  #   assert response.test?
  # end

  # def test_successful_purchase_with_unionpay_card
  #   response = stub_comms do
  #     @gateway.purchase(@amount, @unionpay_credit_card, @options)
  #   end.respond_with(simple_successful_authorize_response, simple_successful_capture_repsonse)
  #   assert_success response
  #   assert_equal '8835511210681145#8835511210689965#', response.authorization
  #   assert response.test?
  # end

  # def test_successful_maestro_purchase
  #   response = stub_comms do
  #     @gateway.purchase(@amount, @credit_card, @options.merge({ selected_brand: 'maestro', overwrite_brand: 'true' }))
  #   end.check_request do |endpoint, data, _headers|
  #     if /authorise/.match?(endpoint)
  #       assert_match(/"overwriteBrand":true/, data)
  #       assert_match(/"selectedBrand":"maestro"/, data)
  #     end
  #   end.respond_with(successful_authorize_response, successful_capture_response)
  #   assert_success response
  #   assert_equal '7914775043909934#8814775564188305#', response.authorization
  #   assert response.test?
  # end

  # def test_3ds_2_fields_sent
  #   stub_comms do
  #     @gateway.authorize(@amount, @credit_card, @normalized_3ds_2_options)
  #   end.check_request do |_endpoint, data, _headers|
  #     data = JSON.parse(data)
  #     assert_equal 'browser', data['threeDS2RequestData']['deviceChannel']
  #     assert_equal 'unknown', data['browserInfo']['acceptHeader']
  #     assert_equal 100, data['browserInfo']['colorDepth']
  #     assert_equal false, data['browserInfo']['javaEnabled']
  #     assert_equal 'US', data['browserInfo']['language']
  #     assert_equal 1000, data['browserInfo']['screenHeight']
  #     assert_equal 500, data['browserInfo']['screenWidth']
  #     assert_equal '-120', data['browserInfo']['timeZoneOffset']
  #     assert_equal 'unknown', data['browserInfo']['userAgent']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_installments_sent
  #   stub_comms do
  #     @gateway.authorize(@amount, @credit_card, @options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 2, JSON.parse(data)['installments']['value']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_capture_delay_hours_sent
  #   stub_comms do
  #     @gateway.authorize(@amount, @credit_card, @options.merge({ capture_delay_hours: 4 }))
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 4, JSON.parse(data)['captureDelayHours']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_custom_routing_sent
  #   stub_comms do
  #     @gateway.authorize(@amount, @credit_card, @options.merge({ custom_routing_flag: 'abcdefg' }))
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'abcdefg', JSON.parse(data)['additionalData']['customRoutingFlag']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_splits_sent
  #   split_data = [{
  #     'amount' => {
  #       'currency' => 'USD',
  #       'value' => 50
  #     },
  #     'type' => 'MarketPlace',
  #     'account' => '163298747',
  #     'reference' => 'QXhlbFN0b2x0ZW5iZXJnCg'
  #   }, {
  #     'amount' => {
  #       'currency' => 'USD',
  #       'value' => 50
  #     },
  #     'type' => 'Commission',
  #     'reference' => 'THVjYXNCbGVkc29lCg'
  #   }]

  #   options = @options.merge({ splits: split_data })
  #   stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal split_data, JSON.parse(data)['splits']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_execute_threed_false_with_additional_data
  #   stub_comms do
  #     @gateway.authorize(@amount, @credit_card, @options.merge({ execute_threed: false, overwrite_brand: true, selected_brand: 'maestro' }))
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_match(/"additionalData":{"overwriteBrand":true,"executeThreeD":false}/, data)
  #     assert_match(/"selectedBrand":"maestro"/, data)
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_execute_threed_false_sent_3ds2
  #   stub_comms do
  #     @gateway.authorize(@amount, '123', @normalized_3ds_2_options.merge({ execute_threed: false }))
  #   end.check_request do |_endpoint, data, _headers|
  #     refute JSON.parse(data)['additionalData']['scaExemption']
  #     assert_false JSON.parse(data)['additionalData']['executeThreeD']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_sca_exemption_not_sent_if_execute_threed_missing_3ds2
  #   stub_comms do
  #     @gateway.authorize(@amount, '123', @normalized_3ds_2_options.merge({ scaExemption: 'lowValue' }))
  #   end.check_request do |_endpoint, data, _headers|
  #     refute JSON.parse(data)['additionalData']['scaExemption']
  #     refute JSON.parse(data)['additionalData']['executeThreeD']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_sca_exemption_and_execute_threed_false_sent_3ds2
  #   stub_comms do
  #     @gateway.authorize(@amount, '123', @normalized_3ds_2_options.merge({ sca_exemption: 'lowValue', execute_threed: false }))
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'lowValue', JSON.parse(data)['additionalData']['scaExemption']
  #     assert_false JSON.parse(data)['additionalData']['executeThreeD']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_sca_exemption_and_execute_threed_true_sent_3ds2
  #   stub_comms do
  #     @gateway.authorize(@amount, '123', @normalized_3ds_2_options.merge({ sca_exemption: 'lowValue', execute_threed: true }))
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'lowValue', JSON.parse(data)['additionalData']['scaExemption']
  #     assert JSON.parse(data)['additionalData']['executeThreeD']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_sca_exemption_not_sent_when_execute_threed_true_3ds1
  #   stub_comms do
  #     @gateway.authorize(@amount, '123', @options.merge({ sca_exemption: 'lowValue', execute_threed: true }))
  #   end.check_request do |_endpoint, data, _headers|
  #     refute JSON.parse(data)['additionalData']['scaExemption']
  #     assert JSON.parse(data)['additionalData']['executeThreeD']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_sca_exemption_not_sent_when_execute_threed_false_3ds1
  #   stub_comms do
  #     @gateway.authorize(@amount, '123', @options.merge({ sca_exemption: 'lowValue', execute_threed: false }))
  #   end.check_request do |_endpoint, data, _headers|
  #     refute JSON.parse(data)['additionalData']['scaExemption']
  #     refute JSON.parse(data)['additionalData']['executeThreeD']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_update_shopper_statement_and_industry_usage_sent
  #   stub_comms do
  #     @gateway.adjust(@amount, '123', @options.merge({ update_shopper_statement: 'statement note', industry_usage: 'DelayedCharge' }))
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'statement note', JSON.parse(data)['additionalData']['updateShopperStatement']
  #     assert_equal 'DelayedCharge', JSON.parse(data)['additionalData']['industryUsage']
  #   end.respond_with(successful_adjust_response)
  # end

  # def test_risk_data_sent
  #   stub_comms do
  #     @gateway.authorize(@amount, @credit_card, @options.merge({ risk_data: { 'operatingSystem' => 'HAL9000' } }))
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'HAL9000', JSON.parse(data)['additionalData']['riskdata.operatingSystem']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_risk_data_complex_data
  #   stub_comms do
  #     risk_data = {
  #       'deliveryMethod' => 'express',
  #       'basket.item.productTitle' => 'Blue T Shirt',
  #       'promotions.promotion.promotionName' => 'Big Sale promotion'
  #     }
  #     @gateway.authorize(@amount, @credit_card, @options.merge({ risk_data: risk_data }))
  #   end.check_request do |_endpoint, data, _headers|
  #     parsed = JSON.parse(data)
  #     assert_equal 'express', parsed['additionalData']['riskdata.deliveryMethod']
  #     assert_equal 'Blue T Shirt', parsed['additionalData']['riskdata.basket.item.productTitle']
  #     assert_equal 'Big Sale promotion', parsed['additionalData']['riskdata.promotions.promotion.promotionName']
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_stored_credential_recurring_cit_initial
  #   options = stored_credential_options(:cardholder, :recurring, :initial)
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_match(/"shopperInteraction":"Ecommerce"/, data)
  #     assert_match(/"recurringProcessingModel":"Subscription"/, data)
  #   end.respond_with(successful_authorize_response)

  #   assert_success response
  # end

  # def test_stored_credential_recurring_cit_used
  #   @credit_card.verification_value = nil
  #   options = stored_credential_options(:cardholder, :recurring, ntid: 'abc123')
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_match(/"shopperInteraction":"ContAuth"/, data)
  #     assert_match(/"recurringProcessingModel":"Subscription"/, data)
  #   end.respond_with(successful_authorize_response)

  #   assert_success response
  # end

  # def test_stored_credential_recurring_mit_initial
  #   options = stored_credential_options(:merchant, :recurring, :initial)
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_match(/"shopperInteraction":"ContAuth"/, data)
  #     assert_match(/"recurringProcessingModel":"Subscription"/, data)
  #   end.respond_with(successful_authorize_response)

  #   assert_success response
  # end

  # def test_stored_credential_recurring_mit_used
  #   @credit_card.verification_value = nil
  #   options = stored_credential_options(:merchant, :recurring, ntid: 'abc123')
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_match(/"shopperInteraction":"ContAuth"/, data)
  #     assert_match(/"recurringProcessingModel":"Subscription"/, data)
  #   end.respond_with(successful_authorize_response)

  #   assert_success response
  # end

  # def test_stored_credential_unscheduled_cit_initial
  #   options = stored_credential_options(:cardholder, :unscheduled, :initial)
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_match(/"shopperInteraction":"Ecommerce"/, data)
  #     assert_match(/"recurringProcessingModel":"CardOnFile"/, data)
  #   end.respond_with(successful_authorize_response)

  #   assert_success response
  # end

  # def test_stored_credential_unscheduled_cit_used
  #   @credit_card.verification_value = nil
  #   options = stored_credential_options(:cardholder, :unscheduled, ntid: 'abc123')
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_match(/"shopperInteraction":"ContAuth"/, data)
  #     assert_match(/"recurringProcessingModel":"CardOnFile"/, data)
  #   end.respond_with(successful_authorize_response)

  #   assert_success response
  # end

  # def test_stored_credential_unscheduled_mit_initial
  #   options = stored_credential_options(:merchant, :unscheduled, :initial)
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_match(/"shopperInteraction":"ContAuth"/, data)
  #     assert_match(/"recurringProcessingModel":"UnscheduledCardOnFile"/, data)
  #   end.respond_with(successful_authorize_response)

  #   assert_success response
  # end

  # def test_stored_credential_unscheduled_mit_used
  #   @credit_card.verification_value = nil
  #   options = stored_credential_options(:merchant, :unscheduled, ntid: 'abc123')
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_match(/"shopperInteraction":"ContAuth"/, data)
  #     assert_match(/"recurringProcessingModel":"UnscheduledCardOnFile"/, data)
  #   end.respond_with(successful_authorize_response)

  #   assert_success response
  # end

  # def test_nonfractional_currency_handling
  #   stub_comms do
  #     @gateway.authorize(200, @credit_card, @options.merge(currency: 'JPY'))
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_match(/"amount\":{\"value\":\"2\",\"currency\":\"JPY\"}/, data)
  #   end.respond_with(successful_authorize_response)

  #   stub_comms do
  #     @gateway.authorize(200, @credit_card, @options.merge(currency: 'CLP'))
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_match(/"amount\":{\"value\":\"200\",\"currency\":\"CLP\"}/, data)
  #   end.respond_with(successful_authorize_response)
  # end

  # def test_failed_purchase
  #   @gateway.expects(:ssl_post).returns(failed_purchase_response)

  #   response = @gateway.purchase(@amount, credit_card('400111'), @options)
  #   assert_failure response

  #   assert_equal AdyenGateway::STANDARD_ERROR_CODE[:incorrect_number], response.error_code
  # end

  # def test_successful_refund
  #   @gateway.expects(:ssl_post).returns(successful_refund_response)
  #   response = @gateway.refund(@amount, '7914775043909934')
  #   assert_equal '7914775043909934#8514775559925128#', response.authorization
  #   assert_equal '[refund-received]', response.message
  #   assert response.test?
  # end

  # def test_successful_refund_with_compound_psp_reference
  #   @gateway.expects(:ssl_post).returns(successful_refund_response)
  #   response = @gateway.refund(@amount, '7914775043909934#8514775559000000')
  #   assert_equal '7914775043909934#8514775559925128#', response.authorization
  #   assert_equal '[refund-received]', response.message
  #   assert response.test?
  # end

  # def test_failed_refund
  #   @gateway.expects(:ssl_post).returns(failed_refund_response)
  #   response = @gateway.refund(@amount, '')
  #   assert_nil response.authorization
  #   assert_equal 'Original pspReference required for this operation', response.message
  #   assert_failure response
  # end

  # def test_failed_credit
  #   @gateway.expects(:ssl_post).returns(failed_credit_response)
  #   response = @gateway.refund(@amount, '')
  #   assert_nil response.authorization
  #   assert_equal "Required field 'reference' is not provided.", response.message
  #   assert_failure response
  # end

  # def test_successful_credit
  #   @gateway.expects(:ssl_post).returns(successful_credit_response)
  #   response = @gateway.credit(@amount, '883614109029400G')
  #   assert_equal '#883614109029400G#', response.authorization
  #   assert_equal 'Received', response.message
  #   assert_success response
  # end

  # def test_successful_void
  #   @gateway.expects(:ssl_post).returns(successful_void_response)
  #   response = @gateway.void('7914775043909934')
  #   assert_equal '7914775043909934#8614775821628806#', response.authorization
  #   assert_equal '[cancel-received]', response.message
  #   assert response.test?
  # end

  # def test_successful_cancel_or_refund
  #   @gateway.expects(:ssl_post).returns(successful_cancel_or_refund_response)
  #   response = @gateway.void('7914775043909934')
  #   assert_equal '7914775043909934#8614775821628806#', response.authorization
  #   assert_equal '[cancelOrRefund-received]', response.message
  #   assert response.test?
  # end

  # def test_failed_void
  #   @gateway.expects(:ssl_post).returns(failed_void_response)
  #   response = @gateway.void('')
  #   assert_equal 'Original pspReference required for this operation', response.message
  #   assert_failure response
  # end

  # def test_successful_adjust
  #   @gateway.expects(:ssl_post).returns(successful_adjust_response)
  #   response = @gateway.adjust(200, '8835544088660594')
  #   assert_equal '8835544088660594#8835544088660594#', response.authorization
  #   assert_equal '[adjustAuthorisation-received]', response.message
  # end

  # def test_failed_adjust
  #   @gateway.expects(:ssl_post).returns(failed_adjust_response)
  #   response = @gateway.adjust(200, '')
  #   assert_equal 'Original pspReference required for this operation', response.message
  #   assert_failure response
  # end

  # def test_successful_synchronous_adjust
  #   @gateway.expects(:ssl_post).returns(successful_synchronous_adjust_response)
  #   response = @gateway.adjust(200, '8835544088660594')
  #   assert_equal '8835544088660594#8835574118820108#', response.authorization
  #   assert_equal 'Authorised', response.message
  # end

  # def test_failed_synchronous_adjust
  #   @gateway.expects(:ssl_post).returns(failed_synchronous_adjust_response)
  #   response = @gateway.adjust(200, '8835544088660594')
  #   assert_equal 'Refused', response.message
  #   assert_failure response
  # end

  # def test_successful_tokenize_only_store
  #   response = stub_comms do
  #     @gateway.store(@credit_card, @options.merge({ tokenize_only: true }))
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'CardOnFile', JSON.parse(data)['recurringProcessingModel']
  #   end.respond_with(successful_store_response)
  #   assert_equal '#8835205392522157#', response.authorization
  # end

  # def test_successful_store
  #   response = stub_comms do
  #     @gateway.store(@credit_card, @options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'CardOnFile', JSON.parse(data)['recurringProcessingModel']
  #   end.respond_with(successful_store_response)
  #   assert_success response
  #   assert_equal '#8835205392522157#8315202663743702', response.authorization
  # end

  # def test_successful_store_with_bank_account
  #   response = stub_comms do
  #     @gateway.store(@bank_account, @options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'CardOnFile', JSON.parse(data)['recurringProcessingModel']
  #   end.respond_with(successful_store_response)
  #   assert_success response
  #   assert_equal '#8835205392522157#8315202663743702', response.authorization
  # end

  # def test_successful_store_with_recurring_contract_type
  #   stub_comms do
  #     @gateway.store(@credit_card, @options.merge({ recurring_contract_type: 'ONECLICK' }))
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'ONECLICK', JSON.parse(data)['recurring']['contract']
  #   end.respond_with(successful_store_response)
  # end

  # def test_recurring_contract_type_set_for_reference_purchase
  #   stub_comms do
  #     @gateway.store('123', @options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'RECURRING', JSON.parse(data)['recurring']['contract']
  #   end.respond_with(successful_store_response)
  # end

  # def test_failed_store
  #   @gateway.expects(:ssl_post).returns(failed_store_response)
  #   response = @gateway.store(@credit_card, @options)
  #   assert_failure response
  #   assert_equal 'Refused', response.message
  # end

  # def test_successful_unstore
  #   response = stub_comms do
  #     @gateway.unstore(shopper_reference: 'shopper_reference',
  #                      recurring_detail_reference: 'detail_reference')
  #   end.respond_with(successful_unstore_response)
  #   assert_success response
  #   assert_equal '[detail-successfully-disabled]', response.message
  # end

  # def test_failed_unstore
  #   @gateway.expects(:ssl_post).returns(failed_unstore_response)
  #   response = @gateway.unstore(shopper_reference: 'random_reference',
  #                               recurring_detail_reference: 'detail_reference')
  #   assert_failure response
  #   assert_equal 'Contract not found', response.message
  # end

  # def test_successful_verify
  #   response = stub_comms do
  #     @gateway.verify(@credit_card, @options)
  #   end.respond_with(successful_verify_response)
  #   assert_success response
  #   assert_equal '#7914776426645103#', response.authorization
  #   assert_equal 'Authorised', response.message
  #   assert response.test?
  # end

  # def test_successful_verify_with_bank_account
  #   response = stub_comms do
  #     @gateway.verify(@bank_account, @options)
  #   end.respond_with(successful_verify_response)
  #   assert_success response
  #   assert_equal '#7914776426645103#', response.authorization
  #   assert_equal 'Authorised', response.message
  #   assert response.test?
  # end

  # def test_failed_verify
  #   response = stub_comms do
  #     @gateway.verify(@credit_card, @options)
  #   end.respond_with(failed_verify_response)
  #   assert_failure response
  #   assert_equal '#7914776433387947#', response.authorization
  #   assert_equal 'Refused', response.message
  #   assert response.test?
  # end

  # def test_failed_verify_with_bank_account
  #   response = stub_comms do
  #     @gateway.verify(@bank_account, @options)
  #   end.respond_with(failed_verify_response)
  #   assert_failure response
  #   assert_equal '#7914776433387947#', response.authorization
  #   assert_equal 'Refused', response.message
  #   assert response.test?
  # end

  # def test_failed_avs_check_returns_refusal_reason_raw
  #   @gateway.expects(:ssl_post).returns(failed_authorize_avs_response)

  #   response = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_failure response
  #   assert_equal 'Refused | 05 : Do not honor', response.message
  # end

  # def test_scrub
  #   assert @gateway.supports_scrubbing?
  #   assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  # end

  # def test_scrub_bank_account
  #   assert @gateway.supports_scrubbing?
  #   assert_equal @gateway.scrub(pre_scrubbed_bank_account), post_scrubbed_bank_account
  # end

  # def test_scrub_network_tokenization_card
  #   assert @gateway.supports_scrubbing?
  #   assert_equal @gateway.scrub(pre_scrubbed_network_tokenization_card), post_scrubbed_network_tokenization_card
  # end

  # def test_shopper_data
  #   post = { card: { billingAddress: {} } }
  #   @gateway.send(:add_shopper_data, post, @options)
  #   assert_equal 'john.smith@test.com', post[:shopperEmail]
  #   assert_equal '77.110.174.153', post[:shopperIP]
  # end

  # def test_shopper_data_backwards_compatibility
  #   post = { card: { billingAddress: {} } }
  #   @gateway.send(:add_shopper_data, post, @options_shopper_data)
  #   assert_equal 'john2.smith@test.com', post[:shopperEmail]
  #   assert_equal '192.168.100.100', post[:shopperIP]
  # end

  # def test_add_address
  #   post = { card: { billingAddress: {} } }
  #   @options[:billing_address].delete(:address1)
  #   @options[:billing_address].delete(:address2)
  #   @options[:billing_address].delete(:state)
  #   @options[:shipping_address].delete(:state)
  #   @gateway.send(:add_address, post, @options)
  #   # Billing Address
  #   assert_equal 'NA', post[:billingAddress][:street]
  #   assert_equal 'NA', post[:billingAddress][:houseNumberOrName]
  #   assert_equal 'NA', post[:billingAddress][:stateOrProvince]
  #   assert_equal @options[:billing_address][:zip], post[:billingAddress][:postalCode]
  #   assert_equal @options[:billing_address][:city], post[:billingAddress][:city]
  #   assert_equal @options[:billing_address][:country], post[:billingAddress][:country]
  #   # Shipping Address
  #   assert_equal 'NA', post[:deliveryAddress][:stateOrProvince]
  #   assert_equal @options[:shipping_address][:address1], post[:deliveryAddress][:street]
  #   assert_equal @options[:shipping_address][:address2], post[:deliveryAddress][:houseNumberOrName]
  #   assert_equal @options[:shipping_address][:zip], post[:deliveryAddress][:postalCode]
  #   assert_equal @options[:shipping_address][:city], post[:deliveryAddress][:city]
  #   assert_equal @options[:shipping_address][:country], post[:deliveryAddress][:country]
  # end

  # def test_successful_auth_phone
  #   options = @options.merge(billing_address: { phone: 1234567890 })
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 1234567890, JSON.parse(data)['telephoneNumber']
  #   end.respond_with(successful_authorize_response)
  #   assert_success response
  # end

  # def test_successful_auth_phone_number
  #   options = @options.merge(billing_address: { phone_number: 987654321, phone: 1234567890 })
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 987654321, JSON.parse(data)['telephoneNumber']
  #   end.respond_with(successful_authorize_response)
  #   assert_success response
  # end

  # def test_successful_auth_application_info
  #   ActiveMerchant::Billing::AdyenGateway.application_id = { name: 'Acme', version: '1.0' }

  #   options = @options.merge!(
  #     merchantApplication: {
  #       name: 'Acme Inc.',
  #       version: '2'
  #     }
  #   )
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'Acme', JSON.parse(data)['applicationInfo']['externalPlatform']['name']
  #     assert_equal '1.0', JSON.parse(data)['applicationInfo']['externalPlatform']['version']
  #     assert_equal 'Acme Inc.', JSON.parse(data)['applicationInfo']['merchantApplication']['name']
  #     assert_equal '2', JSON.parse(data)['applicationInfo']['merchantApplication']['version']
  #   end.respond_with(successful_authorize_response)
  #   assert_success response
  # end

  # def test_purchase_with_long_order_id
  #   options = @options.merge({ order_id: @long_order_id })
  #   response = stub_comms do
  #     @gateway.purchase(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal @long_order_id[0..79], JSON.parse(data)['reference']
  #   end.respond_with(successful_authorize_response, successful_capture_response)
  #   assert_success response
  # end

  # def test_authorize_with_credit_card_no_name
  #   credit_card_no_name = ActiveMerchant::Billing::CreditCard.new({
  #     number: '4111111111111111',
  #     month: 3,
  #     year: 2030,
  #     verification_value: '737',
  #     brand: 'visa'
  #   })

  #   response = stub_comms do
  #     @gateway.authorize(@amount, credit_card_no_name, @options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'Not Provided', JSON.parse(data)['card']['holderName']
  #   end.respond_with(successful_authorize_response)
  #   assert_success response
  # end

  # def test_authorize_with_network_tokenization_credit_card_no_name
  #   @apple_pay_card.first_name = nil
  #   @apple_pay_card.last_name = nil
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @apple_pay_card, @options)
  #   end.check_request do |_endpoint, data, _headers|
  #     assert_equal 'Not Provided', JSON.parse(data)['card']['holderName']
  #   end.respond_with(successful_authorize_response)
  #   assert_success response
  # end

  # def test_authorize_with_network_tokenization_credit_card
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @apple_pay_card, @options)
  #   end.check_request do |_endpoint, data, _headers|
  #     parsed = JSON.parse(data)
  #     assert_equal 'YwAAAAAABaYcCMX/OhNRQAAAAAA=', parsed['mpiData']['cavv']
  #     assert_equal '07', parsed['mpiData']['eci']
  #     assert_equal 'applepay', parsed['additionalData']['paymentdatasource.type']
  #   end.respond_with(successful_authorize_response)
  #   assert_success response
  # end

  # def test_authorize_and_capture_with_network_transaction_id
  #   auth = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, @options)
  #   end.respond_with(successful_authorize_response_with_network_tx_ref)
  #   assert_equal auth.network_transaction_id, '858435661128555'

  #   response = stub_comms do
  #     @gateway.capture(@amount, auth.authorization, @options.merge(network_transaction_id: auth.network_transaction_id))
  #   end.check_request do |_, data, _|
  #     assert_match(/"networkTxReference":"#{auth.network_transaction_id}"/, data)
  #   end.respond_with(successful_capture_response)
  #   assert_success response
  # end

  # def test_authorize_and_capture_with_network_transaction_id_from_stored_cred_hash
  #   auth = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, @options)
  #   end.respond_with(successful_authorize_response_with_network_tx_ref)
  #   assert_equal auth.network_transaction_id, '858435661128555'

  #   response = stub_comms do
  #     @gateway.capture(@amount, auth.authorization, @options.merge(stored_credential: { network_transaction_id: auth.network_transaction_id }))
  #   end.check_request do |_, data, _|
  #     assert_match(/"networkTxReference":"#{auth.network_transaction_id}"/, data)
  #   end.respond_with(successful_capture_response)
  #   assert_success response
  # end

  # def test_authorize_with_network_token
  #   @gateway.expects(:ssl_post).returns(successful_authorize_response)

  #   response = @gateway.authorize(@amount, @nt_credit_card, @options)
  #   assert_success response
  # end

  # def test_successful_purchase_with_network_token
  #   response = stub_comms do
  #     @gateway.purchase(@amount, @nt_credit_card, @options)
  #   end.respond_with(successful_authorize_response, successful_capture_response)
  #   assert_success response
  # end

  # def test_supports_network_tokenization
  #   assert_instance_of TrueClass, @gateway.supports_network_tokenization?
  # end

  # def test_authorize_with_sub_merchant_id
  #   sub_merchant_data = {
  #     sub_merchant_id: '123451234512345',
  #     sub_merchant_name: 'Wildsea',
  #     sub_merchant_street: '1234 Street St',
  #     sub_merchant_city: 'Night City',
  #     sub_merchant_state: 'East Block',
  #     sub_merchant_postal_code: '112233',
  #     sub_merchant_country: 'EUR',
  #     sub_merchant_tax_id: '12345abcde67',
  #     sub_merchant_mcc: '1234'
  #   }
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, @options.merge(sub_merchant_data))
  #   end.check_request do |_endpoint, data, _headers|
  #     parsed = JSON.parse(data)
  #     assert parsed['additionalData']['subMerchantID']
  #     assert parsed['additionalData']['subMerchantName']
  #     assert parsed['additionalData']['subMerchantStreet']
  #     assert parsed['additionalData']['subMerchantCity']
  #     assert parsed['additionalData']['subMerchantState']
  #     assert parsed['additionalData']['subMerchantPostalCode']
  #     assert parsed['additionalData']['subMerchantCountry']
  #     assert parsed['additionalData']['subMerchantTaxId']
  #   end.respond_with(successful_authorize_response)
  #   assert_success response
  # end

  # def test_authorize_with_sub_sellers
  #   sub_seller_options = {
  #     "subMerchant.numberOfSubSellers": '2',
  #     "subMerchant.subSeller1.id": '111111111',
  #     "subMerchant.subSeller1.name": 'testSub1',
  #     "subMerchant.subSeller1.street": 'Street1',
  #     "subMerchant.subSeller1.postalCode": '12242840',
  #     "subMerchant.subSeller1.city": 'Sao jose dos campos',
  #     "subMerchant.subSeller1.state": 'SP',
  #     "subMerchant.subSeller1.country": 'BRA',
  #     "subMerchant.subSeller1.taxId": '12312312340',
  #     "subMerchant.subSeller1.mcc": '5691',
  #     "subMerchant.subSeller1.debitSettlementBank": '1',
  #     "subMerchant.subSeller1.debitSettlementAgency": '1',
  #     "subMerchant.subSeller1.debitSettlementAccountType": '1',
  #     "subMerchant.subSeller1.debitSettlementAccount": '1',
  #     "subMerchant.subSeller1.creditSettlementBank": '1',
  #     "subMerchant.subSeller1.creditSettlementAgency": '1',
  #     "subMerchant.subSeller1.creditSettlementAccountType": '1',
  #     "subMerchant.subSeller1.creditSettlementAccount": '1',
  #     "subMerchant.subSeller2.id": '22222222',
  #     "subMerchant.subSeller2.name": 'testSub2',
  #     "subMerchant.subSeller2.street": 'Street2',
  #     "subMerchant.subSeller2.postalCode": '12300000',
  #     "subMerchant.subSeller2.city": 'Jacarei',
  #     "subMerchant.subSeller2.state": 'SP',
  #     "subMerchant.subSeller2.country": 'BRA',
  #     "subMerchant.subSeller2.taxId": '12312312340',
  #     "subMerchant.subSeller2.mcc": '5691',
  #     "subMerchant.subSeller2.debitSettlementBank": '1',
  #     "subMerchant.subSeller2.debitSettlementAgency": '1',
  #     "subMerchant.subSeller2.debitSettlementAccountType": '1',
  #     "subMerchant.subSeller2.debitSettlementAccount": '1',
  #     "subMerchant.subSeller2.creditSettlementBank": '1',
  #     "subMerchant.subSeller2.creditSettlementAgency": '1',
  #     "subMerchant.subSeller2.creditSettlementAccountType": '1',
  #     "subMerchant.subSeller2.creditSettlementAccount": '1'
  #   }
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, @options.merge(sub_merchant_data: sub_seller_options))
  #   end.check_request do |_endpoint, data, _headers|
  #     parsed = JSON.parse(data)
  #     additional_data = parsed['additionalData']
  #     assert additional_data['subMerchant.numberOfSubSellers']
  #     assert additional_data['subMerchant.subSeller1.id']
  #     assert additional_data['subMerchant.subSeller1.name']
  #     assert additional_data['subMerchant.subSeller1.street']
  #     assert additional_data['subMerchant.subSeller1.city']
  #     assert additional_data['subMerchant.subSeller1.state']
  #     assert additional_data['subMerchant.subSeller1.postalCode']
  #     assert additional_data['subMerchant.subSeller1.country']
  #     assert additional_data['subMerchant.subSeller1.taxId']
  #     assert additional_data['subMerchant.subSeller1.debitSettlementBank']
  #     assert additional_data['subMerchant.subSeller1.debitSettlementAgency']
  #     assert additional_data['subMerchant.subSeller1.debitSettlementAccountType']
  #     assert additional_data['subMerchant.subSeller1.debitSettlementAccount']
  #     assert additional_data['subMerchant.subSeller1.creditSettlementBank']
  #     assert additional_data['subMerchant.subSeller1.creditSettlementAgency']
  #     assert additional_data['subMerchant.subSeller1.creditSettlementAccountType']
  #     assert additional_data['subMerchant.subSeller1.creditSettlementAccount']
  #     assert additional_data['subMerchant.subSeller2.id']
  #     assert additional_data['subMerchant.subSeller2.name']
  #     assert additional_data['subMerchant.subSeller2.street']
  #     assert additional_data['subMerchant.subSeller2.city']
  #     assert additional_data['subMerchant.subSeller2.state']
  #     assert additional_data['subMerchant.subSeller2.postalCode']
  #     assert additional_data['subMerchant.subSeller2.country']
  #     assert additional_data['subMerchant.subSeller2.taxId']
  #     assert additional_data['subMerchant.subSeller2.debitSettlementBank']
  #     assert additional_data['subMerchant.subSeller2.debitSettlementAgency']
  #     assert additional_data['subMerchant.subSeller2.debitSettlementAccountType']
  #     assert additional_data['subMerchant.subSeller2.debitSettlementAccount']
  #     assert additional_data['subMerchant.subSeller2.creditSettlementBank']
  #     assert additional_data['subMerchant.subSeller2.creditSettlementAgency']
  #     assert additional_data['subMerchant.subSeller2.creditSettlementAccountType']
  #     assert additional_data['subMerchant.subSeller2.creditSettlementAccount']
  #   end.respond_with(successful_authorize_response)
  #   assert_success response
  # end

  # def test_extended_avs_response
  #   response = stub_comms do
  #     @gateway.verify(@credit_card, @options)
  #   end.respond_with(extended_avs_response)
  #   assert_equal 'Card member\'s name, billing address, and billing postal code match.', response.avs_result['message']
  # end

  # def test_optional_idempotency_key_header
  #   options = @options.merge(idempotency_key: 'test123')
  #   response = stub_comms do
  #     @gateway.authorize(@amount, @credit_card, options)
  #   end.check_request do |_endpoint, _data, headers|
  #     assert headers['Idempotency-Key']
  #   end.respond_with(successful_authorize_response)
  #   assert_success response
  # end

  # def test_three_decimal_places_currency_handling
  #   stub_comms do
  #     @gateway.authorize(1000, @credit_card, @options.merge(currency: 'JOD'))
  #   end.check_request(skip_response: true) do |_endpoint, data|
  #     assert_match(/"amount\":{\"value\":\"1000\",\"currency\":\"JOD\"}/, data)
  #   end
  # end

  private

  def expect_session
    @gateway.expects(:ssl_post)
      .with("https://ppp-test.safecharge.com/ppp/api/v1/getSessionToken.do", anything, anything)
      .returns(successful_session_create_response)
  end
  
  def successful_session_create_response
    <<-RESPONSE
    {
      "sessionToken": "7c42f3a1-a399-4ba9-866e-0f04c651181b",
      "internalRequestId": 410054338,
      "status": "SUCCESS",
      "errCode": 0,
      "reason": "",
      "merchantId": "12345",
      "merchantSiteId": "67890",
      "version": "1.0"
    }
    RESPONSE
  end

  def successful_payment_request
    <<-RESPONSE
    {
      "sessionToken": "0e762388-201b-4076-99a9-b2bda3007c0c",
      "merchantId": "12345",
      "merchantSiteId": "67890",
      "clientRequestId": "",
      "amount": "100",
      "currency": "USD",
      "userTokenId": "230811147",
      "clientUniqueId": "1",
      "paymentOption": {
        "card": {
          "cardNumber": "",
          "cardHolderName": "John Smith",
          "expirationMonth": "12",
          "expirationYear": "2022",
          "CVV": "217"
        }
      },
      "deviceDetails": {
        "ipAddress": "127.0.0.1"
      },
      "billingAddress": {
        "email": "john.smith@email.com",
        "country": "US"
      },
      "timeStamp": "20220311110525",
      "checksum": "e297e3bd87c11984d2c569cb4bb7cedfcc3f8ca93aadeacb90abea267bd1f93f"
    }
    RESPONSE
  end

  def successful_initPayment_response
    <<-RESPONSE
    {
      "orderId": "308576688",
      "userTokenId": "230811147",
      "transactionId": "711000000008956041",
      "transactionType": "InitAuth3D",
      "transactionStatus": "APPROVED",
      "gwErrorCode": 0,
      "gwExtendedErrorCode": 0,
      "paymentOption": {
                         "card": {
                                   "ccCardNumber": "4****1111",
                                  "bin": "411111",
                                  "last4Digits": "1111",
                                  "ccExpMonth": "12",
                                  "ccExpYear": "50",
                                  "acquirerId": "19",
                                  "threeD": {
                                              "methodUrl": "",
                                             "version": "",
                                             "v2supported": "false",
                                             "methodPayload": "",
                                             "serverTransId": ""
                                            }
                                 }
                       },
      "customData": "",
      "sessionToken": "b85bc330-21bd-4569-8d76-e6cc08ef07e3",
      "clientUniqueId": "12345",
      "internalRequestId": 410795948,
      "status": "SUCCESS",
      "errCode": 0,
      "reason": "",
      "merchantId": "4318971784049510026",
      "merchantSiteId": "231008",
      "version": "1.0",
      "clientRequestId": "17128"
    }
    RESPONSE
  end
  
  def declined_payment_request
    <<-RESPONSE
    {
      "orderId": "308575998",
      "userTokenId": "230811147",
      "paymentOption": {
        "userPaymentOptionId": "74265028",
        "card": {
          "ccCardNumber": "4****4242",
          "bin": "424242",
          "last4Digits": "4242",
          "ccExpMonth": "12",
          "ccExpYear": "50",
          "acquirerId": "19",
          "cvv2Reply": "",
          "avsCode": "",
          "cardBrand": "VISA",
          "issuerBankName": "",
          "isPrepaid": "false",
          "threeD": {}
        }
      },
      "transactionStatus": "DECLINED",
      "gwErrorCode": -1,
      "gwErrorReason": "Decline",
      "gwExtendedErrorCode": 0,
      "transactionType": "Sale",
      "transactionId": "711000000008955382",
      "externalTransactionId": "",
      "authCode": "",
      "customData": "",
      "fraudDetails": {
        "finalDecision": "Accept"
      },
      "externalSchemeTransactionId": "",
      "sessionToken": "4d98b92a-0687-44c5-a5f8-e9d76adf333b",
      "clientUniqueId": "12345",
      "internalRequestId": 410783398,
      "status": "SUCCESS",
      "errCode": 0,
      "reason": "",
      "merchantId": "4318971784049510026",
      "merchantSiteId": "231008",
      "version": "1.0",
      "clientRequestId": "1"
    }
    RESPONSE
  end
end
