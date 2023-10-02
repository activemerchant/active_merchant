require 'test_helper'

class AdyenTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = AdyenGateway.new(
      username: 'ws@adyenmerchant.com',
      password: 'password',
      merchant_account: 'merchantAccount'
    )

    @bank_account = check()

    @credit_card = credit_card(
      '4111111111111111',
      month: 8,
      year: 2018,
      first_name: 'Test',
      last_name: 'Card',
      verification_value: '737',
      brand: 'visa'
    )

    @elo_credit_card = credit_card(
      '5066 9911 1111 1118',
      month: 10,
      year: 2020,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'elo'
    )

    @cabal_credit_card = credit_card(
      '6035 2277 1642 7021',
      month: 10,
      year: 2020,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'cabal'
    )

    @unionpay_credit_card = credit_card(
      '8171 9999 0000 0000 021',
      month: 10,
      year: 2030,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'unionpay'
    )

    @three_ds_enrolled_card = credit_card('4212345678901237', brand: :visa)

    @apple_pay_card = network_tokenization_credit_card(
      '4111111111111111',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '08',
      year: '2018',
      source: :apple_pay,
      verification_value: nil
    )

    @nt_credit_card = network_tokenization_credit_card(
      '4895370015293175',
      brand: 'visa',
      eci: '07',
      source: :network_token,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )

    @amount = 100

    @options = {
      billing_address: address(),
      shipping_address: address(),
      shopper_reference: 'John Smith',
      order_id: '345123',
      installments: 2,
      stored_credential: { reason_type: 'unscheduled' },
      email: 'john.smith@test.com',
      ip: '77.110.174.153'
    }

    @options_shopper_data = {
      email: 'john.smith@test.com',
      ip: '77.110.174.153',
      shopper_email: 'john2.smith@test.com',
      shopper_ip: '192.168.100.100'
    }

    @normalized_3ds_2_options = {
      reference: '345123',
      email: 'john.smith@test.com',
      ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: address(),
      order_id: '123',
      stored_credential: { reason_type: 'unscheduled' },
      three_ds_2: {
        channel: 'browser',
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
    }

    @long_order_id = 'asdfjkl;asdfjkl;asdfj;aiwyutinvpoaieryutnmv;203987528752098375j3q-p489756ijmfpvbijpq348nmdf;vbjp3845'
  end

  # Subdomains are only valid for production gateways, so the test_url check must be manually bypassed for this test to pass.
  # def test_subdomain_specification
  #   gateway = AdyenGateway.new(
  #     username: 'ws@adyenmerchant.com',
  #     password: 'password',
  #     merchant_account: 'merchantAccount',
  #     subdomain: '123-subdomain'
  #   )
  #
  #   response = stub_comms(gateway) do
  #     gateway.authorize(@amount, @credit_card, @options)
  #   end.check_request do |endpoint, data, headers|
  #     assert_match("https://123-subdomain-pal-live.adyenpayments.com/pal/servlet/Payment/v18/authorise", endpoint)
  #   end.respond_with(successful_authorize_response)
  #
  #   assert response
  #   assert_success response
  # end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '#7914775043909934#', response.authorization
    assert_equal 'R', response.avs_result['code']
    assert_equal 'M', response.cvv_result['code']
    assert response.test?
  end

  def test_successful_authorize_bank_account
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @bank_account, @options)
    assert_success response

    assert_equal '#7914775043909934#', response.authorization
    assert_equal 'R', response.avs_result['code']
    assert_equal 'M', response.cvv_result['code']
    assert response.test?
  end

  def test_successful_authorize_with_3ds
    @gateway.expects(:ssl_post).returns(successful_authorize_with_3ds_response)

    response = @gateway.authorize(@amount, @three_ds_enrolled_card, @options.merge(execute_threed: true))
    assert response.test?
    refute response.authorization.blank?
    assert_equal '#8835440446784145#', response.authorization
    assert_equal response.params['resultCode'], 'RedirectShopper'
    refute response.params['issuerUrl'].blank?
    refute response.params['md'].blank?
    refute response.params['paRequest'].blank?
  end

  def test_failed_authorize_with_unexpected_3ds
    @gateway.expects(:ssl_post).returns(successful_authorize_with_3ds_response)
    response = @gateway.authorize(@amount, @three_ds_enrolled_card, @options)
    assert_failure response
    assert_match 'Received unexpected 3DS authentication response, but a 3DS initiation flag was not included in the request.', response.message
  end

  def test_successful_authorize_with_recurring_contract_type
    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge({ recurring_contract_type: 'ONECLICK' }))
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'john.smith@test.com', JSON.parse(data)['shopperEmail']
      assert_equal 'ONECLICK', JSON.parse(data)['recurring']['contract']
    end.respond_with(successful_authorize_response)
  end

  def test_adds_3ds1_standalone_fields
    eci = '05'
    cavv = '3q2+78r+ur7erb7vyv66vv\/\/\/\/8='
    cavv_algorithm = '1'
    xid = 'ODUzNTYzOTcwODU5NzY3Qw=='
    enrolled = 'Y'
    authentication_response_status = 'Y'
    options_with_3ds1_standalone = @options.merge(
      three_d_secure: {
        eci: eci,
        cavv: cavv,
        cavv_algorithm: cavv_algorithm,
        xid: xid,
        enrolled: enrolled,
        authentication_response_status: authentication_response_status
      }
    )
    stub_comms do
      @gateway.authorize(@amount, @credit_card, options_with_3ds1_standalone)
    end.check_request do |_endpoint, data, _headers|
      assert_equal eci, JSON.parse(data)['mpiData']['eci']
      assert_equal cavv, JSON.parse(data)['mpiData']['cavv']
      assert_equal cavv_algorithm, JSON.parse(data)['mpiData']['cavvAlgorithm']
      assert_equal xid, JSON.parse(data)['mpiData']['xid']
      assert_equal enrolled, JSON.parse(data)['mpiData']['directoryResponse']
      assert_equal authentication_response_status, JSON.parse(data)['mpiData']['authenticationResponse']
    end.respond_with(successful_authorize_response)
  end

  def test_adds_3ds2_standalone_fields
    version = '2.1.0'
    eci = '02'
    cavv = 'jJ81HADVRtXfCBATEp01CJUAAAA='
    ds_transaction_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    directory_response_status = 'C'
    authentication_response_status = 'Y'
    options_with_3ds2_standalone = @options.merge(
      three_d_secure: {
        version: version,
        eci: eci,
        cavv: cavv,
        ds_transaction_id: ds_transaction_id,
        directory_response_status: directory_response_status,
        authentication_response_status: authentication_response_status
      }
    )
    stub_comms do
      @gateway.authorize(@amount, @credit_card, options_with_3ds2_standalone)
    end.check_request do |_endpoint, data, _headers|
      assert_equal version, JSON.parse(data)['mpiData']['threeDSVersion']
      assert_equal eci, JSON.parse(data)['mpiData']['eci']
      assert_equal cavv, JSON.parse(data)['mpiData']['cavv']
      assert_equal ds_transaction_id, JSON.parse(data)['mpiData']['dsTransID']
      assert_equal directory_response_status, JSON.parse(data)['mpiData']['directoryResponse']
      assert_equal authentication_response_status, JSON.parse(data)['mpiData']['authenticationResponse']
    end.respond_with(successful_authorize_response)
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'Expired Card', response.message
    assert_failure response
  end

  def test_standard_error_code_mapping
    @gateway.expects(:ssl_post).returns(failed_billing_field_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'incorrect_address', response.error_code
  end

  def test_unknown_error_code_mapping
    @gateway.expects(:ssl_post).returns(failed_invalid_delivery_field_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '702', response.error_code
  end

  def test_billing_address_error_code_mapping
    @gateway.expects(:ssl_post).returns(failed_billing_address_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal AdyenGateway::STANDARD_ERROR_CODE[:incorrect_address], response.error_code
  end

  def test_cvc_length_error_code_mapping
    @gateway.expects(:ssl_post).returns(failed_cvc_validation_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal AdyenGateway::STANDARD_ERROR_CODE[:invalid_cvc], response.error_code
  end

  def test_invalid_card_number_error_code_mapping
    @gateway.expects(:ssl_post).returns(failed_invalid_card_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal AdyenGateway::STANDARD_ERROR_CODE[:incorrect_number], response.error_code
  end

  def test_invalid_amount_error_code_mapping
    @gateway.expects(:ssl_post).returns(failed_invalid_amount_response)

    response = @gateway.authorize(nil, @credit_card, @options)
    assert_failure response
    assert_equal AdyenGateway::STANDARD_ERROR_CODE[:invalid_amount], response.error_code
  end

  def test_invalid_access_error_code_mapping
    @gateway.expects(:ssl_post).returns(failed_not_allowed_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal AdyenGateway::STANDARD_ERROR_CODE[:config_error], response.error_code
  end

  def test_unknown_reason_error_code_mapping
    @gateway.expects(:ssl_post).returns(failed_unknown_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal AdyenGateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_failed_authorise3d
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.send(:commit, 'authorise3d', {}, {})

    assert_equal 'Expired Card', response.message
    assert_failure response
  end

  def test_failed_authorise3ds2
    @gateway.expects(:ssl_post).returns(failed_authorize_3ds2_response)

    response = @gateway.send(:commit, 'authorise3ds2', {}, {})

    assert_equal '3D Not Authenticated', response.message
    assert_failure response
  end

  def test_failed_authorise_visa
    @gateway.expects(:ssl_post).returns(failed_authorize_visa_response)

    response = @gateway.send(:commit, 'authorise', {}, {})

    assert_equal 'Refused | 01: Refer to card issuer', response.message
    assert_failure response
  end

  def test_failed_authorise_mastercard
    @gateway.expects(:ssl_post).returns(failed_authorize_mastercard_response)

    response = @gateway.send(:commit, 'authorise', {}, {})

    assert_equal 'Refused | 01 : New account information available', response.message
    assert_failure response
  end

  def test_failed_authorise_mastercard_raw_error_message
    @gateway.expects(:ssl_post).returns(failed_authorize_mastercard_response)

    response = @gateway.send(:commit, 'authorise', {}, { raw_error_message: true })

    assert_equal 'Refused | 01: Refer to card issuer', response.message
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    response = @gateway.capture(@amount, '7914775043909934')
    assert_equal '7914775043909934#8814775564188305#', response.authorization
    assert_success response
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    response = @gateway.capture(nil, '')
    assert_nil response.authorization
    assert_equal 'Original pspReference required for this operation', response.message
    assert_failure response
  end

  def test_successful_capture_with_shopper_statement
    stub_comms do
      @gateway.capture(@amount, '7914775043909934', @options.merge(shopper_statement: 'test1234'))
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'test1234', JSON.parse(data)['additionalData']['shopperStatement']
    end.respond_with(successful_capture_response)
  end

  def test_successful_purchase_with_credit_card
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
    assert_equal '7914775043909934#8814775564188305#', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_bank_account
    response = stub_comms do
      @gateway.purchase(@amount, @bank_account, @options)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
    assert_equal '7914775043909934#8814775564188305#', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_elo_card
    response = stub_comms do
      @gateway.purchase(@amount, @elo_credit_card, @options)
    end.respond_with(simple_successful_authorize_response, simple_successful_capture_repsonse)
    assert_success response
    assert_equal '8835511210681145#8835511210689965#', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_cabal_card
    response = stub_comms do
      @gateway.purchase(@amount, @cabal_credit_card, @options)
    end.respond_with(simple_successful_authorize_response, simple_successful_capture_repsonse)
    assert_success response
    assert_equal '8835511210681145#8835511210689965#', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_unionpay_card
    response = stub_comms do
      @gateway.purchase(@amount, @unionpay_credit_card, @options)
    end.respond_with(simple_successful_authorize_response, simple_successful_capture_repsonse)
    assert_success response
    assert_equal '8835511210681145#8835511210689965#', response.authorization
    assert response.test?
  end

  def test_successful_maestro_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({ selected_brand: 'maestro', overwrite_brand: 'true' }))
    end.check_request do |endpoint, data, _headers|
      if /authorise/.match?(endpoint)
        assert_match(/"overwriteBrand":true/, data)
        assert_match(/"selectedBrand":"maestro"/, data)
      end
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
    assert_equal '7914775043909934#8814775564188305#', response.authorization
    assert response.test?
  end

  def test_3ds_2_fields_sent
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @normalized_3ds_2_options)
    end.check_request do |_endpoint, data, _headers|
      data = JSON.parse(data)
      assert_equal 'browser', data['threeDS2RequestData']['deviceChannel']
      assert_equal 'unknown', data['browserInfo']['acceptHeader']
      assert_equal 100, data['browserInfo']['colorDepth']
      assert_equal false, data['browserInfo']['javaEnabled']
      assert_equal 'US', data['browserInfo']['language']
      assert_equal 1000, data['browserInfo']['screenHeight']
      assert_equal 500, data['browserInfo']['screenWidth']
      assert_equal '-120', data['browserInfo']['timeZoneOffset']
      assert_equal 'unknown', data['browserInfo']['userAgent']
    end.respond_with(successful_authorize_response)
  end

  def test_installments_sent
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 2, JSON.parse(data)['installments']['value']
    end.respond_with(successful_authorize_response)
  end

  def test_capture_delay_hours_sent
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge({ capture_delay_hours: 4 }))
    end.check_request do |_endpoint, data, _headers|
      assert_equal 4, JSON.parse(data)['captureDelayHours']
    end.respond_with(successful_authorize_response)
  end

  def test_custom_routing_sent
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge({ custom_routing_flag: 'abcdefg' }))
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'abcdefg', JSON.parse(data)['additionalData']['customRoutingFlag']
    end.respond_with(successful_authorize_response)
  end

  def test_splits_sent
    split_data = [{
      'amount' => {
        'currency' => 'USD',
        'value' => 50
      },
      'type' => 'MarketPlace',
      'account' => '163298747',
      'reference' => 'QXhlbFN0b2x0ZW5iZXJnCg'
    }, {
      'amount' => {
        'currency' => 'USD',
        'value' => 50
      },
      'type' => 'Commission',
      'reference' => 'THVjYXNCbGVkc29lCg'
    }]

    options = @options.merge({ splits: split_data })
    stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal split_data, JSON.parse(data)['splits']
    end.respond_with(successful_authorize_response)
  end

  def test_execute_threed_false_with_additional_data
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge({ execute_threed: false, overwrite_brand: true, selected_brand: 'maestro' }))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"additionalData":{"overwriteBrand":true,"executeThreeD":false}/, data)
      assert_match(/"selectedBrand":"maestro"/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_execute_threed_false_sent_3ds2
    stub_comms do
      @gateway.authorize(@amount, '123', @normalized_3ds_2_options.merge({ execute_threed: false }))
    end.check_request do |_endpoint, data, _headers|
      refute JSON.parse(data)['additionalData']['scaExemption']
      assert_false JSON.parse(data)['additionalData']['executeThreeD']
    end.respond_with(successful_authorize_response)
  end

  def test_sca_exemption_not_sent_if_execute_threed_missing_3ds2
    stub_comms do
      @gateway.authorize(@amount, '123', @normalized_3ds_2_options.merge({ scaExemption: 'lowValue' }))
    end.check_request do |_endpoint, data, _headers|
      refute JSON.parse(data)['additionalData']['scaExemption']
      refute JSON.parse(data)['additionalData']['executeThreeD']
    end.respond_with(successful_authorize_response)
  end

  def test_sca_exemption_and_execute_threed_false_sent_3ds2
    stub_comms do
      @gateway.authorize(@amount, '123', @normalized_3ds_2_options.merge({ sca_exemption: 'lowValue', execute_threed: false }))
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'lowValue', JSON.parse(data)['additionalData']['scaExemption']
      assert_false JSON.parse(data)['additionalData']['executeThreeD']
    end.respond_with(successful_authorize_response)
  end

  def test_sca_exemption_and_execute_threed_true_sent_3ds2
    stub_comms do
      @gateway.authorize(@amount, '123', @normalized_3ds_2_options.merge({ sca_exemption: 'lowValue', execute_threed: true }))
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'lowValue', JSON.parse(data)['additionalData']['scaExemption']
      assert JSON.parse(data)['additionalData']['executeThreeD']
    end.respond_with(successful_authorize_response)
  end

  def test_sca_exemption_not_sent_when_execute_threed_true_3ds1
    stub_comms do
      @gateway.authorize(@amount, '123', @options.merge({ sca_exemption: 'lowValue', execute_threed: true }))
    end.check_request do |_endpoint, data, _headers|
      refute JSON.parse(data)['additionalData']['scaExemption']
      assert JSON.parse(data)['additionalData']['executeThreeD']
    end.respond_with(successful_authorize_response)
  end

  def test_sca_exemption_not_sent_when_execute_threed_false_3ds1
    stub_comms do
      @gateway.authorize(@amount, '123', @options.merge({ sca_exemption: 'lowValue', execute_threed: false }))
    end.check_request do |_endpoint, data, _headers|
      refute JSON.parse(data)['additionalData']['scaExemption']
      refute JSON.parse(data)['additionalData']['executeThreeD']
    end.respond_with(successful_authorize_response)
  end

  def test_update_shopper_statement_and_industry_usage_sent
    stub_comms do
      @gateway.adjust(@amount, '123', @options.merge({ update_shopper_statement: 'statement note', industry_usage: 'DelayedCharge' }))
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'statement note', JSON.parse(data)['additionalData']['updateShopperStatement']
      assert_equal 'DelayedCharge', JSON.parse(data)['additionalData']['industryUsage']
    end.respond_with(successful_adjust_response)
  end

  def test_risk_data_sent
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge({ risk_data: { 'operatingSystem' => 'HAL9000' } }))
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'HAL9000', JSON.parse(data)['additionalData']['riskdata.operatingSystem']
    end.respond_with(successful_authorize_response)
  end

  def test_risk_data_complex_data
    stub_comms do
      risk_data = {
        'deliveryMethod' => 'express',
        'basket.item.productTitle' => 'Blue T Shirt',
        'promotions.promotion.promotionName' => 'Big Sale promotion'
      }
      @gateway.authorize(@amount, @credit_card, @options.merge({ risk_data: risk_data }))
    end.check_request do |_endpoint, data, _headers|
      parsed = JSON.parse(data)
      assert_equal 'express', parsed['additionalData']['riskdata.deliveryMethod']
      assert_equal 'Blue T Shirt', parsed['additionalData']['riskdata.basket.item.productTitle']
      assert_equal 'Big Sale promotion', parsed['additionalData']['riskdata.promotions.promotion.promotionName']
    end.respond_with(successful_authorize_response)
  end

  def test_stored_credential_recurring_cit_initial
    options = stored_credential_options(:cardholder, :recurring, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"shopperInteraction":"Ecommerce"/, data)
      assert_match(/"recurringProcessingModel":"Subscription"/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_recurring_cit_used
    @credit_card.verification_value = nil
    options = stored_credential_options(:cardholder, :recurring, ntid: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"shopperInteraction":"ContAuth"/, data)
      assert_match(/"recurringProcessingModel":"Subscription"/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_recurring_mit_initial
    options = stored_credential_options(:merchant, :recurring, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"shopperInteraction":"ContAuth"/, data)
      assert_match(/"recurringProcessingModel":"Subscription"/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_recurring_mit_used
    @credit_card.verification_value = nil
    options = stored_credential_options(:merchant, :recurring, ntid: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"shopperInteraction":"ContAuth"/, data)
      assert_match(/"recurringProcessingModel":"Subscription"/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_cit_initial
    options = stored_credential_options(:cardholder, :unscheduled, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"shopperInteraction":"Ecommerce"/, data)
      assert_match(/"recurringProcessingModel":"CardOnFile"/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_cit_used
    @credit_card.verification_value = nil
    options = stored_credential_options(:cardholder, :unscheduled, ntid: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"shopperInteraction":"ContAuth"/, data)
      assert_match(/"recurringProcessingModel":"CardOnFile"/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_mit_initial
    options = stored_credential_options(:merchant, :unscheduled, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"shopperInteraction":"ContAuth"/, data)
      assert_match(/"recurringProcessingModel":"UnscheduledCardOnFile"/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_mit_used
    @credit_card.verification_value = nil
    options = stored_credential_options(:merchant, :unscheduled, ntid: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"shopperInteraction":"ContAuth"/, data)
      assert_match(/"recurringProcessingModel":"UnscheduledCardOnFile"/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_skip_mpi_data_field_omits_mpi_hash
    options = {
      billing_address: address(),
      shipping_address: address(),
      shopper_reference: 'John Smith',
      order_id: '1001',
      description: 'AM test',
      currency: 'GBP',
      customer: '123',
      skip_mpi_data: 'Y',
      shopper_interaction: 'ContAuth',
      recurring_processing_model: 'Subscription',
      network_transaction_id: '123ABC'
    }
    response = stub_comms do
      @gateway.authorize(@amount, @apple_pay_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"shopperInteraction":"ContAuth"/, data)
      assert_match(/"recurringProcessingModel":"Subscription"/, data)
      refute_includes data, 'mpiData'
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_omits_mpi_hash_without_field
    options = {
      billing_address: address(),
      shipping_address: address(),
      shopper_reference: 'John Smith',
      order_id: '1001',
      description: 'AM test',
      currency: 'GBP',
      customer: '123',
      shopper_interaction: 'ContAuth',
      recurring_processing_model: 'Subscription',
      network_transaction_id: '123ABC'
    }
    response = stub_comms do
      @gateway.authorize(@amount, @apple_pay_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"shopperInteraction":"ContAuth"/, data)
      assert_match(/"recurringProcessingModel":"Subscription"/, data)
      refute_includes data, 'mpiData'
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_nonfractional_currency_handling
    stub_comms do
      @gateway.authorize(200, @credit_card, @options.merge(currency: 'JPY'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"amount\":{\"value\":\"2\",\"currency\":\"JPY\"}/, data)
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(200, @credit_card, @options.merge(currency: 'CLP'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"amount\":{\"value\":\"200\",\"currency\":\"CLP\"}/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, credit_card('400111'), @options)
    assert_failure response

    assert_equal AdyenGateway::STANDARD_ERROR_CODE[:incorrect_number], response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, '7914775043909934')
    assert_equal '7914775043909934#8514775559925128#', response.authorization
    assert_equal '[refund-received]', response.message
    assert response.test?
  end

  def test_successful_refund_with_compound_psp_reference
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, '7914775043909934#8514775559000000')
    assert_equal '7914775043909934#8514775559925128#', response.authorization
    assert_equal '[refund-received]', response.message
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)
    response = @gateway.refund(@amount, '')
    assert_nil response.authorization
    assert_equal 'Original pspReference required for this operation', response.message
    assert_failure response
  end

  def test_failed_credit
    @gateway.expects(:ssl_post).returns(failed_credit_response)
    response = @gateway.refund(@amount, '')
    assert_nil response.authorization
    assert_equal "Required field 'reference' is not provided.", response.message
    assert_failure response
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    response = @gateway.credit(@amount, '883614109029400G')
    assert_equal '#883614109029400G#', response.authorization
    assert_equal 'Received', response.message
    assert_success response
  end

  def test_successful_payout_with_credit_card
    payout_options = {
      reference: 'P9999999999999999',
      email: 'john.smith@test.com',
      ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: @us_address,
      nationality: 'NL',
      order_id: 'P9999999999999999',
      date_of_birth: '1990-01-01',
      payout: true
    }

    stub_comms do
      @gateway.credit(2500, @credit_card, payout_options)
    end.check_request do |endpoint, data, _headers|
      assert_match(/payout/, endpoint)
      assert_match(/"dateOfBirth\":\"1990-01-01\"/, data)
      assert_match(/"nationality\":\"NL\"/, data)
      assert_match(/"shopperName\":{\"firstName\":\"Test\",\"lastName\":\"Card\"}/, data)
    end.respond_with(successful_payout_response)
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    response = @gateway.void('7914775043909934')
    assert_equal '7914775043909934#8614775821628806#', response.authorization
    assert_equal '[cancel-received]', response.message
    assert response.test?
  end

  def test_successful_cancel_or_refund
    @gateway.expects(:ssl_post).returns(successful_cancel_or_refund_response)
    response = @gateway.void('7914775043909934')
    assert_equal '7914775043909934#8614775821628806#', response.authorization
    assert_equal '[cancelOrRefund-received]', response.message
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    response = @gateway.void('')
    assert_equal 'Original pspReference required for this operation', response.message
    assert_failure response
  end

  def test_successful_adjust
    @gateway.expects(:ssl_post).returns(successful_adjust_response)
    response = @gateway.adjust(200, '8835544088660594')
    assert_equal '8835544088660594#8835544088660594#', response.authorization
    assert_equal '[adjustAuthorisation-received]', response.message
  end

  def test_failed_adjust
    @gateway.expects(:ssl_post).returns(failed_adjust_response)
    response = @gateway.adjust(200, '')
    assert_equal 'Original pspReference required for this operation', response.message
    assert_failure response
  end

  def test_successful_synchronous_adjust
    @gateway.expects(:ssl_post).returns(successful_synchronous_adjust_response)
    response = @gateway.adjust(200, '8835544088660594')
    assert_equal '8835544088660594#8835574118820108#', response.authorization
    assert_equal 'Authorised', response.message
  end

  def test_failed_synchronous_adjust
    @gateway.expects(:ssl_post).returns(failed_synchronous_adjust_response)
    response = @gateway.adjust(200, '8835544088660594')
    assert_equal 'Refused', response.message
    assert_failure response
  end

  def test_successful_tokenize_only_store
    response = stub_comms do
      @gateway.store(@credit_card, @options.merge({ tokenize_only: true }))
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'CardOnFile', JSON.parse(data)['recurringProcessingModel']
    end.respond_with(successful_store_response)
    assert_equal '#8835205392522157#', response.authorization
  end

  def test_successful_tokenize_only_store_with_ntid
    stub_comms do
      @gateway.store(@credit_card, @options.merge({ tokenize_only: true, network_transaction_id: '858435661128555' }))
    end.check_request do |_endpoint, data, _headers|
      assert_equal '858435661128555', JSON.parse(data)['additionalData']['networkTxReference']
    end.respond_with(successful_store_response)
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'CardOnFile', JSON.parse(data)['recurringProcessingModel']
    end.respond_with(successful_store_response)
    assert_success response
    assert_equal '#8835205392522157#8315202663743702', response.authorization
  end

  def test_successful_store_with_bank_account
    response = stub_comms do
      @gateway.store(@bank_account, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'CardOnFile', JSON.parse(data)['recurringProcessingModel']
    end.respond_with(successful_store_response)
    assert_success response
    assert_equal '#8835205392522157#8315202663743702', response.authorization
  end

  def test_successful_store_with_recurring_contract_type
    stub_comms do
      @gateway.store(@credit_card, @options.merge({ recurring_contract_type: 'ONECLICK' }))
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'ONECLICK', JSON.parse(data)['recurring']['contract']
    end.respond_with(successful_store_response)
  end

  def test_recurring_contract_type_set_for_reference_purchase
    stub_comms do
      @gateway.store('123', @options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'RECURRING', JSON.parse(data)['recurring']['contract']
    end.respond_with(successful_store_response)
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)
    response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal 'Refused', response.message
  end

  def test_successful_unstore
    response = stub_comms do
      @gateway.unstore(shopper_reference: 'shopper_reference',
                       recurring_detail_reference: 'detail_reference')
    end.respond_with(successful_unstore_response)
    assert_success response
    assert_equal '[detail-successfully-disabled]', response.message
  end

  def test_failed_unstore
    @gateway.expects(:ssl_post).returns(failed_unstore_response)
    response = @gateway.unstore(shopper_reference: 'random_reference',
                                recurring_detail_reference: 'detail_reference')
    assert_failure response
    assert_equal 'Contract not found', response.message
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.check_request do |endpoint, data, _headers|
      assert_equal '0', JSON.parse(data)['amount']['value'] if endpoint.include?('authorise')
    end.respond_with(successful_verify_response)
    assert_success response
    assert_equal '#7914776426645103#', response.authorization
    assert_equal 'Authorised', response.message
    assert response.test?
  end

  def test_successful_verify_with_custom_amount
    response = stub_comms do
      @gateway.verify(@credit_card, @options.merge({ verify_amount: '500' }))
    end.check_request do |endpoint, data, _headers|
      assert_equal '500', JSON.parse(data)['amount']['value'] if endpoint.include?('authorise')
    end.respond_with(successful_verify_response)
    assert_success response
  end

  def test_successful_verify_with_bank_account
    response = stub_comms do
      @gateway.verify(@bank_account, @options)
    end.respond_with(successful_verify_response)
    assert_success response
    assert_equal '#7914776426645103#', response.authorization
    assert_equal 'Authorised', response.message
    assert response.test?
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_verify_response)
    assert_failure response
    assert_equal '#7914776433387947#', response.authorization
    assert_equal 'Refused', response.message
    assert response.test?
  end

  def test_failed_verify_with_bank_account
    response = stub_comms do
      @gateway.verify(@bank_account, @options)
    end.respond_with(failed_verify_response)
    assert_failure response
    assert_equal '#7914776433387947#', response.authorization
    assert_equal 'Refused', response.message
    assert response.test?
  end

  def test_failed_avs_check_returns_refusal_reason_raw
    @gateway.expects(:ssl_post).returns(failed_authorize_avs_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Refused | 05 : Do not honor', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_scrub_bank_account
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed_bank_account), post_scrubbed_bank_account
  end

  def test_scrub_network_tokenization_card
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed_network_tokenization_card), post_scrubbed_network_tokenization_card
  end

  def test_shopper_data
    post = { card: { billingAddress: {} } }
    @gateway.send(:add_shopper_data, post, @credit_card, @options)
    @gateway.send(:add_extra_data, post, @credit_card, @options)
    assert_equal 'john.smith@test.com', post[:shopperEmail]
    assert_equal '77.110.174.153', post[:shopperIP]
  end

  def test_shopper_data_backwards_compatibility
    post = { card: { billingAddress: {} } }
    @gateway.send(:add_shopper_data, post, @credit_card, @options_shopper_data)
    @gateway.send(:add_extra_data, post, @credit_card, @options_shopper_data)
    assert_equal 'john2.smith@test.com', post[:shopperEmail]
    assert_equal '192.168.100.100', post[:shopperIP]
  end

  def test_add_address
    post = { card: { billingAddress: {} } }
    @options[:billing_address].delete(:address1)
    @options[:billing_address].delete(:address2)
    @options[:billing_address].delete(:state)
    @options[:shipping_address].delete(:state)
    @gateway.send(:add_address, post, @options)
    # Billing Address
    assert_equal 'NA', post[:billingAddress][:street]
    assert_equal 'NA', post[:billingAddress][:houseNumberOrName]
    assert_equal 'NA', post[:billingAddress][:stateOrProvince]
    assert_equal @options[:billing_address][:zip], post[:billingAddress][:postalCode]
    assert_equal @options[:billing_address][:city], post[:billingAddress][:city]
    assert_equal @options[:billing_address][:country], post[:billingAddress][:country]
    # Shipping Address
    assert_equal 'NA', post[:deliveryAddress][:stateOrProvince]
    assert_equal @options[:shipping_address][:address1], post[:deliveryAddress][:street]
    assert_equal @options[:shipping_address][:address2], post[:deliveryAddress][:houseNumberOrName]
    assert_equal @options[:shipping_address][:zip], post[:deliveryAddress][:postalCode]
    assert_equal @options[:shipping_address][:city], post[:deliveryAddress][:city]
    assert_equal @options[:shipping_address][:country], post[:deliveryAddress][:country]
  end

  def test_address_override_that_will_swap_housenumberorname_and_street
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(address_override: true))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"houseNumberOrName":"456 My Street"/, data)
      assert_match(/"street":"Apt 1"/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_successful_auth_phone
    options = @options.merge(billing_address: { phone: 1234567890 })
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 1234567890, JSON.parse(data)['telephoneNumber']
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_successful_auth_phone_number
    options = @options.merge(billing_address: { phone_number: 987654321, phone: 1234567890 })
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 987654321, JSON.parse(data)['telephoneNumber']
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_successful_auth_application_info
    ActiveMerchant::Billing::AdyenGateway.application_id = { name: 'Acme', version: '1.0' }

    options = @options.merge!(
      merchantApplication: {
        name: 'Acme Inc.',
        version: '2'
      }
    )
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'Acme', JSON.parse(data)['applicationInfo']['externalPlatform']['name']
      assert_equal '1.0', JSON.parse(data)['applicationInfo']['externalPlatform']['version']
      assert_equal 'Acme Inc.', JSON.parse(data)['applicationInfo']['merchantApplication']['name']
      assert_equal '2', JSON.parse(data)['applicationInfo']['merchantApplication']['version']
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_purchase_with_long_order_id
    options = @options.merge({ order_id: @long_order_id })
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal @long_order_id[0..79], JSON.parse(data)['reference']
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_authorize_with_credit_card_no_name
    credit_card_no_name = ActiveMerchant::Billing::CreditCard.new({
      number: '4111111111111111',
      month: 3,
      year: 2030,
      verification_value: '737',
      brand: 'visa'
    })

    response = stub_comms do
      @gateway.authorize(@amount, credit_card_no_name, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'Not Provided', JSON.parse(data)['card']['holderName']
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_authorize_with_network_tokenization_credit_card_no_name
    @apple_pay_card.first_name = nil
    @apple_pay_card.last_name = nil
    response = stub_comms do
      @gateway.authorize(@amount, @apple_pay_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'Not Provided', JSON.parse(data)['card']['holderName']
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_authorize_with_network_tokenization_credit_card
    response = stub_comms do
      @gateway.authorize(@amount, @apple_pay_card, @options)
    end.check_request do |_endpoint, data, _headers|
      parsed = JSON.parse(data)
      assert_equal 'YwAAAAAABaYcCMX/OhNRQAAAAAA=', parsed['mpiData']['cavv']
      assert_equal '07', parsed['mpiData']['eci']
      assert_equal 'applepay', parsed['additionalData']['paymentdatasource.type']
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_authorize_and_capture_with_network_transaction_id
    auth = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.respond_with(successful_authorize_response_with_network_tx_ref)
    assert_equal auth.network_transaction_id, '858435661128555'

    response = stub_comms do
      @gateway.capture(@amount, auth.authorization, @options.merge(network_transaction_id: auth.network_transaction_id))
    end.check_request do |_, data, _|
      assert_match(/"networkTxReference":"#{auth.network_transaction_id}"/, data)
    end.respond_with(successful_capture_response)
    assert_success response
  end

  def test_authorize_and_capture_with_network_transaction_id_from_stored_cred_hash
    auth = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.respond_with(successful_authorize_response_with_network_tx_ref)
    assert_equal auth.network_transaction_id, '858435661128555'

    response = stub_comms do
      @gateway.capture(@amount, auth.authorization, @options.merge(stored_credential: { network_transaction_id: auth.network_transaction_id }))
    end.check_request do |_, data, _|
      assert_match(/"networkTxReference":"#{auth.network_transaction_id}"/, data)
    end.respond_with(successful_capture_response)
    assert_success response
  end

  def test_authorize_with_network_token
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @nt_credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_network_token
    response = stub_comms do
      @gateway.purchase(@amount, @nt_credit_card, @options)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_supports_network_tokenization
    assert_instance_of TrueClass, @gateway.supports_network_tokenization?
  end

  def test_authorize_with_sub_merchant_id
    sub_merchant_data = {
      sub_merchant_id: '123451234512345',
      sub_merchant_name: 'Wildsea',
      sub_merchant_street: '1234 Street St',
      sub_merchant_city: 'Night City',
      sub_merchant_state: 'East Block',
      sub_merchant_postal_code: '112233',
      sub_merchant_country: 'EUR',
      sub_merchant_tax_id: '12345abcde67',
      sub_merchant_mcc: '1234'
    }
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(sub_merchant_data))
    end.check_request do |_endpoint, data, _headers|
      parsed = JSON.parse(data)
      assert parsed['additionalData']['subMerchantID']
      assert parsed['additionalData']['subMerchantName']
      assert parsed['additionalData']['subMerchantStreet']
      assert parsed['additionalData']['subMerchantCity']
      assert parsed['additionalData']['subMerchantState']
      assert parsed['additionalData']['subMerchantPostalCode']
      assert parsed['additionalData']['subMerchantCountry']
      assert parsed['additionalData']['subMerchantTaxId']
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_authorize_with_sub_sellers
    sub_seller_options = {
      "subMerchant.numberOfSubSellers": '2',
      "subMerchant.subSeller1.id": '111111111',
      "subMerchant.subSeller1.name": 'testSub1',
      "subMerchant.subSeller1.street": 'Street1',
      "subMerchant.subSeller1.postalCode": '12242840',
      "subMerchant.subSeller1.city": 'Sao jose dos campos',
      "subMerchant.subSeller1.state": 'SP',
      "subMerchant.subSeller1.country": 'BRA',
      "subMerchant.subSeller1.taxId": '12312312340',
      "subMerchant.subSeller1.mcc": '5691',
      "subMerchant.subSeller1.debitSettlementBank": '1',
      "subMerchant.subSeller1.debitSettlementAgency": '1',
      "subMerchant.subSeller1.debitSettlementAccountType": '1',
      "subMerchant.subSeller1.debitSettlementAccount": '1',
      "subMerchant.subSeller1.creditSettlementBank": '1',
      "subMerchant.subSeller1.creditSettlementAgency": '1',
      "subMerchant.subSeller1.creditSettlementAccountType": '1',
      "subMerchant.subSeller1.creditSettlementAccount": '1',
      "subMerchant.subSeller2.id": '22222222',
      "subMerchant.subSeller2.name": 'testSub2',
      "subMerchant.subSeller2.street": 'Street2',
      "subMerchant.subSeller2.postalCode": '12300000',
      "subMerchant.subSeller2.city": 'Jacarei',
      "subMerchant.subSeller2.state": 'SP',
      "subMerchant.subSeller2.country": 'BRA',
      "subMerchant.subSeller2.taxId": '12312312340',
      "subMerchant.subSeller2.mcc": '5691',
      "subMerchant.subSeller2.debitSettlementBank": '1',
      "subMerchant.subSeller2.debitSettlementAgency": '1',
      "subMerchant.subSeller2.debitSettlementAccountType": '1',
      "subMerchant.subSeller2.debitSettlementAccount": '1',
      "subMerchant.subSeller2.creditSettlementBank": '1',
      "subMerchant.subSeller2.creditSettlementAgency": '1',
      "subMerchant.subSeller2.creditSettlementAccountType": '1',
      "subMerchant.subSeller2.creditSettlementAccount": '1'
    }
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(sub_merchant_data: sub_seller_options))
    end.check_request do |_endpoint, data, _headers|
      parsed = JSON.parse(data)
      additional_data = parsed['additionalData']
      assert additional_data['subMerchant.numberOfSubSellers']
      assert additional_data['subMerchant.subSeller1.id']
      assert additional_data['subMerchant.subSeller1.name']
      assert additional_data['subMerchant.subSeller1.street']
      assert additional_data['subMerchant.subSeller1.city']
      assert additional_data['subMerchant.subSeller1.state']
      assert additional_data['subMerchant.subSeller1.postalCode']
      assert additional_data['subMerchant.subSeller1.country']
      assert additional_data['subMerchant.subSeller1.taxId']
      assert additional_data['subMerchant.subSeller1.debitSettlementBank']
      assert additional_data['subMerchant.subSeller1.debitSettlementAgency']
      assert additional_data['subMerchant.subSeller1.debitSettlementAccountType']
      assert additional_data['subMerchant.subSeller1.debitSettlementAccount']
      assert additional_data['subMerchant.subSeller1.creditSettlementBank']
      assert additional_data['subMerchant.subSeller1.creditSettlementAgency']
      assert additional_data['subMerchant.subSeller1.creditSettlementAccountType']
      assert additional_data['subMerchant.subSeller1.creditSettlementAccount']
      assert additional_data['subMerchant.subSeller2.id']
      assert additional_data['subMerchant.subSeller2.name']
      assert additional_data['subMerchant.subSeller2.street']
      assert additional_data['subMerchant.subSeller2.city']
      assert additional_data['subMerchant.subSeller2.state']
      assert additional_data['subMerchant.subSeller2.postalCode']
      assert additional_data['subMerchant.subSeller2.country']
      assert additional_data['subMerchant.subSeller2.taxId']
      assert additional_data['subMerchant.subSeller2.debitSettlementBank']
      assert additional_data['subMerchant.subSeller2.debitSettlementAgency']
      assert additional_data['subMerchant.subSeller2.debitSettlementAccountType']
      assert additional_data['subMerchant.subSeller2.debitSettlementAccount']
      assert additional_data['subMerchant.subSeller2.creditSettlementBank']
      assert additional_data['subMerchant.subSeller2.creditSettlementAgency']
      assert additional_data['subMerchant.subSeller2.creditSettlementAccountType']
      assert additional_data['subMerchant.subSeller2.creditSettlementAccount']
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_level_2_data
    level_2_options = {
      total_tax_amount: '160',
      customer_reference: '101'
    }

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(level_2_data: level_2_options))
    end.check_request do |_endpoint, data, _headers|
      parsed = JSON.parse(data)
      additional_data = parsed['additionalData']
      assert_equal additional_data['enhancedSchemeData.totalTaxAmount'], level_2_options[:total_tax_amount]
      assert_equal additional_data['enhancedSchemeData.customerReference'], level_2_options[:customer_reference]
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_level_3_data
    level_3_options = {
      total_tax_amount: '12800',
      customer_reference: '101',
      freight_amount: '300',
      destination_state_province_code: 'NYC',
      ship_from_postal_code: '1082GM',
      order_date: '101216',
      destination_postal_code: '1082GM',
      destination_country_code: 'NLD',
      duty_amount: '500',
      items: [
        {
          description: 'T16 Test products 1',
          product_code: 'TEST120',
          commodity_code: 'COMMCODE1',
          quantity: '5',
          unit_of_measure: 'm',
          unit_price: '1000',
          discount_amount: '60',
          total_amount: '4940'
        }
      ]
    }

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(level_3_data: level_3_options))
    end.check_request do |_endpoint, data, _headers|
      parsed = JSON.parse(data)
      additional_data = parsed['additionalData']
      leve_3_keys = ['enhancedSchemeData.freightAmount', 'enhancedSchemeData.destinationStateProvinceCode',
                     'enhancedSchemeData.shipFromPostalCode', 'enhancedSchemeData.orderDate', 'enhancedSchemeData.destinationPostalCode',
                     'enhancedSchemeData.destinationCountryCode', 'enhancedSchemeData.dutyAmount',
                     'enhancedSchemeData.itemDetailLine1.description', 'enhancedSchemeData.itemDetailLine1.productCode',
                     'enhancedSchemeData.itemDetailLine1.commodityCode', 'enhancedSchemeData.itemDetailLine1.quantity',
                     'enhancedSchemeData.itemDetailLine1.unitOfMeasure', 'enhancedSchemeData.itemDetailLine1.unitPrice',
                     'enhancedSchemeData.itemDetailLine1.discountAmount', 'enhancedSchemeData.itemDetailLine1.totalAmount']

      additional_data_keys = additional_data.keys
      assert_all(leve_3_keys) { |item| additional_data_keys.include?(item) }

      mapper = { "enhancedSchemeData.freightAmount": 'freight_amount',
                "enhancedSchemeData.destinationStateProvinceCode": 'destination_state_province_code',
                "enhancedSchemeData.shipFromPostalCode": 'ship_from_postal_code',
                "enhancedSchemeData.orderDate": 'order_date',
                "enhancedSchemeData.destinationPostalCode": 'destination_postal_code',
                "enhancedSchemeData.destinationCountryCode": 'destination_country_code',
                "enhancedSchemeData.dutyAmount": 'duty_amount' }

      mapper.each do |item|
        assert_equal additional_data[item[0]], level_3_options[item[1]]
      end
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_succesful_additional_airline_data
    airline_data = {
      agency_invoice_number: 'BAC123',
      agency_plan_name: 'plan name',
      airline_code: '434234',
      airline_designator_code: '1234',
      boarding_fee: '100',
      computerized_reservation_system: 'abcd',
      customer_reference_number: 'asdf1234',
      document_type: 'cc',
      leg: {
        carrier_code: 'KL'
      },
      passenger: {
        first_name: 'Joe',
        last_name: 'Doe'
      }
    }

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(additional_data_airline: airline_data))
    end.check_request do |_endpoint, data, _headers|
      parsed = JSON.parse(data)
      additional_data = parsed['additionalData']
      assert_equal additional_data['airline.agency_invoice_number'], airline_data[:agency_invoice_number]
      assert_equal additional_data['airline.agency_plan_name'], airline_data[:agency_plan_name]
      assert_equal additional_data['airline.airline_code'], airline_data[:airline_code]
      assert_equal additional_data['airline.airline_designator_code'], airline_data[:airline_designator_code]
      assert_equal additional_data['airline.boarding_fee'], airline_data[:boarding_fee]
      assert_equal additional_data['airline.computerized_reservation_system'], airline_data[:computerized_reservation_system]
      assert_equal additional_data['airline.customer_reference_number'], airline_data[:customer_reference_number]
      assert_equal additional_data['airline.document_type'], airline_data[:document_type]
      assert_equal additional_data['airline.flight_date'], airline_data[:flight_date]
      assert_equal additional_data['airline.ticket_issue_address'], airline_data[:abcqwer]
      assert_equal additional_data['airline.ticket_number'], airline_data[:ticket_number]
      assert_equal additional_data['airline.travel_agency_code'], airline_data[:travel_agency_code]
      assert_equal additional_data['airline.travel_agency_name'], airline_data[:travel_agency_name]
      assert_equal additional_data['airline.passenger_name'], airline_data[:passenger_name]
      assert_equal additional_data['airline.leg.carrier_code'], airline_data[:leg][:carrier_code]
      assert_equal additional_data['airline.leg.class_of_travel'], airline_data[:leg][:class_of_travel]
      assert_equal additional_data['airline.passenger.first_name'], airline_data[:passenger][:first_name]
      assert_equal additional_data['airline.passenger.last_name'], airline_data[:passenger][:last_name]
      assert_equal additional_data['airline.passenger.telephone_number'], airline_data[:passenger][:telephone_number]
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_additional_data_lodging
    lodging_data = {
      check_in_date: '20230822',
      check_out_date: '20230830',
      customer_service_toll_free_number: '234234',
      fire_safety_act_indicator: 'abc123',
      folio_cash_advances: '1234667',
      folio_number: '32343',
      food_beverage_charges: '1234',
      no_show_indicator: 'Y',
      prepaid_expenses: '100',
      property_phone_number: '54545454',
      number_of_nights: '5'
    }

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(additional_data_lodging: lodging_data))
    end.check_request do |_endpoint, data, _headers|
      parsed = JSON.parse(data)
      additional_data = parsed['additionalData']
      assert_equal additional_data['lodging.checkInDate'], lodging_data[:check_in_date]
      assert_equal additional_data['lodging.checkOutDate'], lodging_data[:check_out_date]
      assert_equal additional_data['lodging.customerServiceTollFreeNumber'], lodging_data[:customer_service_toll_free_number]
      assert_equal additional_data['lodging.fireSafetyActIndicator'], lodging_data[:fire_safety_act_indicator]
      assert_equal additional_data['lodging.folioCashAdvances'], lodging_data[:folio_cash_advances]
      assert_equal additional_data['lodging.folioNumber'], lodging_data[:folio_number]
      assert_equal additional_data['lodging.foodBeverageCharges'], lodging_data[:food_beverage_charges]
      assert_equal additional_data['lodging.noShowIndicator'], lodging_data[:no_show_indicator]
      assert_equal additional_data['lodging.prepaidExpenses'], lodging_data[:prepaid_expenses]
      assert_equal additional_data['lodging.propertyPhoneNumber'], lodging_data[:property_phone_number]
      assert_equal additional_data['lodging.room1.numberOfNights'], lodging_data[:number_of_nights]
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_additional_extra_data
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(store: 'test store'))
    end.check_request do |_endpoint, data, _headers|
      assert_equal JSON.parse(data)['store'], 'test store'
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_extended_avs_response
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(extended_avs_response)
    assert_equal 'Card member\'s name, billing address, and billing postal code match.', response.avs_result['message']
  end

  def test_optional_idempotency_key_header
    options = @options.merge(idempotency_key: 'test123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, _data, headers|
      assert headers['Idempotency-Key']
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_three_decimal_places_currency_handling
    stub_comms do
      @gateway.authorize(1000, @credit_card, @options.merge(currency: 'JOD'))
    end.check_request(skip_response: true) do |_endpoint, data|
      assert_match(/"amount\":{\"value\":\"1000\",\"currency\":\"JOD\"}/, data)
    end
  end

  private

  def stored_credential_options(*args, ntid: nil)
    {
      order_id: '#1001',
      description: 'AM test',
      currency: 'GBP',
      customer: '123',
      stored_credential: stored_credential(*args, ntid: ntid)
    }
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to pal-test.adyen.com:443...
      opened
      starting SSL for pal-test.adyen.com:443...
      SSL established
      <- "POST /pal/servlet/Payment/v18/authorise HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic d3NfMTYzMjQ1QENvbXBhbnkuRGFuaWVsYmFra2Vybmw6eXU0aD50ZlxIVEdydSU1PDhxYTVMTkxVUw==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.adyen.com\r\nContent-Length: 308\r\n\r\n"
      <- "{\"merchantAccount\":\"DanielbakkernlNL\",\"reference\":\"345123\",\"amount\":{\"value\":\"100\",\"currency\":\"USD\"},\"card\":{\"expiryMonth\":8,\"expiryYear\":2018,\"holderName\":\"John Smith\",\"number\":\"4111111111111111\",\"cvc\":\"737\"},\"shopperEmail\":\"john.smith@test.com\",\"shopperIP\":\"77.110.174.153\",\"shopperReference\":\"John Smith\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 27 Oct 2016 11:37:13 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Set-Cookie: JSESSIONID=C0D66C19173B3491D862B8FDBFD72FD7.test3e; Path=/pal/; Secure; HttpOnly\r\n"
      -> "pspReference: 8514775682339577\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "\r\n"
      -> "50\r\n"
      reading 80 bytes...
      -> ""
      -> "{\"pspReference\":\"8514775682339577\",\"resultCode\":\"Authorised\",\"authCode\":\"31845\"}"
      read 80 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to pal-test.adyen.com:443...
      opened
      starting SSL for pal-test.adyen.com:443...
      SSL established
      <- "POST /pal/servlet/Payment/v18/authorise HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.adyen.com\r\nContent-Length: 308\r\n\r\n"
      <- "{\"merchantAccount\":\"DanielbakkernlNL\",\"reference\":\"345123\",\"amount\":{\"value\":\"100\",\"currency\":\"USD\"},\"card\":{\"expiryMonth\":8,\"expiryYear\":2018,\"holderName\":\"John Smith\",\"number\":\"[FILTERED]\",\"cvc\":\"[FILTERED]\"},\"shopperEmail\":\"john.smith@test.com\",\"shopperIP\":\"77.110.174.153\",\"shopperReference\":\"John Smith\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 27 Oct 2016 11:37:13 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Set-Cookie: JSESSIONID=C0D66C19173B3491D862B8FDBFD72FD7.test3e; Path=/pal/; Secure; HttpOnly\r\n"
      -> "pspReference: 8514775682339577\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "\r\n"
      -> "50\r\n"
      reading 80 bytes...
      -> ""
      -> "{\"pspReference\":\"8514775682339577\",\"resultCode\":\"Authorised\",\"authCode\":\"31845\"}"
      read 80 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    POST_SCRUBBED
  end

  def pre_scrubbed_bank_account
    <<-PRE_SCRUBBED
      opening connection to pal-test.adyen.com:443...
      opened
      starting SSL for pal-test.adyen.com:443...
      SSL established
      <- "POST /pal/servlet/Payment/v18/authorise HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic d3NfMTYzMjQ1QENvbXBhbnkuRGFuaWVsYmFra2Vybmw6eXU0aD50ZlxIVEdydSU1PDhxYTVMTkxVUw==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.adyen.com\r\nContent-Length: 308\r\n\r\n"
      <- "{\"merchantAccount\":\"DanielbakkernlNL\",\"reference\":\"345123\",\"amount\":{\"value\":\"100\",\"currency\":\"USD\"},\"bankAccount\":{\"bankAccountNumber\":\"15378535\",\"bankLocationId\":\"244183602\",\"ownerName\":\"Jim Smith\",\"shopperEmail\":\"john.smith@test.com\",\"shopperIP\":\"77.110.174.153\",\"shopperReference\":\"John Smith\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 27 Oct 2016 11:37:13 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Set-Cookie: JSESSIONID=C0D66C19173B3491D862B8FDBFD72FD7.test3e; Path=/pal/; Secure; HttpOnly\r\n"
      -> "pspReference: 8514775682339577\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "\r\n"
      -> "50\r\n"
      reading 80 bytes...
      -> ""
      -> "{\"pspReference\":\"8514775682339577\",\"resultCode\":\"Authorised\",\"authCode\":\"31845\"}"
      read 80 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed_bank_account
    <<-POST_SCRUBBED
      opening connection to pal-test.adyen.com:443...
      opened
      starting SSL for pal-test.adyen.com:443...
      SSL established
      <- "POST /pal/servlet/Payment/v18/authorise HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.adyen.com\r\nContent-Length: 308\r\n\r\n"
      <- "{\"merchantAccount\":\"DanielbakkernlNL\",\"reference\":\"345123\",\"amount\":{\"value\":\"100\",\"currency\":\"USD\"},\"bankAccount\":{\"bankAccountNumber\":\"[FILTERED]\",\"bankLocationId\":\"[FILTERED]\",\"ownerName\":\"Jim Smith\",\"shopperEmail\":\"john.smith@test.com\",\"shopperIP\":\"77.110.174.153\",\"shopperReference\":\"John Smith\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 27 Oct 2016 11:37:13 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Set-Cookie: JSESSIONID=C0D66C19173B3491D862B8FDBFD72FD7.test3e; Path=/pal/; Secure; HttpOnly\r\n"
      -> "pspReference: 8514775682339577\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "\r\n"
      -> "50\r\n"
      reading 80 bytes...
      -> ""
      -> "{\"pspReference\":\"8514775682339577\",\"resultCode\":\"Authorised\",\"authCode\":\"31845\"}"
      read 80 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    POST_SCRUBBED
  end

  def pre_scrubbed_network_tokenization_card
    <<-PRE_SCRUBBED
      opening connection to pal-test.adyen.com:443...
      opened
      starting SSL for pal-test.adyen.com:443...
      SSL established
      I, [2018-06-18T11:53:47.394267 #25363]  INFO -- : [ActiveMerchant::Billing::AdyenGateway] connection_ssl_version=TLSv1.2 connection_ssl_cipher=ECDHE-RSA-AES128-GCM-SHA256
      D, [2018-06-18T11:53:47.394346 #25363] DEBUG -- : {"merchantAccount":"SpreedlyCOM294","reference":"123","amount":{"value":"100","currency":"USD"},"mpiData":{"authenticationResponse":"Y","cavv":"YwAAAAAABaYcCMX/OhNRQAAAAAA=","directoryResponse":"Y","eci":"07"},"card":{"expiryMonth":8,"expiryYear":2018,"holderName":"Longbob Longsen","number":"4111111111111111","billingAddress":{"street":"456 My Street","houseNumberOrName":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","stateOrProvince":"ON","country":"CA"}},"shopperEmail":"john.smith@test.com","shopperIP":"77.110.174.153","shopperReference":"John Smith","selectedBrand":"applepay","shopperInteraction":"Ecommerce"}
      <- "POST /pal/servlet/Payment/v18/authorise HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic d3NAQ29tcGFueS5TcHJlZWRseTQ3MTo3c3d6U0p2R1VWViUvP3Q0Uy9bOVtoc0hF\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: pal-test.adyen.com\r\nContent-Length: 618\r\n\r\n"
      <- "{\"merchantAccount\":\"SpreedlyCOM294\",\"reference\":\"123\",\"amount\":{\"value\":\"100\",\"currency\":\"USD\"},\"mpiData\":{\"authenticationResponse\":\"Y\",\"cavv\":\"YwAAAAAABaYcCMX/OhNRQAAAAAA=\",\"directoryResponse\":\"Y\",\"eci\":\"07\"},\"card\":{\"expiryMonth\":8,\"expiryYear\":2018,\"holderName\":\"Longbob Longsen\",\"number\":\"4111111111111111\",\"billingAddress\":{\"street\":\"456 My Street\",\"houseNumberOrName\":\"Apt 1\",\"postalCode\":\"K1C2N6\",\"city\":\"Ottawa\",\"stateOrProvince\":\"ON\",\"country\":\"CA\"}},\"shopperEmail\":\"john.smith@test.com\",\"shopperIP\":\"77.110.174.153\",\"shopperReference\":\"John Smith\",\"selectedBrand\":\"applepay\",\"shopperInteraction\":\"Ecommerce\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 18 Jun 2018 15:53:47 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Set-Cookie: JSESSIONID=06EE78291B761A33ED9E21E46BA54649.test104e; Path=/pal; Secure; HttpOnly\r\n"
      -> "pspReference: 8835293372276408\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "\r\n"
      -> "50\r\n"
      reading 80 bytes...
      -> ""
      -> "{\"pspReference\":\"8835293372276408\",\"resultCode\":\"Authorised\",\"authCode\":\"26056\"}"
      read 80 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed_network_tokenization_card
    <<-POST_SCRUBBED
      opening connection to pal-test.adyen.com:443...
      opened
      starting SSL for pal-test.adyen.com:443...
      SSL established
      I, [2018-06-18T11:53:47.394267 #25363]  INFO -- : [ActiveMerchant::Billing::AdyenGateway] connection_ssl_version=TLSv1.2 connection_ssl_cipher=ECDHE-RSA-AES128-GCM-SHA256
      D, [2018-06-18T11:53:47.394346 #25363] DEBUG -- : {"merchantAccount":"SpreedlyCOM294","reference":"123","amount":{"value":"100","currency":"USD"},"mpiData":{"authenticationResponse":"Y","cavv":"[FILTERED]","directoryResponse":"Y","eci":"07"},"card":{"expiryMonth":8,"expiryYear":2018,"holderName":"Longbob Longsen","number":"[FILTERED]","billingAddress":{"street":"456 My Street","houseNumberOrName":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","stateOrProvince":"ON","country":"CA"}},"shopperEmail":"john.smith@test.com","shopperIP":"77.110.174.153","shopperReference":"John Smith","selectedBrand":"applepay","shopperInteraction":"Ecommerce"}
      <- "POST /pal/servlet/Payment/v18/authorise HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: pal-test.adyen.com\r\nContent-Length: 618\r\n\r\n"
      <- "{\"merchantAccount\":\"SpreedlyCOM294\",\"reference\":\"123\",\"amount\":{\"value\":\"100\",\"currency\":\"USD\"},\"mpiData\":{\"authenticationResponse\":\"Y\",\"cavv\":\"[FILTERED]\",\"directoryResponse\":\"Y\",\"eci\":\"07\"},\"card\":{\"expiryMonth\":8,\"expiryYear\":2018,\"holderName\":\"Longbob Longsen\",\"number\":\"[FILTERED]\",\"billingAddress\":{\"street\":\"456 My Street\",\"houseNumberOrName\":\"Apt 1\",\"postalCode\":\"K1C2N6\",\"city\":\"Ottawa\",\"stateOrProvince\":\"ON\",\"country\":\"CA\"}},\"shopperEmail\":\"john.smith@test.com\",\"shopperIP\":\"77.110.174.153\",\"shopperReference\":\"John Smith\",\"selectedBrand\":\"applepay\",\"shopperInteraction\":\"Ecommerce\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 18 Jun 2018 15:53:47 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Set-Cookie: JSESSIONID=06EE78291B761A33ED9E21E46BA54649.test104e; Path=/pal; Secure; HttpOnly\r\n"
      -> "pspReference: 8835293372276408\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "\r\n"
      -> "50\r\n"
      reading 80 bytes...
      -> ""
      -> "{\"pspReference\":\"8835293372276408\",\"resultCode\":\"Authorised\",\"authCode\":\"26056\"}"
      read 80 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    POST_SCRUBBED
  end

  def failed_purchase_response
    <<-RESPONSE
    {
      "status": 422,
      "errorCode": "101",
      "message": "Invalid card number",
      "errorType": "validation",
      "pspReference": "8514775645144049"
    }
    RESPONSE
  end

  def simple_successful_authorize_response
    <<-RESPONSE
    {
      "pspReference":"8835511210681145",
      "resultCode":"Authorised",
      "authCode":"98696"
    }
    RESPONSE
  end

  def simple_successful_capture_repsonse
    <<-RESPONSE
    {
      "pspReference":"8835511210689965",
      "response":"[capture-received]"
    }
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
    {
      "additionalData": {
        "cvcResult": "1 Matches",
        "avsResult": "0 Unknown",
        "cvcResultRaw": "M"
      },
      "pspReference":"7914775043909934",
      "resultCode":"Authorised",
      "authCode":"50055"
    }
    RESPONSE
  end

  def successful_authorize_response_with_network_tx_ref
    <<~RESPONSE
      {
        "additionalData": {
          "liabilityShift": "false",
          "authCode": "034788",
          "avsResult": "2 Neither postal code nor address match",
          "adjustAuthorisationData": "BQABAQAd37r69soYRcrrGlBumyPHvhurCKvze1aPCT2fztlUyUZZ0+5YZgh/rlmBjM9FNCm3Emv4awkiFXyaMJ4x+Jc7eGJpCaB9oq1QTkeMIw4yjvblij8nBmj8OIloKN/sKVF1WD4tSSC6ybgz0/ZxVZpn+l4TDcHJfGIYfELax7sMFfjGR6HEGw1Ac0we4FcLltxLL8x/aRRGOaadBO74wpvl8aatVYvgVKh42f09ovChJlDvcoIifAopkp5RxuzN1wqcad+ScHZsriVJVySuXgguAaLmEBpF6y/LQfej1pRW+zEEjYgFzrnbP+giWomBQcyY2mCnf6cBwVaeddavLSv6EMcmuplIfUPGDSr7NygJ2wkAAAEZmz6JwmlAmPoKMsuJPnnRNSBdG2EKTRBU139U2ytJuK8hVXNJc98A7bylLQqRc9zjSxJAOdX+KdaEY4KNASUqovgZ1ylPnRt/FYOqfraZcyQtl9otJjTl9oQkgSdfFeQEKg6OD9VVMzObShBEjuVFuT6HAAujEl79i1eS7QhD0w4/c8zW6tsSF29gbr7CPi/CHudeUuFHBPWGQ/NoIQXYKD+TfU+mKyPq0w8NYRdQyIiTHXHppDfrBJFbyCfE3+Dm80KKt3Kf94jvIs4xawFPURiB73GEELHufROqBQwPThWETrnTC0MwzdGB5r1KwKCtSPcV0V1zKd6pVEbjJjUvuE/9z5KaaSK8CwlHmMQcAlkYEpEmaY5bZ21gghsub9ukn/xcIhoERPi39ahnDya5thX+/+IyihGpRCIq3zMPkGKCqTokDRTv8tOK+6CMUlNbnnF95G4Kkar7lbbhxsHtElCsuVziBuoYt8n/l562uSx669+lkJ0X1w6yDPrsU9gWXkZQ8uozxKVdLIB2n0apQp8syqJ7I5atgyLnFYFnuIxW58D4evPdD5pO1d3DlCTA9DT8Df8kPRdIXNol4+skrTrP8YwMjvm3HZGusffseF0nNhOormhWdBSYIX89mu4uUus=",
          "retry.attempt1.acquirerAccount": "TestPmmAcquirerAccount",
          "threeDOffered": "false",
          "retry.attempt1.avsResultRaw": "2",
          "retry.attempt1.acquirer": "TestPmmAcquirer",
          "networkTxReference": "858435661128555",
          "authorisationMid": "1000",
          "acquirerAccountCode": "TestPmmAcquirerAccount",
          "cvcResult": "1 Matches",
          "retry.attempt1.responseCode": "Approved",
          "recurringProcessingModel": "Subscription",
          "threeDAuthenticated": "false",
          "retry.attempt1.rawResponse": "AUTHORISED"
        },
        "pspReference": "853623109930081E",
        "resultCode": "Authorised",
        "authCode": "034788"
      }
    RESPONSE
  end

  def successful_authorize_with_3ds_response
    '{"pspReference":"8835440446784145","resultCode":"RedirectShopper","issuerUrl":"https:\\/\\/test.adyen.com\\/hpp\\/3d\\/validate.shtml","md":"djIhcWk3MUhlVFlyQ1h2UC9NWmhpVm10Zz09IfIxi5eDMZgG72AUXy7PEU86esY68wr2cunaFo5VRyNPuWg3ZSvEIFuielSuoYol5WhjCH+R6EJTjVqY8eCTt+0wiqHd5btd82NstIc8idJuvg5OCu2j8dYo0Pg7nYxW\\/2vXV9Wy\\/RYvwR8tFfyZVC\\/U2028JuWtP2WxrBTqJ6nV2mDoX2chqMRSmX8xrL6VgiLoEfzCC\\/c+14r77+whHP0Mz96IGFf4BIA2Qo8wi2vrTlccH\\/zkLb5hevvV6QH3s9h0\\/JibcUrpoXH6M903ulGuikTr8oqVjEB9w8\\/WlUuxukHmqqXqAeOPA6gScehs6SpRm45PLpLysCfUricEIDhpPN1QCjjgw8+qVf3Ja1SzwfjCVocU","paRequest":"eNpVUctuwjAQ\\/BXaD2Dt4JCHFkspqVQOBChwriJnBanIAyepoF9fG5LS+jQz612PZ3F31ETxllSnSeKSmiY90CjPZs+h709cIZgQU88XXLjPEtfRO50lfpFu8qqUfMzGDsJATbtWx7RsJabq\\/LJIJHcmwp0i9BQL0otY7qhp10URqXOXa9IIdxnLtCC5jz6i+VO4rY2v7HSdr5ZOIBBuNVRVV7b6Kn3BEAaCnT7JY9vWIUDTt41VVSDYAsLD1bqzqDGDLnkmV\\/HhO9lt2DLesORTiSR+ZckmsmeGYG9glrYkHcZ97jB35PCQe6HrI9x0TAvrQO638cgkYRz1Atb2nehOuC38FdBEralUwy8GhnSpq5LMDRPpL0Z4mJ6\\/2WBVa7ISzj1azw+YQZ6N+FawU3ITCg9YcBtjCYJthX570G\\/ZoH\\/b\\/wFlSqpp"}'
  end

  def failed_authorize_response
    <<-RESPONSE
    {
      "pspReference": "8514775559925128",
      "refusalReason": "Expired Card",
      "resultCode": "Refused"
    }
    RESPONSE
  end

  def failed_authorize_3ds2_response
    <<-RESPONSE
    {
      "additionalData":
      {
        "threeds2.threeDS2Result.dsTransID": "1111-abc-234",
        "threeds2.threeDS2Result.eci":"07",
        "threeds2.threeDS2Result.threeDSServerTransID":"222-cde-321",
        "threeds2.threeDS2Result.transStatusReason":"01",
        "threeds2.threeDS2Result.messageVersion":"2.1.0",
        "threeds2.threeDS2Result.authenticationValue":"ABCDEFG",
        "threeds2.threeDS2Result.transStatus":"N"
       },
       "pspReference":"8514775559925128",
       "refusalReason":"3D Not Authenticated",
       "resultCode":"Refused"
     }
    RESPONSE
  end

  def failed_authorize_visa_response
    <<-RESPONSE
    {
      "additionalData":
      {
        "refusalReasonRaw": "01: Refer to card issuer"
       },
       "refusalReason": "Refused",
       "pspReference":"8514775559925128",
       "resultCode":"Refused"
     }
    RESPONSE
  end

  def failed_authorize_mastercard_response
    <<-RESPONSE
    {
      "additionalData":
      {
        "refusalReasonRaw": "01: Refer to card issuer",
        "merchantAdviceCode": "01 : New account information available"
       },
       "refusalReason": "Refused",
       "pspReference":"8514775559925128",
       "resultCode":"Refused"
     }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    {
      "pspReference": "8814775564188305",
      "response": "[capture-received]"
    }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
    {
      "status": 422,
      "errorCode": "167",
      "message": "Original pspReference required for this operation",
      "errorType": "validation"
    }
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    {
      "pspReference": "8514775559925128",
      "response": "[refund-received]"
    }
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
    {
      "status":422,
      "errorCode":"167",
      "message":"Original pspReference required for this operation",
      "errorType":"validation"
    }
    RESPONSE
  end

  def successful_credit_response
    <<-RESPONSE
    {
      "pspReference": "883614109029400G",
      "resultCode": "Received"
    }
    RESPONSE
  end

  def successful_payout_response
    <<-RESPONSE
    {
      "additionalData":
      {
        "liabilityShift": "false",
        "authCode": "081439",
        "avsResult": "0 Unknown",
        "retry.attempt1.acquirerAccount": "TestPmmAcquirerAccount",
        "threeDOffered": "false",
        "retry.attempt1.acquirer": "TestPmmAcquirer",
        "authorisationMid": "50",
        "acquirerAccountCode": "TestPmmAcquirerAccount",
        "cvcResult": "0 Unknown",
        "retry.attempt1.responseCode": "Approved",
        "threeDAuthenticated": "false",
        "retry.attempt1.rawResponse": "AUTHORISED"
      },
      "pspReference": "GMTN2VTQGJHKGK82",
      "resultCode": "Authorised",
      "authCode": "081439"
    }
    RESPONSE
  end

  def failed_credit_response
    <<-RESPONSE
    {
      "status":422,
      "errorCode":"130",
      "message":"Required field 'reference' is not provided.",
      "errorType":"validation"
    }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {
      "pspReference":"8614775821628806",
      "response":"[cancel-received]"
    }
    RESPONSE
  end

  def successful_cancel_or_refund_response
    <<-RESPONSE
    {
      "pspReference":"8614775821628806",
      "response":"[cancelOrRefund-received]"
    }
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
    {
      "status":422,
      "errorCode":"167",
      "message":"Original pspReference required for this operation",
      "errorType":"validation"
    }
    RESPONSE
  end

  def successful_adjust_response
    <<-RESPONSE
    {
      "pspReference": "8835544088660594",
      "response": "[adjustAuthorisation-received]"
    }
    RESPONSE
  end

  def failed_adjust_response
    <<-RESPONSE
    {
      "status":422,
      "errorCode":"167",
      "message":"Original pspReference required for this operation",
      "errorType":"validation"
    }
    RESPONSE
  end

  def successful_synchronous_adjust_response
    <<-RESPONSE
    {\"additionalData\":{\"authCode\":\"70125\",\"adjustAuthorisationData\":\"BQABAQA9NtGnJAkLXKqW1C+VUeCNMzDf4WwzLFBiuQ8iaA2Yvflz41t0cYxtA7XVzG2pzlJPMnkSK75k3eByNS0\\/m0\\/N2+NnnKv\\/9rYPn8Pjq1jc7CapczdqZNl8P9FwqtIa4Kdeq7ZBNeGalx9oH4reutlFggzWCr+4eYXMRqMgQNI2Bu5XvwkqBbXwbDL05CuNPjjEwO64YrCpVBLrxk4vlW4fvCLFR0u8O68C+Y4swmsPDvGUxWpRgwNVqXsTmvt9z8hlej21BErL8fPEy+fJP4Zab8oyfcLrv9FJkHZq03cyzJpOzqX458Ctn9sIwBawXzNEFN5bCt6eT1rgp0yuHeMGEGwrjNl8rijez7Rd\\/vy1WUYAAMfmZFuJMQ73l1+Hkr0VlHv6crlyP\\/FVTY\\/XIUiGMqa1yM08Zu\\/Gur5N7lU8qnMi2WO9QPyHmmdlfo7+AGsrKrzV4wY\\/wISg0pcv8PypBWVq\\/hYoCqlHsGUuIiyGLIW7A8LtG6\\/JqAA9t\\/0EdnQVz0k06IEEYnBzkQoY8Qv3cVszgPQukGstBraB47gQdVDp9vmuQjMstt8Te56SDRxtfcu0z4nQIURVSkJJNj8RYfwXH9OUbz3Vd2vwoR3lCJFTCKIeW8sidNVB3xAZnddBVQ3P\\/QxPnrrRdCcnoWSGoEOBBIxgF00XwNxJ4P7Xj1bB7oq3M7k99dgPnSdZIjyvG6BWKnCQcGyVRB0yOaYBaOCmN66EgWfXoJR5BA4Jo6gnWnESWV62iUC8OCzmis1VagfaBn0A9vWNcqKFkUr\\/68s3w8ixLJFy+WdpAS\\/flzC3bJbvy9YR9nESKAP40XiNGz9iBROCfPI2bSOvdFf831RdTxWaE+ewAC3w9GsgEKAXxzWsVeSODWRZQA0TEVOfX8SaNVa5w3EXLDsRVnmKgUH8yQnEJQBGhDJXg1sEbowE07CzzdAY5Mc=\",\"refusalReasonRaw\":\"AUTHORISED\"},\"pspReference\":\"8835574118820108\",\"response\":\"Authorised\"}
    RESPONSE
  end

  def failed_synchronous_adjust_response
    <<-RESPONSE
    {\"additionalData\":{\"authCode\":\"90745\",\"refusalReasonRaw\":\"2\"},\"pspReference\":\"8835574120337117\",\"response\":\"Refused\"}
    RESPONSE
  end

  def successful_verify_response
    <<-RESPONSE
    {
      "pspReference":"7914776426645103",
      "resultCode":"Authorised",
      "authCode":"31265"
    }
    RESPONSE
  end

  def failed_unknown_response
    <<~RESPONSE
      {
        "status": 422,
        "errorCode": "0",
        "message": "An unknown error occurred",
        "errorType": "validation"
      }
    RESPONSE
  end

  def failed_not_allowed_response
    <<~RESPONSE
      {
        "status": 422,
        "errorCode": "10",
        "message": "You are not allowed to perform this action",
        "errorType": "validation"
      }
    RESPONSE
  end

  def failed_invalid_amount_response
    <<~RESPONSE
      {
        "status": 422,
        "errorCode": "100",
        "message": "There is no amount specified in the request",
        "errorType": "validation"
      }
    RESPONSE
  end

  def failed_invalid_card_response
    <<~RESPONSE
      {
        "status": 422,
        "errorCode": "101",
        "message": "The specified card number is not valid",
        "errorType": "validation"
      }
    RESPONSE
  end

  def failed_cvc_validation_response
    <<~RESPONSE
      {
        "status": 422,
        "errorCode": "103",
        "message": "The length of the CVC code is not correct for the given card number",
        "errorType": "validation"
      }
    RESPONSE
  end

  def failed_billing_address_response
    <<~RESPONSE
      {
        "status": 422,
        "errorCode": "104",
        "message": "There was an error in the specified billing address fields",
        "errorType": "validation"
      }
    RESPONSE
  end

  def failed_billing_field_response
    <<~RESPONSE
      {
        "status": 422,
        "errorCode": "132",
        "message": "Required field 'billingAddress.street' is not provided.",
        "errorType": "validation"
      }
    RESPONSE
  end

  def failed_invalid_delivery_field_response
    <<~RESPONSE
      {
        "status": 500,
        "errorCode": "702",
        "message": "The 'deliveryDate' field is invalid. Invalid date (year)",
        "errorType": "validation"
      }
    RESPONSE
  end

  def failed_verify_response
    <<-RESPONSE
    {
      "pspReference":"7914776433387947",
      "refusalReason":"Refused",
      "resultCode":"Refused"
    }
    RESPONSE
  end

  def failed_authorize_avs_response
    <<-RESPONSE
    {\"additionalData\":{\"cvcResult\":\"0 Unknown\",\"fraudResultType\":\"GREEN\",\"avsResult\":\"3 AVS unavailable\",\"fraudManualReview\":\"false\",\"avsResultRaw\":\"U\",\"refusalReasonRaw\":\"05 : Do not honor\",\"authorisationMid\":\"494619000001174\",\"acquirerCode\":\"AdyenVisa_BR_494619\",\"acquirerReference\":\"802320302458\",\"acquirerAccountCode\":\"AdyenVisa_BR_Cabify\"},\"fraudResult\":{\"accountScore\":0,\"results\":[{\"FraudCheckResult\":{\"accountScore\":0,\"checkId\":46,\"name\":\"DistinctCountryUsageByShopper\"}}]},\"pspReference\":\"1715167376763498\",\"refusalReason\":\"Refused\",\"resultCode\":\"Refused\"}
    RESPONSE
  end

  def successful_tokenize_only_store_response
    <<-RESPONSE
    {"alias":"P481159492341538","aliasType":"Default","pspReference":"881574707964582B","recurringDetailReference":"8415747079647045","result":"Success"}
    RESPONSE
  end

  def successful_store_response
    <<-RESPONSE
    {"additionalData":{"recurring.recurringDetailReference":"8315202663743702","recurring.shopperReference":"John Smith"},"pspReference":"8835205392522157","resultCode":"Authorised","authCode":"94571"}
    RESPONSE
  end

  def failed_store_response
    <<-RESPONSE
    {"pspReference":"8835205393394754","refusalReason":"Refused","resultCode":"Refused"}
    RESPONSE
  end

  def successful_unstore_response
    <<-RESPONSE
    {"response":"[detail-successfully-disabled]"}
    RESPONSE
  end

  def failed_unstore_response
    <<-RESPONSE
    {"status":422,"errorCode":"800","message":"Contract not found","errorType":"validation"}
    RESPONSE
  end

  def extended_avs_response
    <<-RESPONSE
    {\"additionalData\":{\"cvcResult\":\"1 Matches\",\"cvcResultRaw\":\"Y\",\"avsResult\":\"20 Name, address and zip match\",\"avsResultRaw\":\"M\"}}
    RESPONSE
  end
end
