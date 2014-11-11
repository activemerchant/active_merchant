require 'test_helper'

class WorldpayOnlinePaymentsTest < Test::Unit::TestCase
  def setup
    @gateway = WorldpayOnlinePaymentsGateway.new(
      client_key: "T_C_fba10c60-5581-414c-aee7-358f150e6104",
      service_key: "T_S_e19c5313-e249-4beb-a6de-1f788882476c"
    )

    @amount = 1000

    @credit_card = credit_card('4444333322221111')
    @incredit_card = credit_card('4242424242424242')
    @options = {:order_id => 1}

    @token = "TEST_RU_f9de95c1-5cae-4cf2-b862-a20d60424b8c"
    @intoken = "_TEST_RU_f9de95c1-5cae-4cf2-b862-a20d60424b8c_"

    @orderCode = "7cc1eed8-b555-454b-8579-44ba65d3878a"
    @inorderCode = "_7cc1eed8-b555-454b-8579-44ba65d3878a_"
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_failure response
  end


  def test_successful_capture
    response = @gateway.capture(@amount, @token, @options)
    assert_success response

    assert_equal "SUCCESS", response.params["paymentStatus"]
    assert response.test?
  end
  def test_failed_capture
    response = @gateway.capture(@amount, @intoken, @options)
    assert_failure response

    assert_not_equal "200", response.params["httpStatusCode"]
    assert response.test?
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal "SUCCESS", response.params["paymentStatus"]
    assert response.test?
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @incredit_card, @options)
    assert_failure response

    assert_not_equal "200", response.params["httpStatusCode"]
    assert response.test?
  end

  def test_successful_refund
    response_purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response_purchase
    response = @gateway.refund(@amount, response_purchase.params["orderCode"], @options)
    assert_success response
  end

  def test_failed_refund
    response_purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response_purchase

    response = @gateway.refund(@amount, response_purchase.params["orderCode"]+"1", @options)
    assert_failure response
  end

  def test_successful_void
  end

  def test_failed_void
  end

  def test_successful_verify
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
  end

  private

  def successful_authorize_response
    %({"token":"TEST_RU_f9de95c1-5cae-4cf2-b862-a20d60424b8c","paymentMethod":{"type":"ObfuscatedCard","name":"hhh vvg","expiryMonth":10,"expiryYear":2016,"cardType":"UNKNOWN","maskedCardNumber":"**** **** **** 1111"},"reusable":false})
  end
  def failed_authorize_response
    ##unauthorised

    #%(
    #  {"httpStatusCode":401,"customCode":"UNAUTHORIZED","message":"Unauthorized Access","description":"Request can't be authorized, please validate your request","errorHelpUrl":null,"originalRequest":"{'reusable':false,'paymentMethod':{'type':'Card','name':'Example Name','expiryMonth':'**','expiryYear':'****','cardNumber':'**** **** **** 1111','cvc':'****'},'clientKey':'T_C_af8d409c-e21d-4dsfdfsdfsdfsdd201-90fd-c51b0b00a098'}"}
    #)

    ## bad request / cvc
    %(
    {"httpStatusCode":400,"customCode":"BAD_REQUEST","message":"CVC can't be null/empty","description":"Some of request parameters are invalid, please check your request. For more information please refer to Json schema.","errorHelpUrl":null,"originalRequest":"{'reusable':false,'paymentMethod':{'type':'Card','name':'Example Name','expiryMonth':'**','expiryYear':'****','cardNumber':'**** **** **** 1111','cvc':''},'clientKey':'T_C_845d39f4-f33c-430c-8fca-ad89bf1e5810'}"}
    )
  end

  def successful_purchase_response

  end

  def failed_purchase_response

  end

  def successful_capture_response
    %({"httpStatusCode"=>401, "customCode"=>"UNAUTHORIZED", "message"=>"Unauthorized Access", "description"=>"Request can't be authorized, please validate your request", "errorHelpUrl"=>nil, "originalRequest"=>"{'token':'TEST_RU_f9de95c1-5cae-4cf2-b862-a20d60424b8c','orderDescription':'Order with token','amount':1200,'currencyCode':'EUR','name':'Shooper Name','customerIdentifiers':{'product-category':'fruits','product-quantity':'5','product-name':'orange'},'billingAddress':{'address1':'Address Line 1','address2':'Address Line 2','address3':'Address Line 3','postalCode':'EEEE','city':'City','state':'State','countryCode':'GB'},'customerOrderCode':'CustomerOrderCode','orderType':'ECOM'}"})
  end

  def failed_capture_response
    %({"orderCode":"7cc1eed8-b555-454b-8579-44ba65d3878a","token":"TEST_RU_f9de95c1-5cae-4cf2-b862-a20d60424b8c","orderDescription":"My test order","amount":1523,"currencyCode":"GBP","paymentStatus":"SUCCESS","paymentResponse":{"type":"ObfuscatedCard","name":"Example Name","expiryMonth":10,"expiryYear":2015,"cardType":"VISA_CREDIT","maskedCardNumber":"**** **** **** 1111","billingAddress":{"address1":"123 House Road","address2":"A village","address3":"","postalCode":"EC1 1AA","city":"London","state":"","countryCode":"GB"}},"customerOrderCode":"A123","customerIdentifiers":{ "my-customer-ref" : "customer-ref"},"environment":"TEST"})
  end

  def successful_refund_response
  end

  def failed_refund_response
  end

  def successful_void_response
  end

  def failed_void_response
  end
end
