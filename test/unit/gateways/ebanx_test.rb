require 'test_helper'

class EbanxTest < Test::Unit::TestCase
  def setup
    @gateway = EbanxGateway.new(integration_key: 'key')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '592db57ad6933455efbb62a48d1dfa091dd7cd092109db99', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "NOK", response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '592dc02dbe421478a132bf5c2ecfe52c86ac01b454ae799b', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "NOK", response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway.capture(@amount, "authorization", @options)
    assert_success response

    assert_equal 'Sandbox - Test credit card, transaction captured', response.message
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, "", @options)
    assert_failure response
    assert_equal "BP-CAP-1", response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    response = @gateway.refund(@amount, "authorization", @options)
    assert_success response

    assert_equal '59306246f2a0c5f327a15dd6492687e197aca7eda179da08', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    response = @gateway.refund(@amount, "", @options)
    assert_failure response
    assert_equal "BP-REF-CAN-2", response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)

    response = @gateway.void("authorization", @options)
    assert_success response

    assert_equal '5930629dde0899dc53b3557ea9887aa8f3d264a91d115d40', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void("", @options)
    assert_failure response
    assert_equal "BP-CAN-1", response.error_code
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).times(2).returns(successful_authorize_response, successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal nil, response.error_code
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_request).times(2).returns(successful_authorize_response, failed_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal nil, response.error_code
  end

  def test_failed_verify
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal "NOK", response.error_code
  end

  def test_successful_store_and_purchase
    @gateway.expects(:ssl_request).returns(successful_store_response)

    store = @gateway.store(@credit_card, @options)
    assert_success store
    assert_equal 'a61a7c98535718801395991b5112f888d359c2d632e2c3bb8afe75aa23f3334d7fd8dc57d7721f8162503773063de59ee85901b5714a92338c6d9c0352aee78c|visa', store.authorization

    @gateway.expects(:ssl_request).returns(successful_purchase_with_stored_card_response)

    response = @gateway.purchase(@amount, store.authorization, @options)
    assert_success response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      request_body={\"integration_key\":\"1231000\",\"operation\":\"request\",\"payment\":{\"amount_total\":\"1.00\",\"currency_code\":\"USD\",\"merchant_payment_code\":\"2bed75b060e936834e354d944aeaa892\",\"name\":\"Longbob Longsen\",\"email\":\"unspecified@example.com\",\"document\":\"853.513.468-93\",\"payment_type_code\":\"visa\",\"creditcard\":{\"card_number\":\"4111111111111111\",\"card_name\":\"Longbob Longsen\",\"card_due_date\":\"9/2018\",\"card_cvv\":\"123\"},\"address\":\"Rua E\",\"street_number\":\"1040\",\"city\":\"Maracana\u{fa}\",\"state\":\"CE\",\"zipcode\":\"61919-230\",\"country\":\"BR\",\"phone_number\":\"(555)555-5555\"}}
    )
  end

  def post_scrubbed
    %q(
      request_body={\"integration_key\":\"[FILTERED]\",\"operation\":\"request\",\"payment\":{\"amount_total\":\"1.00\",\"currency_code\":\"USD\",\"merchant_payment_code\":\"2bed75b060e936834e354d944aeaa892\",\"name\":\"Longbob Longsen\",\"email\":\"unspecified@example.com\",\"document\":\"853.513.468-93\",\"payment_type_code\":\"visa\",\"creditcard\":{\"card_number\":\"[FILTERED]\",\"card_name\":\"Longbob Longsen\",\"card_due_date\":\"9/2018\",\"card_cvv\":\"[FILTERED]\"},\"address\":\"Rua E\",\"street_number\":\"1040\",\"city\":\"Maracana\u{fa}\",\"state\":\"CE\",\"zipcode\":\"61919-230\",\"country\":\"BR\",\"phone_number\":\"(555)555-5555\"}}
    )
  end

  def successful_purchase_response
    %(
      {"payment":{"hash":"592db57ad6933455efbb62a48d1dfa091dd7cd092109db99","pin":"081043552","merchant_payment_code":"ca2251ed6ac582162b17d77dfd7fb98a","order_number":null,"status":"CO","status_date":"2017-05-30 15:10:01","open_date":"2017-05-30 15:10:01","confirm_date":"2017-05-30 15:10:01","transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-06-02","instalments":"1","payment_type_code":"visa","transaction_status":{"acquirer":"EBANX","code":"OK","description":"Sandbox - Test credit card, transaction captured"},"pre_approved":true,"capture_available":false,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"status":"SUCCESS"}
    )
  end

  def failed_purchase_response
    %(
      {"payment":{"hash":"592dd2f17965cd3d7a17e71a3fe943b8363c72d60caffacc","pin":"655998606","merchant_payment_code":"e71e467805aef9064599bc5a76e98e23","order_number":null,"status":"CA","status_date":"2017-05-30 17:15:45","open_date":"2017-05-30 17:15:45","confirm_date":null,"transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-06-02","instalments":"1","payment_type_code":"visa","transaction_status":{"acquirer":"EBANX","code":"NOK","description":"Sandbox - Test credit card, transaction declined reason insufficientFunds"},"pre_approved":false,"capture_available":false,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"status":"SUCCESS"}
    )
  end

  def successful_authorize_response
    %(
      {"payment":{"hash":"592dc02dbe421478a132bf5c2ecfe52c86ac01b454ae799b","pin":"296389224","merchant_payment_code":"8e5c943c3c93adbed8d8a7347ca333fe","order_number":null,"status":"PE","status_date":null,"open_date":"2017-05-30 15:55:40","confirm_date":null,"transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-06-02","instalments":"1","payment_type_code":"visa","transaction_status":{"acquirer":"EBANX","code":"OK","description":"Sandbox - Test credit card, transaction will be approved"},"pre_approved":true,"capture_available":true,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"status":"SUCCESS"}
    )
  end

  def failed_authorize_response
    %(
      {"payment":{"hash":"592dd2146d5b8a27924daaa0f0248d8c582cb2ce6b67495e","pin":"467618452","merchant_payment_code":"7883bdbbdfa961ce753247fbeb4ff99d","order_number":null,"status":"CA","status_date":"2017-05-30 17:12:03","open_date":"2017-05-30 17:12:03","confirm_date":null,"transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-06-02","instalments":"1","payment_type_code":"visa","transaction_status":{"acquirer":"EBANX","code":"NOK","description":"Sandbox - Test credit card, transaction declined reason insufficientFunds"},"pre_approved":false,"capture_available":false,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"status":"SUCCESS"}
    )
  end

  def successful_capture_response
    %(
      {"payment":{"hash":"592dd65824427e4f5f50564c118f399869637bfb30d54f5b","pin":"081043654","merchant_payment_code":"8424e3000d64d056fbd58639957dc1c4","order_number":null,"status":"CO","status_date":"2017-05-30 17:30:16","open_date":"2017-05-30 17:30:15","confirm_date":"2017-05-30 17:30:16","transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-06-02","instalments":"1","payment_type_code":"visa","transaction_status":{"acquirer":"EBANX","code":"OK","description":"Sandbox - Test credit card, transaction captured"},"pre_approved":true,"capture_available":false,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"status":"SUCCESS"}
    )
  end

  def failed_capture_response
    %(
      {"status":"ERROR","status_code":"BP-CAP-1","status_message":"Parameters hash or merchant_payment_code not informed"}
    )
  end

  def successful_refund_response
    %(
      {"payment":{"hash":"59306246f2a0c5f327a15dd6492687e197aca7eda179da08","pin":"446189033","merchant_payment_code":"b5e1f7298f8fa645e8a903fbdc5ce44a","order_number":null,"status":"CO","status_date":"2017-06-01 15:51:49","open_date":"2017-06-01 15:51:49","confirm_date":"2017-06-01 15:51:49","transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-06-04","instalments":"1","payment_type_code":"visa","transaction_status":{"acquirer":"EBANX","code":"OK","description":"Sandbox - Test credit card, transaction captured"},"pre_approved":true,"capture_available":false,"refunds":[{"id":"20739","merchant_refund_code":null,"status":"RE","request_date":"2017-06-01 15:51:50","pending_date":null,"confirm_date":null,"cancel_date":null,"amount_ext":"1.00","description":"full refund"}],"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"refund":{"id":"20739","merchant_refund_code":null,"status":"RE","request_date":"2017-06-01 15:51:50","pending_date":null,"confirm_date":null,"cancel_date":null,"amount_ext":"1.00","description":"full refund"},"operation":"refund","status":"SUCCESS"}
    )
  end

  def failed_refund_response
    %(
      {"status":"ERROR","status_code":"BP-REF-CAN-2","status_message":"Payment not found with this hash: "}
    )
  end

  def successful_void_response
    %(
      {"payment":{"hash":"5930629dde0899dc53b3557ea9887aa8f3d264a91d115d40","pin":"465556618","merchant_payment_code":"8b97c49aecffbb309dadd08c87ccbdd0","order_number":null,"status":"CA","status_date":"2017-06-01 15:53:18","open_date":"2017-06-01 15:53:17","confirm_date":null,"transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-06-04","instalments":"1","payment_type_code":"visa","transaction_status":{"acquirer":"EBANX","code":"NOK","description":"Sandbox - Test credit card, transaction cancelled"},"pre_approved":false,"capture_available":false,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"operation":"cancel","status":"SUCCESS"}
    )
  end

  def failed_void_response
    %(
      {"status":"ERROR","status_code":"BP-CAN-1","status_message":"Parameter hash not informed"}
    )
  end

  def successful_store_response
    %(
      {"status":"SUCCESS","payment_type_code":"visa","token":"a61a7c98535718801395991b5112f888d359c2d632e2c3bb8afe75aa23f3334d7fd8dc57d7721f8162503773063de59ee85901b5714a92338c6d9c0352aee78c","masked_card_number":"411111xxxxxx1111"}
    )
  end

  def successful_purchase_with_stored_card_response
    %(
      {"payment":{"hash":"59d3e2955021c5e2b180e1ea9670e2d9675c15453a2ab346","pin":"252076123","merchant_payment_code":"a942f8a68836e888fa8e8af1e8ca4bf2","order_number":null,"status":"CO","status_date":"2017-10-03 19:18:45","open_date":"2017-10-03 19:18:44","confirm_date":"2017-10-03 19:18:45","transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-10-06","instalments":"1","payment_type_code":"visa","details":{"billing_descriptor":""},"transaction_status":{"acquirer":"EBANX","code":"OK","description":"Accepted"},"pre_approved":true,"capture_available":false,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"NOT PROVIDED","birth_date":null}},"status":"SUCCESS"}
    )
  end
end
