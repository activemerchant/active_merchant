require 'test_helper'

class KushkiTest < Test::Unit::TestCase
  def setup
    @gateway = KushkiGateway.new(public_merchant_id: '_', private_merchant_id: '_')
    @amount = 100
    @credit_card = credit_card
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_charge_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_options
    options = {
      currency: "USD",
      amount: {
        subtotal_iva_0: "4.95",
        subtotal_iva: "10",
        iva: "1.54",
        ice: "3.50"
      }
    }

    amount = 100 * (
      options[:amount][:subtotal_iva_0].to_f +
      options[:amount][:subtotal_iva].to_f +
      options[:amount][:iva].to_f +
      options[:amount][:ice].to_f
    )

    @gateway.expects(:ssl_post).returns(successful_charge_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)

    response = @gateway.purchase(amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
    assert response.test?
  end

  def test_failed_purchase
    options = {
      amount: {
        subtotal_iva: "200"
      }
    }

    @gateway.expects(:ssl_post).returns(failed_charge_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_failure response
    assert_equal 'Monto de la transacción es diferente al monto de la venta inicial', response.message
    assert_equal '220', response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_charge_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)

    purchase = @gateway.purchase(@amount, @credit_card)
    assert_success purchase

    @gateway.expects(:ssl_request).returns(successful_refund_response)

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Succeeded', refund.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(successful_charge_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)

    purchase = @gateway.purchase(@amount, @credit_card)
    assert_success purchase

    @gateway.expects(:ssl_request).returns(failed_refund_response)

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_failure refund
    assert_equal 'Ticket number inválido', refund.message
    assert_equal 'K010', refund.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_charge_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)

    purchase = @gateway.purchase(@amount, @credit_card)
    assert_success purchase

    @gateway.expects(:ssl_request).returns(successful_void_response)

    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void("000")
    assert_failure response
    assert_equal 'Tipo de moneda no válida', response.message
    assert_equal '205', response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to api-uat.kushkipagos.com:443...
      opened
      starting SSL for api-uat.kushkipagos.com:443...
      SSL established
      <- "POST /v1/tokens HTTP/1.1\r\nContent-Type: application/json\r\nPublic-Merchant-Id: 10000001837148605646147925549896\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api-uat.kushkipagos.com\r\nContent-Length: 166\r\n\r\n"
      <- "{\"totalAmount\":1.0,\"currency\":\"USD\",\"isDeferred\":false,\"card\":{\"number\":\"4000100011112224\",\"name\":\"Longbob Longsen\",\"cvv\":\"777\",\"expiryMonth\":\"09\",\"expiryYear\":\"18\"}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Tue, 07 Feb 2017 14:53:00 GMT\r\n"
      -> "Server: Apache/2.4.18 (Unix) OpenSSL/1.0.1s Resin/4.0.40\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: OPTIONS\r\n"
      -> "Access-Control-Max-Age: 1000\r\n"
      -> "Access-Control-Allow-Headers: x-requested-with, Content-Type, origin, authorization, accept, client-security-token\r\n"
      -> "Content-Length: 44\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 44 bytes...
      -> ""
      -> "{\"token\":\"BeWb3z100000UXANj0018371b8iPZHYq\"}"
      read 44 bytes
      Conn close
      opening connection to api-uat.kushkipagos.com:443...
      opened
      starting SSL for api-uat.kushkipagos.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/json\r\nPrivate-Merchant-Id: 10000001837138390991147925549896\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api-uat.kushkipagos.com\r\nContent-Length: 123\r\n\r\n"
      <- "{\"token\":\"BeWb3z100000UXANj0018371b8iPZHYq\",\"amount\":{\"currency\":\"USD\",\"subtotalIva\":1.0,\"iva\":0,\"subtotalIva0\":0,\"ice\":0}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Tue, 07 Feb 2017 14:53:02 GMT\r\n"
      -> "Server: Apache/2.4.18 (Unix) OpenSSL/1.0.1s Resin/4.0.40\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: OPTIONS\r\n"
      -> "Access-Control-Max-Age: 1000\r\n"
      -> "Access-Control-Allow-Headers: x-requested-with, Content-Type, origin, authorization, accept, client-security-token\r\n"
      -> "Content-Length: 37\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 37 bytes...
      -> ""
      -> "{\"ticketNumber\":\"170383559069100036\"}"
      read 37 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to api-uat.kushkipagos.com:443...
      opened
      starting SSL for api-uat.kushkipagos.com:443...
      SSL established
      <- "POST /v1/tokens HTTP/1.1\r\nContent-Type: application/json\r\nPublic-Merchant-Id: 10000001837148605646147925549896\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api-uat.kushkipagos.com\r\nContent-Length: 166\r\n\r\n"
      <- "{\"totalAmount\":1.0,\"currency\":\"USD\",\"isDeferred\":false,\"card\":{\"number\":\"[FILTERED]\",\"name\":\"Longbob Longsen\",\"cvv\":\"[FILTERED]\",\"expiryMonth\":\"09\",\"expiryYear\":\"18\"}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Tue, 07 Feb 2017 14:53:00 GMT\r\n"
      -> "Server: Apache/2.4.18 (Unix) OpenSSL/1.0.1s Resin/4.0.40\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: OPTIONS\r\n"
      -> "Access-Control-Max-Age: 1000\r\n"
      -> "Access-Control-Allow-Headers: x-requested-with, Content-Type, origin, authorization, accept, client-security-token\r\n"
      -> "Content-Length: 44\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 44 bytes...
      -> ""
      -> "{\"token\":\"BeWb3z100000UXANj0018371b8iPZHYq\"}"
      read 44 bytes
      Conn close
      opening connection to api-uat.kushkipagos.com:443...
      opened
      starting SSL for api-uat.kushkipagos.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/json\r\nPrivate-Merchant-Id: [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api-uat.kushkipagos.com\r\nContent-Length: 123\r\n\r\n"
      <- "{\"token\":\"BeWb3z100000UXANj0018371b8iPZHYq\",\"amount\":{\"currency\":\"USD\",\"subtotalIva\":1.0,\"iva\":0,\"subtotalIva0\":0,\"ice\":0}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Tue, 07 Feb 2017 14:53:02 GMT\r\n"
      -> "Server: Apache/2.4.18 (Unix) OpenSSL/1.0.1s Resin/4.0.40\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: OPTIONS\r\n"
      -> "Access-Control-Max-Age: 1000\r\n"
      -> "Access-Control-Allow-Headers: x-requested-with, Content-Type, origin, authorization, accept, client-security-token\r\n"
      -> "Content-Length: 37\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 37 bytes...
      -> ""
      -> "{\"ticketNumber\":\"170383559069100036\"}"
      read 37 bytes
      Conn close
    )
  end

  def successful_token_response
    %(
      {
        "token":"Rcp7Un10000070Jwa5018371WVtD0ECx"
      }
    )
  end

  def successful_charge_response
    %(
      {
        "ticketNumber":"170384522771700083"
      }
    )
  end

  def failed_charge_response
    %(
      {
        "code":"220",
        "message":"Monto de la transacción es diferente al monto de la venta inicial"
      }
    )
  end

  def successful_refund_response
    %(
      {
        "code": "K000",
        "message": "El reembolso solicitado se realizó con éxito."
      }
    )
  end

  def failed_refund_response
    %(
      {
        "code": "K010",
        "message": "Ticket number inválido"
      }
    )
  end

  def successful_void_response
    %(
      {
        "ticketNumber":"170384634023500095"
      }
    )
  end

  def failed_void_response
    %(
      {
        "code":"205",
        "message":"Tipo de moneda no válida"
      }
    )
  end
end
