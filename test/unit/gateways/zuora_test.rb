require 'test_helper'

class ZuoraTest < Test::Unit::TestCase
  def setup
    @gateway = ZuoraGateway.new(username: 'login', password: 'password')
    @credit_card = credit_card

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
    @failed_options = {
      order_id: '1'
    }
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response

    assert_equal '2c92c0fa6068c1dd016068ff41251bb5', response.authorization
    assert response.test?
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)

    response = @gateway.store(@credit_card, @failed_options)
    assert_failure response

    assert_match /'billToContact' may not be null/, response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to rest.apisandbox.zuora.com:443...
      opened
      starting SSL for rest.apisandbox.zuora.com:443...
      SSL established
      <- "POST /v1/accounts HTTP/1.1\r\nContent-Type: application/json\r\nUser-Agent: ActiveMerchantBindings/1.70.0\r\nApiaccesskeyid: foo\r\nApisecretaccesskey: bar\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: rest.apisandbox.zuora.com\r\nContent-Length: 422\r\n\r\n"
      <- "{\"billToContact\":{\"address1\":\"456 My Street\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zipCode\":\"K1C2N6\",\"country\":\"CA\",\"firstName\":\"Bob\",\"lastName\":\"Longsen\"},\"currency\":\"AUD\",\"creditCard\":{\"cardNumber\":\"4000100011112224\",\"cardType\":\"Visa\",\"expirationMonth\":\"09\",\"expirationYear\":\"2018\",\"securityCode\":\"123\"},\"autoPay\":true,\"billCycleDay\":0,\"invoiceDeliveryPrefsEmail\":false,\"invoiceDeliveryPrefsPrint\":false,\"name\":\"Store Purchase\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Server: Zuora App\r\n"
      -> "x-request-id: 8e4fda2d-d977-4643-827d-b9abd61d2c29\r\n"
      -> "X-Kong-Upstream-Latency: 2122\r\n"
      -> "X-Kong-Proxy-Latency: 0\r\n"
      -> "Date: Mon, 18 Dec 2017 10:16:59 GMT\r\n"
      -> "Content-Length: 165\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: ZSession=-jut7AtmxKwJOpdTT0oKsoTAikqaj3ZmfLKpaoFOYOQc_WXCm1409iE9XxLIHIIB9ID05fVqnVqZgt9inkrtJ3jWIh6iMMedv8Ljh9zF3489_8D91EFRcSeSd7Pn_o8dsbl2I7ilYYZ9Wn8066t5pCzosnt3_60weM_NXKB0RLopFV5D58Pwd-dBiO2XSJgLnVU8bAWnNmPqLqBg-7Sbf6cbChxxDfOv6CU-9asQodgNNG0bCxDx5sIUgHwy7fL8CG-FU3ekL5Zlc1vfrZdTpDmfNpk1PrELzdWPVftktCj-FHrd1XTsasjTzC1rzbR-rewL7usFwhk4839Pt6_qm-m01YiMn30rqk6xw04YJ0U%3D; Path=/; Secure; HttpOnly\r\n"
      -> "\r\n"
      reading 165 bytes...
      -> "{\n  \"success\" : true,\n  \"accountId\" : \"2c92c0fb6068c83d016069205ece2945\",\n  \"accountNumber\" : \"A00002791\",\n  \"paymentMethodId\" : \"2c92c0fb6068c83d0160692066c6294b\"\n}"
      read 165 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to rest.apisandbox.zuora.com:443...
      opened
      starting SSL for rest.apisandbox.zuora.com:443...
      SSL established
      <- "POST /v1/accounts HTTP/1.1\r\nContent-Type: application/json\r\nUser-Agent: ActiveMerchantBindings/1.70.0\r\nApiaccesskeyid: [FILTERED]\r\nApisecretaccesskey: [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: rest.apisandbox.zuora.com\r\nContent-Length: 422\r\n\r\n"
      <- "{\"billToContact\":{\"address1\":\"456 My Street\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zipCode\":\"K1C2N6\",\"country\":\"CA\",\"firstName\":\"Bob\",\"lastName\":\"Longsen\"},\"currency\":\"AUD\",\"creditCard\":{\"cardNumber\":\"[FILTERED]\",\"cardType\":\"Visa\",\"expirationMonth\":\"09\",\"expirationYear\":\"2018\",\"securityCode\":\"[FILTERED]\"},\"autoPay\":true,\"billCycleDay\":0,\"invoiceDeliveryPrefsEmail\":false,\"invoiceDeliveryPrefsPrint\":false,\"name\":\"Store Purchase\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Server: Zuora App\r\n"
      -> "x-request-id: 8e4fda2d-d977-4643-827d-b9abd61d2c29\r\n"
      -> "X-Kong-Upstream-Latency: 2122\r\n"
      -> "X-Kong-Proxy-Latency: 0\r\n"
      -> "Date: Mon, 18 Dec 2017 10:16:59 GMT\r\n"
      -> "Content-Length: 165\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: ZSession=-jut7AtmxKwJOpdTT0oKsoTAikqaj3ZmfLKpaoFOYOQc_WXCm1409iE9XxLIHIIB9ID05fVqnVqZgt9inkrtJ3jWIh6iMMedv8Ljh9zF3489_8D91EFRcSeSd7Pn_o8dsbl2I7ilYYZ9Wn8066t5pCzosnt3_60weM_NXKB0RLopFV5D58Pwd-dBiO2XSJgLnVU8bAWnNmPqLqBg-7Sbf6cbChxxDfOv6CU-9asQodgNNG0bCxDx5sIUgHwy7fL8CG-FU3ekL5Zlc1vfrZdTpDmfNpk1PrELzdWPVftktCj-FHrd1XTsasjTzC1rzbR-rewL7usFwhk4839Pt6_qm-m01YiMn30rqk6xw04YJ0U%3D; Path=/; Secure; HttpOnly\r\n"
      -> "\r\n"
      reading 165 bytes...
      -> "{\n  \"success\" : true,\n  \"accountId\" : \"2c92c0fb6068c83d016069205ece2945\",\n  \"accountNumber\" : \"A00002791\",\n  \"paymentMethodId\" : \"2c92c0fb6068c83d0160692066c6294b\"\n}"
      read 165 bytes
      Conn close
    )
  end

  def successful_store_response
    <<-JSON
      {
        "success" : true,
        "accountId" : "2c92c0fa6068c1dd016068ff41251bb5",
        "accountNumber" : "A00002783",
        "paymentMethodId" : "2c92c0fa6068c1dd016068ff493e1bbb"
      }
    JSON
  end

  def failed_store_response
    <<-JSON
      {
        "success" : false,
        "processId" : "2E49DC014ABB9366",
        "reasons" : [ {
          "code" : 51000220,
          "message" : "'name' may not be empty"
        }, {
          "code" : 51001122,
          "message" : "'billToContact' may not be null"
        }, {
          "code" : 51000322,
          "message" : "'currency' may not be null"
        } ]
      }
    JSON
  end
end
