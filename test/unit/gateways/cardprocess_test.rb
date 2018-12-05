require 'test_helper'

class CardprocessTest < Test::Unit::TestCase
  def setup
    @gateway = CardprocessGateway.new(user_id: 'login', password: 'password', entity_id: '123')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '8a8294495fe8084a016002dd17c163fd', response.authorization
    assert_equal 'DB', response.params['paymentType']
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:incorrect_number], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '8a82944a5fe82704016002caa42c14f8', response.authorization
    assert_equal 'PA', response.params['paymentType']
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'PA', response.params['paymentType']
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, '123', @options)
    assert_success response

    assert_equal '8a82944a5fe82704016002caa7cd1513', response.authorization
    assert_equal 'CP', response.params['paymentType']
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, '123', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, '123', @options)
    assert_success response

    assert_equal '8a82944a5fe82704016002cc88f61731', response.authorization
    assert_equal 'RF', response.params['paymentType']
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, '123', @options)
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('123')
    assert_success response

    assert_equal '8a8294495fe8084a016002cc489446d6', response.authorization
    assert_equal 'RV', response.params['paymentType']
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('123')
    assert_failure response
  end

  def test_successful_verify
    @gateway.stubs(:ssl_post).returns(successful_authorize_response, successful_capture_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_successful_verify_with_failed_void
    @gateway.stubs(:ssl_post).returns(successful_authorize_response, failed_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_general_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response

    assert_equal '8a8294495fe8084a01600332a83d4899', response.authorization
    assert_equal 'CD', response.params['paymentType']
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_error_code_parsing
    codes = {
      '000.000.000' => nil,
      '100.100.101' => :incorrect_number,
      '100.100.303' => :expired_card,
      '100.100.305' => :invalid_expiry_date,
      '100.100.600' => :invalid_cvc,
      '200.222.222' => :config_error,
      '700.777.777' => :config_error,
      '800.800.101' => :card_declined,
      '800.800.102' => :incorrect_address,
      '800.800.302' => :incorrect_address,
      '800.800.150' => :card_declined,
      '800.100.151' => :invalid_number,
      '800.100.152' => :card_declined,
      '800.100.153' => :incorrect_cvc,
      '800.100.154' => :card_declined,
      '800.800.202' => :invalid_zip
    }
    codes.each_pair do |code, key|
      response = {'result' => {'code' => code}}
      assert_equal Gateway::STANDARD_ERROR_CODE[key], @gateway.send(:error_code_from, response), "expecting #{code} => #{key}"
    end
  end

  private

  def pre_scrubbed
    %q(
opening connection to test.vr-pay-ecommerce.de:443...
opened
starting SSL for test.vr-pay-ecommerce.de:443...
SSL established
<- "POST /v1/payments HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: test.vr-pay-ecommerce.de\r\nContent-Length: 447\r\n\r\n"
<- "amount=1.00&currency=EUR&paymentBrand=VISA&card.number=4200000000000000&card.holder=Longbob+Longsen&card.expiryMonth=09&card.expiryYear=2018&card.cvv=123&billing.street1=456+My+Street&billing.street2=Apt+1&billing.city=Ottawa&billing.state=ON&billing.postcode=K1C2N6&billing.country=CA&authentication.userId=8a8294174e735d0c014e78beb6c5154f&authentication.password=cTZjAm9c87&authentication.entityId=8a8294174e735d0c014e78beb6b9154b&paymentType=DB"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Mon, 27 Nov 2017 21:40:52 GMT\r\n"
-> "Server: Apache-Coyote/1.1\r\n"
-> "Strict-Transport-Security: max-age=63072000; includeSubdomains; preload\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "X-XSS-Protection: 1; mode=block\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Access-Control-Allow-Credentials: true\r\n"
-> "X-Application-WAF-Action: allow\r\n"
-> "Content-Type: application/json;charset=UTF-8\r\n"
-> "Content-Length: 725\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 725 bytes...
-> ""
-> "{\"id\":\"8a82944a5fe82704015fff6cf5e572b4\",\"paymentType\":\"DB\",\"paymentBrand\":\"VISA\",\"amount\":\"1.00\",\"currency\":\"EUR\",\"descriptor\":\"5901.3583.3250 OPP_Channel \",\"result\":{\"code\":\"000.100.110\",\"description\":\"Request successfully processed in 'Merchant in Integrator Test Mode'\"},\"card\":{\"bin\":\"420000\",\"last4Digits\":\"0000\",\"holder\":\"Longbob Longsen\",\"expiryMonth\":\"09\",\"expiryYear\":\"2018\"},\"billing\":{\"street1\":\"456 My Street\",\"street2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"postcode\":\"K1C2N6\",\"country\":\"CA\"},\"risk\":{\"score\":\"100\"},\"buildNumber\":\"a89317e58e01406de09ff75de6c962f2365f66e9@2017-11-27 15:38:09 +0000\",\"timestamp\":\"2017-11-27 21:40:51+0000\",\"ndc\":\"8a8294174e735d0c014e78beb6b9154b_24979bbf8c3a424cbd25e59860bb5417\"}"
read 725 bytes
Conn close
    )
  end

  def post_scrubbed
    %q(
opening connection to test.vr-pay-ecommerce.de:443...
opened
starting SSL for test.vr-pay-ecommerce.de:443...
SSL established
<- "POST /v1/payments HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: test.vr-pay-ecommerce.de\r\nContent-Length: 447\r\n\r\n"
<- "amount=1.00&currency=EUR&paymentBrand=VISA&card.number=[FILTERED]&card.holder=Longbob+Longsen&card.expiryMonth=09&card.expiryYear=2018&card.cvv=[FILTERED]&billing.street1=456+My+Street&billing.street2=Apt+1&billing.city=Ottawa&billing.state=ON&billing.postcode=K1C2N6&billing.country=CA&authentication.userId=[FILTERED]&authentication.password=[FILTERED]&authentication.entityId=[FILTERED]&paymentType=DB"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Mon, 27 Nov 2017 21:40:52 GMT\r\n"
-> "Server: Apache-Coyote/1.1\r\n"
-> "Strict-Transport-Security: max-age=63072000; includeSubdomains; preload\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "X-XSS-Protection: 1; mode=block\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Access-Control-Allow-Credentials: true\r\n"
-> "X-Application-WAF-Action: allow\r\n"
-> "Content-Type: application/json;charset=UTF-8\r\n"
-> "Content-Length: 725\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 725 bytes...
-> ""
-> "{\"id\":\"8a82944a5fe82704015fff6cf5e572b4\",\"paymentType\":\"DB\",\"paymentBrand\":\"VISA\",\"amount\":\"1.00\",\"currency\":\"EUR\",\"descriptor\":\"5901.3583.3250 OPP_Channel \",\"result\":{\"code\":\"000.100.110\",\"description\":\"Request successfully processed in 'Merchant in Integrator Test Mode'\"},\"card\":{\"bin\":\"420000\",\"last4Digits\":\"0000\",\"holder\":\"Longbob Longsen\",\"expiryMonth\":\"09\",\"expiryYear\":\"2018\"},\"billing\":{\"street1\":\"456 My Street\",\"street2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"postcode\":\"K1C2N6\",\"country\":\"CA\"},\"risk\":{\"score\":\"100\"},\"buildNumber\":\"a89317e58e01406de09ff75de6c962f2365f66e9@2017-11-27 15:38:09 +0000\",\"timestamp\":\"2017-11-27 21:40:51+0000\",\"ndc\":\"8a8294174e735d0c014e78beb6b9154b_24979bbf8c3a424cbd25e59860bb5417\"}"
read 725 bytes
Conn close
    )
  end

  def successful_purchase_response
    "{\"id\":\"8a8294495fe8084a016002dd17c163fd\",\"paymentType\":\"DB\",\"paymentBrand\":\"VISA\",\"amount\":\"1.00\",\"currency\":\"EUR\",\"descriptor\":\"0177.7272.0802 OPP_Channel \",\"result\":{\"code\":\"000.100.110\",\"description\":\"Request successfully processed in 'Merchant in Integrator Test Mode'\"},\"card\":{\"bin\":\"420000\",\"last4Digits\":\"0000\",\"holder\":\"Longbob Longsen\",\"expiryMonth\":\"09\",\"expiryYear\":\"2018\"},\"billing\":{\"street1\":\"456 My Street\",\"street2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"postcode\":\"K1C2N6\",\"country\":\"CA\"},\"risk\":{\"score\":\"100\"},\"buildNumber\":\"a89317e58e01406de09ff75de6c962f2365f66e9@2017-11-27 15:38:09 +0000\",\"timestamp\":\"2017-11-28 13:42:12+0000\",\"ndc\":\"8a8294174e735d0c014e78beb6b9154b_ed9f9af4170942719cf6e3446f823f45\"}"
  end

  def failed_purchase_response
    '{"id":"8a82944a5fe827040160030a3308412d","paymentType":"DB","paymentBrand":"VISA","result":{"code":"100.100.101","description":"invalid creditcard, bank account number or bank name"},"card":{"bin":"420000","last4Digits":"0001","holder":"Longbob Longsen","expiryMonth":"09","expiryYear":"2018"},"billing":{"street1":"456 My Street","street2":"Apt 1","city":"Ottawa","state":"ON","postcode":"K1C2N6","country":"CA"},"buildNumber":"a89317e58e01406de09ff75de6c962f2365f66e9@2017-11-27 15:38:09 +0000","timestamp":"2017-11-28 14:31:28+0000","ndc":"8a8294174e735d0c014e78beb6b9154b_43d463600f8d429ea6ac09cf25fd9f24"}'
  end

  def successful_authorize_response
    "{\"id\":\"8a82944a5fe82704016002caa42c14f8\",\"paymentType\":\"PA\",\"paymentBrand\":\"VISA\",\"amount\":\"1.00\",\"currency\":\"EUR\",\"descriptor\":\"8374.4038.5698 OPP_Channel \",\"result\":{\"code\":\"000.100.110\",\"description\":\"Request successfully processed in 'Merchant in Integrator Test Mode'\"},\"card\":{\"bin\":\"420000\",\"last4Digits\":\"0000\",\"holder\":\"Longbob Longsen\",\"expiryMonth\":\"09\",\"expiryYear\":\"2018\"},\"billing\":{\"street1\":\"456 My Street\",\"street2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"postcode\":\"K1C2N6\",\"country\":\"CA\"},\"risk\":{\"score\":\"100\"},\"buildNumber\":\"a89317e58e01406de09ff75de6c962f2365f66e9@2017-11-27 15:38:09 +0000\",\"timestamp\":\"2017-11-28 13:22:03+0000\",\"ndc\":\"8a8294174e735d0c014e78beb6b9154b_fc59650eafc84da29ce10e7171e71a34\"}"
  end

  def failed_authorize_response
    '{"paymentType":"PA","paymentBrand":"VISA","result":{"code":"800.100.151","description":"transaction declined (invalid card)"},"card":{"bin":"420000","last4Digits":"0000","holder":"Longbob Longsen","expiryMonth":"09","expiryYear":"2018"},"billing":{"street1":"456 My Street","street2":"Apt 1","city":"Ottawa","state":"ON","postcode":"K1C2N6","country":"CA"},"customParameters":{"forceResultCode":"800.100.151"},"buildNumber":"a89317e58e01406de09ff75de6c962f2365f66e9@2017-11-27 15:38:09 +0000","timestamp":"2017-11-28 13:50:31+0000","ndc":"8a8294174e735d0c014e78beb6b9154b_1077c67bc41048ff887da9ab9ee8b89d"}'
  end

  def successful_capture_response
    "{\"id\":\"8a82944a5fe82704016002caa7cd1513\",\"paymentType\":\"CP\",\"amount\":\"1.00\",\"currency\":\"EUR\",\"descriptor\":\"4938.4300.2018 OPP_Channel\",\"result\":{\"code\":\"000.100.110\",\"description\":\"Request successfully processed in 'Merchant in Integrator Test Mode'\"},\"risk\":{\"score\":\"0\"},\"buildNumber\":\"a89317e58e01406de09ff75de6c962f2365f66e9@2017-11-27 15:38:09 +0000\",\"timestamp\":\"2017-11-28 13:22:03+0000\",\"ndc\":\"8a8294174e735d0c014e78beb6b9154b_fb956c7668a04e18af61519693a1d114\"}"
  end

  def failed_capture_response
    '{"id":"8a82944a5fe8270401600313d3965bca","paymentType":"CP","result":{"code":"700.400.510","description":"capture needs at least one successful transaction of type (PA)"},"risk":{"score":"0"},"buildNumber":"a89317e58e01406de09ff75de6c962f2365f66e9@2017-11-27 15:38:09 +0000","timestamp":"2017-11-28 14:41:59+0000","ndc":"8a8294174e735d0c014e78beb6b9154b_8abfd898a6cd406f94181d9096607aea"}'
  end

  def successful_refund_response
    "{\"id\":\"8a82944a5fe82704016002cc88f61731\",\"paymentType\":\"RF\",\"amount\":\"1.00\",\"currency\":\"EUR\",\"descriptor\":\"3478.1411.3954 OPP_Channel\",\"result\":{\"code\":\"000.100.110\",\"description\":\"Request successfully processed in 'Merchant in Integrator Test Mode'\"},\"buildNumber\":\"a89317e58e01406de09ff75de6c962f2365f66e9@2017-11-27 15:38:09 +0000\",\"timestamp\":\"2017-11-28 13:24:07+0000\",\"ndc\":\"8a8294174e735d0c014e78beb6b9154b_99293f4fffe64105870e77b8e18c0c02\"}"
  end

  def failed_refund_response
    '{"result":{"code":"200.300.404","description":"invalid or missing parameter","parameterErrors":[{"name":"paymentType","value":"RF","message":"must be one of [PA, DB, CD, PA.CP]"},{"name":"paymentBrand","value":null,"message":"card properties must be set"}]},"buildNumber":"a89317e58e01406de09ff75de6c962f2365f66e9@2017-11-27 15:38:09 +0000","timestamp":"2017-11-28 14:33:31+0000","ndc":"8a8294174e735d0c014e78beb6b9154b_febee8f6863b4392b064b23602f3f382"}'
  end

  def successful_void_response
    "{\"id\":\"8a8294495fe8084a016002cc489446d6\",\"paymentType\":\"RV\",\"amount\":\"1.00\",\"currency\":\"EUR\",\"descriptor\":\"9673.6314.6402 OPP_Channel\",\"result\":{\"code\":\"000.100.110\",\"description\":\"Request successfully processed in 'Merchant in Integrator Test Mode'\"},\"risk\":{\"score\":\"0\"},\"buildNumber\":\"a89317e58e01406de09ff75de6c962f2365f66e9@2017-11-27 15:38:09 +0000\",\"timestamp\":\"2017-11-28 13:23:50+0000\",\"ndc\":\"8a8294174e735d0c014e78beb6b9154b_744a5416960a420da01edc3b3daf6c6f\"}"
  end

  def failed_void_response
    '{"result":{"code":"200.300.404","description":"invalid or missing parameter","parameterErrors":[{"name":"paymentBrand","value":null,"message":"card properties must be set"},{"name":"paymentType","value":"RV","message":"must be one of [PA, DB, CD, PA.CP]"},{"name":"amount","value":null,"message":"may not be empty"},{"name":"currency","value":null,"message":"may not be empty"}]},"buildNumber":"a89317e58e01406de09ff75de6c962f2365f66e9@2017-11-27 15:38:09 +0000","timestamp":"2017-11-28 14:34:50+0000","ndc":"8a8294174e735d0c014e78beb6b9154b_4a909e0b99214eb9b155b46a2c67df30"}'
  end

  def successful_credit_response
    "{\"id\":\"8a8294495fe8084a01600332a83d4899\",\"paymentType\":\"CD\",\"paymentBrand\":\"VISA\",\"amount\":\"1.00\",\"currency\":\"EUR\",\"descriptor\":\"2299.3739.4338 OPP_Channel \",\"result\":{\"code\":\"000.100.110\",\"description\":\"Request successfully processed in 'Merchant in Integrator Test Mode'\"},\"card\":{\"bin\":\"420000\",\"last4Digits\":\"0000\",\"holder\":\"Longbob Longsen\",\"expiryMonth\":\"09\",\"expiryYear\":\"2018\"},\"billing\":{\"street1\":\"456 My Street\",\"street2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"postcode\":\"K1C2N6\",\"country\":\"CA\"},\"risk\":{\"score\":\"100\"},\"buildNumber\":\"a89317e58e01406de09ff75de6c962f2365f66e9@2017-11-27 15:38:09 +0000\",\"timestamp\":\"2017-11-28 15:15:39+0000\",\"ndc\":\"8a8294174e735d0c014e78beb6b9154b_691783d2e7834e6eb8ca011f4fee1b74\"}"
  end
end
