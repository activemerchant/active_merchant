require 'test_helper'

class WorldpayOnlinePaymentsTest < Test::Unit::TestCase
  def setup
    @gateway = WorldpayOnlinePaymentsGateway.new(
      client_key: "T_C_d2ddd160-379a-4ce3-9c69-01ad2299a78e",
      service_key: "T_S_0367c376-666f-45f2-ba3d-fc2a1879d966"
    )

    @credit_card = credit_card
    @amount = 1000

    @@credit_card = credit_card('4444333322221111')
    @options = {:order_id => 1}
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_token_response)
    #@gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'REPLACE', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(unsuccessful_token_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize
  end

  def test_failed_authorize
  end

  def test_successful_capture
  end

  def test_failed_capture
  end

  def test_successful_refund
  end

  def test_failed_refund
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

  def successful_token_response
    %({"token":"TEST_RU_1aaeb0c9-3447-45ae-8eb3-84ee5b92ca93","paymentMethod":{"type":"ObfuscatedCard","name":"hhh vvg","expiryMonth":10,"expiryYear":2016,"cardType":"UNKNOWN","maskedCardNumber":"**** **** **** 1111"},"reusable":false})
  end
  def unsuccessful_token_response
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
    %({"httpStatusCode"=>401, "customCode"=>"UNAUTHORIZED", "message"=>"Unauthorized Access", "description"=>"Request can't be authorized, please validate your request", "errorHelpUrl"=>nil, "originalRequest"=>"{'token':'TEST_RU_1aaeb0c9-3447-45ae-8eb3-84ee5b92ca93','orderDescription':'Order with token','amount':1200,'currencyCode':'EUR','name':'Shooper Name','customerIdentifiers':{'product-category':'fruits','product-quantity':'5','product-name':'orange'},'billingAddress':{'address1':'Address Line 1','address2':'Address Line 2','address3':'Address Line 3','postalCode':'EEEE','city':'City','state':'State','countryCode':'GB'},'customerOrderCode':'CustomerOrderCode','orderType':'ECOM'}"})
  end

  def failed_purchase_response
    %({"orderCode":"7cc1eed8-b555-454b-8579-44ba65d3878a","token":"TEST_RU_1aaeb0c9-3447-45ae-8eb3-84ee5b92ca93","orderDescription":"My test order","amount":1523,"currencyCode":"GBP","paymentStatus":"SUCCESS","paymentResponse":{"type":"ObfuscatedCard","name":"Example Name","expiryMonth":10,"expiryYear":2015,"cardType":"VISA_CREDIT","maskedCardNumber":"**** **** **** 1111","billingAddress":{"address1":"123 House Road","address2":"A village","address3":"","postalCode":"EC1 1AA","city":"London","state":"","countryCode":"GB"}},"customerOrderCode":"A123","customerIdentifiers":{ "my-customer-ref" : "customer-ref"},"environment":"TEST"})
  end

  def successful_authorize_response
  end

  def failed_authorize_response
  end

  def successful_capture_response
  end

  def failed_capture_response
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
