require 'test_helper'

class WorldpayOnlinePaymentsTest < Test::Unit::TestCase
  def setup
    @gateway = WorldpayOnlinePaymentsGateway.new(fixtures(:worldpay_online_payments))

    @amount = 1000
    @credit_card = credit_card('4444333322221111')
    @declined_card = credit_card('4242424242424242')
    @options = {
      order_id: '1',
      currency: 'GBP',
      billing_address: address,
      description: 'Test Purchase'
    }

    @token = "TEST_RU_8fcc4f2f-8c0d-483d-a0a3-eaad7356623e"
    @intoken = "_TEST_RU_8fcc4f2f-8c0d-483d-a0a3-eaad7356623e_"

    @orderCode = "e69b5445-2a46-4f2c-b67d-7e1e95bd00a5"
    @inorderCode = "_e69b5445-2a46-4f2c-b67d-7e1e95bd00a5_"
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    @gateway.expects(:ssl_request).returns(successful_token_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_not_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_and_capture
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    @gateway.expects(:ssl_request).returns(successful_token_response)
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    @gateway.expects(:ssl_request).returns(successful_capture_response)
    assert capture = @gateway.capture(@amount-1, authorize.authorization)
    assert_success capture
  end

  def test_failed_authorize_and_capture
    @gateway.expects(:ssl_request).returns(failed_authorize_response)
    authorize = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure authorize

    @gateway.expects(:ssl_request).returns(failed_capture_response)
    assert capture = @gateway.capture(@amount, authorize.authorization)
    assert_failure capture
    assert_not_equal 'SUCCESS', capture.message
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_partial_capture
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    @gateway.expects(:ssl_request).returns(successful_token_response)
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    @gateway.expects(:ssl_request).returns(successful_capture_response)
    assert capture = @gateway.capture(@amount-1, authorize.authorization)
    assert_success capture
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)
    response = @gateway.capture(nil, '')
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    @gateway.expects(:ssl_request).returns(successful_token_response)
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @gateway.expects(:ssl_request).returns(successful_refund_response)
    assert refund = @gateway.refund(nil, purchase.authorization)
    assert_success refund
    assert_match %r{SUCCESS}, refund.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)
    refund = @gateway.refund(nil, '')
    assert_failure refund
    assert_not_match %r{SUCCESS}, refund.message
  end

  def test_failed_double_refund
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    @gateway.expects(:ssl_request).returns(successful_token_response)
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @gateway.expects(:ssl_request).returns(failed_refund_response)
    assert refund = @gateway.refund(nil, purchase.authorization)
    assert_failure refund

    @gateway.expects(:ssl_request).returns(failed_refund_response)
    assert refund = @gateway.refund(nil, purchase.authorization)
    assert_failure refund
  end

  def test_failed_partial_refund
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    @gateway.expects(:ssl_request).returns(successful_token_response)
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @gateway.expects(:ssl_request).returns(failed_refund_response)
    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_failure refund
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    @gateway.expects(:ssl_request).returns(successful_token_response)
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    void = @gateway.void(authorize.authorization)
    assert_success void
  end

  def test_successful_order_void
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    @gateway.expects(:ssl_request).returns(successful_token_response)
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @gateway.expects(:ssl_request).returns(successful_void_response)
    void = @gateway.void(purchase.authorization)
    assert_success void
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)
    void = @gateway.void('InvalidOrderCode')
    assert_failure void
  end

  def test_failed_double_void
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    @gateway.expects(:ssl_request).returns(successful_token_response)
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    @gateway.expects(:ssl_request).returns(successful_void_response)
    void = @gateway.void(authorize.authorization)
    assert_success void

    @gateway.expects(:ssl_request).returns(failed_void_response)
    void = @gateway.void(authorize.authorization)
    assert_failure void
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    @gateway.expects(:ssl_request).returns(successful_token_response)
    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_request).returns(failed_authorize_response)
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
  end

  def test_invalid_login
    badgateway = WorldpayOnlinePaymentsGateway.new(
      client_key: "T_C_NOT_VALID",
      service_key: "T_S_NOT_VALID"
    )

    badgateway.expects(:ssl_request).returns(failed_login_response)
    response = badgateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  private

  def successful_token_response
    %({"token": "TEST_RU_8fcc4f2f-8c0d-483d-a0a3-eaad7356623e","paymentMethod": {"type": "ObfuscatedCard","name": "Longbob Longsen","expiryMonth": 10,"expiryYear": 2016,"cardType": "VISA","maskedCardNumber": "**** **** **** 1111"},"reusable": true})
  end
  def successful_authorize_response
    %({"orderCode": "a46502d0-80ba-425b-a6db-2c57e9de91da","token": "TEST_RU_8fcc4f2f-8c0d-483d-a0a3-eaad7356623e","orderDescription": "Test Purchase","amount": 0,"currencyCode": "GBP","authorizeOnly": true,"paymentStatus": "AUTHORIZED","paymentResponse": {"type": "ObfuscatedCard","name": "Longbob Longsen","expiryMonth": 10,"expiryYear": 2016,"cardType": "VISA_CREDIT","maskedCardNumber": "**** **** **** 1111"},"environment": "TEST","authorizedAmount": 1000})
  end
  def failed_authorize_response
    %({"httpStatusCode":400,"customCode":"BAD_REQUEST","message":"CVC can't be null/empty","description":"Some of request parameters are invalid, please check your request. For more information please refer to Json schema.","errorHelpUrl":null,"originalRequest":"{'reusable':false,'paymentMethod':{'type':'Card','name':'Example Name','expiryMonth':'**','expiryYear':'****','cardNumber':'**** **** **** 1111','cvc':''},'clientKey':'T_C_845d39f4-f33c-430c-8fca-ad89bf1e5810'}"}    )
  end

  def successful_purchase_response
    %({"orderCode": "0f2e0901-6de9-4bcc-85ec-832f4f62ca36","token": "TEST_RU_8fcc4f2f-8c0d-483d-a0a3-eaad7356623e","orderDescription": "Test Purchase","amount": 1000,"currencyCode": "GBP","paymentStatus": "SUCCESS","paymentResponse": {"type": "ObfuscatedCard","name": "Longbob Longsen","expiryMonth": 10,"expiryYear": 2016,"cardType": "VISA_CREDIT","maskedCardNumber": "**** **** **** 1111"},"environment": "TEST"})
  end

  def failed_purchase_response
    %({"httpStatusCode": 401,"customCode": "UNAUTHORIZED","message": "Unauthorized Access","description": "Request can't be authorized, please validate your request","errorHelpUrl": null,"originalRequest": "{'token':'TEST_RU_8fcc4f2f-8c0d-483d-a0a3-eaad7356623e','orderDescription':'Test Purchase','amount':1000,'currencyCode':'GBP','name':'Longbob Longsen','billingAddress':{'address1':'address1','address2':'address2','address3':'address3','postalCode':'EEEE','city':'City','state':'State','countryCode':'GB'}}"})
  end

  def successful_capture_response
    %({"orderCode": "a46502d0-80ba-425b-a6db-2c57e9de91da","token": "TEST_RU_8fcc4f2f-8c0d-483d-a0a3-eaad7356623e","orderDescription": "Test Purchase","amount": 999,"currencyCode": "GBP","authorizeOnly": true,"paymentStatus": "SUCCESS","paymentResponse": {"type": "ObfuscatedCard","name": "Longbob Longsen","expiryMonth": 10,"expiryYear": 2016,"cardType": "VISA_CREDIT","maskedCardNumber": "**** **** **** 1111"},"environment": "TEST","authorizedAmount": 1000})
  end

  def failed_capture_response
    %({"httpStatusCode": 404,"customCode": "ORDER_NOT_FOUND","message": "Order with Order Code: 33ce1213-df9f-497e-aee8-b93f48865daa4c not found","description": "Order Code used with request does not exist, please check the orderCode.","errorHelpUrl": null,"originalRequest": "{'captureAmount':1000}"})
  end

  def successful_refund_response
  end

  def failed_refund_response
    %({"httpStatusCode": 400,"customCode": "BAD_REQUEST","message": "TEST Order: 8d5b48ed-71e8-475a-a648-245b011e5527 with state: REFUNDED cannot be Refunded","description": "Some of request parameters are invalid, please check your request. For more information please refer to Json schema.","errorHelpUrl": null,"originalRequest": "{}"})
  end

  def successful_void_response
  end

  def failed_void_response
    %({"httpStatusCode": 404,"customCode": "ORDER_NOT_FOUND","message": "Order with Order Code: InvalidOrderCode not found","description": "Order Code used with request does not exist, please check the orderCode.","errorHelpUrl": null,"originalRequest": "{'refundAmount':5}"})
  end

  def successful_verify_response
  end

  def failed_verify_response
    %({"httpStatusCode": 404,"customCode": "ORDER_NOT_FOUND","message": "Order with Order Code: InvalidOrderCode not found","description": "Order Code used with request does not exist, please check the orderCode.","errorHelpUrl": null,"originalRequest": "{'refundAmount':5}"})
  end

  def failed_login_response
    %({"httpStatusCode": 401,"customCode": "UNAUTHORIZED","message": "Unauthorized Access","description": "Request can't be authorized, please validate your request","errorHelpUrl": null,"originalRequest": "{'token':'TEST_RU_ba2497be-8140-4be7-89ec-fa24eb6b01e8','orderDescription':'Test Purchase','amount':1000,'currencyCode':'GBP','name':'Longbob Longsen','billingAddress':{'address1':'address1','address2':'address2','address3':'address3','postalCode':'EEEE','city':'City','state':'State','countryCode':'GB'}}"})
  end
end
