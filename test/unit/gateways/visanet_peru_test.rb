require 'test_helper'

class VisanetPeruTest < Test::Unit::TestCase
  def setup
    @gateway = VisanetPeruGateway.new(fixtures(:visanet_peru))

    @amount = 100
    @credit_card = credit_card("4500340090000016", verification_value: "377")
    @declined_card = credit_card("4111111111111111")

    @options = {
      # Visanet Peru expects a 9-digit numeric order_id (aka) purchaseNumber
      order_id: "987654321",
      purchase_number: "987654321",
      billing_address: address,
      email: "visanetperutest@mailinator.com",
      merchant_id: "101266802",
      device_fingerprint_id: "deadbeef",
      merchant_define_data: {
        field3: "movil",  # Channel
        field91: "101266802", # Merchant Code / Merchant Id
        field92: "Cabify" # Merchant Name
      }
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "OK", response.message

    assert_equal "deposit|" + @options[:merchant_id] + "|" + @options[:order_id], response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_authorize_response_bad_card)

    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "OK", response.message
    assert_equal "authorize|" + @options[:merchant_id] + "|" + @options[:order_id], response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response_bad_card)
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
    assert_equal "[ ]", response.message

    @gateway.expects(:ssl_request).returns(failed_authorize_response_bad_email)
    @options[:email] = "cybersource@reject.com"
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
    assert_equal "El pedido ha sido rechazado por Decision Manager", response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    @gateway.expects(:ssl_request).returns(successful_capture_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    capture = @gateway.capture(response.authorization, @options)
    assert_success capture
    assert_equal "OK", capture.message
    assert_equal "deposit|" + @options[:merchant_id] + "|" + @options[:order_id], capture.authorization
    assert capture.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)
    invalid_purchase_number = "122333444"
    response = @gateway.capture("authorize" + "|" + @options[:merchant_id] + "|" + invalid_purchase_number)
    assert_failure response
    assert_equal "[ 'NUMORDEN 12233344 no se encuentra registrado', 'No se realizo el deposito' ]", response.message
    assert_equal 400, response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    @gateway.expects(:ssl_request).returns(successful_void_response)
    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "OK", void.message

    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    @gateway.expects(:ssl_request).returns(successful_capture_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    @gateway.expects(:ssl_request).returns(successful_void_response)
    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "OK", void.message
  end

  def test_failed_void
    invalid_purchase_number = "122333444"
    @gateway.expects(:ssl_request).returns(failed_void_response_for_authorize)
    response = @gateway.void("authorize" + "|" + @options[:merchant_id] + "|" + invalid_purchase_number)
    assert_failure response
    assert_equal "[ 'NUMORDEN no se encuentra registrado.', 'No se ha realizado la anulacion del pedido' ]", response.message
    assert_equal 400, response.error_code

    @gateway.expects(:ssl_request).returns(failed_void_response_for_capture)
    response = @gateway.void("deposit" + "|" + @options[:merchant_id] + "|" + invalid_purchase_number)
    assert_failure response
    assert_equal "[ 'NUMORDEN 122333444 no se encuentra registrado', 'No se realizo la anulacion del deposito' ]", response.message
    assert_equal 400, response.error_code
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    @gateway.expects(:ssl_request).returns(successful_verify_response)
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "OK", response.message
  end

  def test_failed_verify
    @gateway.expects(:ssl_request).returns(failed_verify_response)
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
    assert_equal "[ ]", response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to devapi.vnforapps.com:443...
      opened
      starting SSL for devapi.vnforapps.com:443...
      SSL established
      <- "POST /api.tokenization/api/v2/merchant/101266802 HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic QUtJQUpQT1FaN0JBWEpaNUszNUE6VXIrVTBwbjFia2pSaFBHeitHK09MTmpxSWk3T0Jsd2taMmVUSHlTRw==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: devapi.vnforapps.com\r\nContent-Length: 551\r\n\r\n"
      <- "{\"amount\":100.0,\"purchaseNumber\":\"858169315\",\"externalTransactionId\":\"858169315\",\"currencyId\":604,\"firstName\":\"Longbob\",\"lastName\":\"Longsen\",\"cardNumber\":\"4500340090000016\",\"cvv2Code\":377,\"expirationYear\":\"2017\",\"expirationMonth\":\"09\",\"email\":\"visanetperutest@mailinator.com\",\"antifraud\":{\"billTo_street1\":\"456 My Street\",\"billTo_city\":\"Ottawa\",\"billTo_state\":\"ON\",\"billTo_country\":\"CA\",\"billTo_postalCode\":\"K1C2N6\",\"deviceFingerprintId\":\"deadbeef\",\"merchantDefineData\":{\"field3\":\"movil\",\"field91\":\"101266802\",\"field92\":\"Cabify\"}},\"createAlias\":false}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Date: Mon, 21 Mar 2016 07:21:09 GMT\r\n"
      -> "Server: WildFly/9\r\n"
      -> "X-Powered-By: Undertow/1\r\n"
      -> "Content-Length: 679\r\n"
      -> "Connection: Close\r\n"
      -> "\r\n"
      reading 679 bytes...
      -> "{\"errorCode\":0,\"errorMessage\":\"OK\",\"transactionUUID\":\"3db3c81a-835a-4db6-9e86-eb450c580b2c\",\"externalTransactionId\":\"858169315\",\"transactionDateTime\":1458544860693,\"transactionDuration\":0,\"merchantId\":\"101266802\",\"userTokenId\":null,\"aliasName\":null,\"data\":{\"FECHAYHORA_TX\":\"21/03/2016 02:23\",\"DSC_ECI\":\"Tarjeta no autenticada.\",\"DSC_COD_ACCION\":\"Operacion Autorizada\",\"NOM_EMISOR\":\"FINANCIERA CORDILLER\",\"RESPUESTA\":\"1\",\"ID_UNICO\":\"\",\"NUMORDEN\":\"858169315\",\"CODACCION\":\"000\",\"ETICKET\":\"3106040291071603210220450000\",\"IMP_AUTORIZADO\":\"100.00\",\"DECISIONCS\":\"1\",\"COD_AUTORIZA\":\"160351\",\"CODTIENDA\":\"101266802\",\"PAN\":\"450034******0016\",\"reviewTransaction\":\"false\",\"ORI_TARJETA\":\"N\"}}"
      read 679 bytes
      Conn close
      opening connection to devapi.vnforapps.com:443...
      opened
      starting SSL for devapi.vnforapps.com:443...
      SSL established
      <- "PUT /api.tokenization/api/v2/merchant/101266802/deposit/858169315 HTTP/1.1\r\nAuthorization: Basic QUtJQUpQT1FaN0JBWEpaNUszNUE6VXIrVTBwbjFia2pSaFBHeitHK09MTmpxSWk3T0Jsd2taMmVUSHlTRw==\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: devapi.vnforapps.com\r\nContent-Length: 37\r\n\r\n"
      <- "{\"externalTransactionId\":\"858169315\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Date: Mon, 21 Mar 2016 07:21:36 GMT\r\n"
      -> "Server: WildFly/9\r\n"
      -> "X-Powered-By: Undertow/1\r\n"
      -> "Content-Length: 550\r\n"
      -> "Connection: Close\r\n"
      -> "\r\n"
      reading 550 bytes...
      -> "{\"errorCode\":0,\"errorMessage\":\"OK\",\"transactionUUID\":\"6dee4901-813a-40ab-b571-60ee450be2ea\",\"externalTransactionId\":\"858169315\",\"transactionDateTime\":1458544871523,\"transactionDuration\":0,\"merchantId\":\"101266802\",\"userTokenId\":null,\"aliasName\":null,\"data\":{\"FECHAYHORA_TX\":null,\"DSC_ECI\":null,\"DSC_COD_ACCION\":null,\"NOM_EMISOR\":null,\"ESTADO\":\"Depositado\",\"RESPUESTA\":\"1\",\"ID_UNICO\":null,\"NUMORDEN\":null,\"CODACCION\":null,\"ETICKET\":null,\"IMP_AUTORIZADO\":null,\"DECISIONCS\":null,\"COD_AUTORIZA\":null,\"CODTIENDA\":\"101266802\",\"PAN\":null,\"ORI_TARJETA\":null}}"
      read 550 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to devapi.vnforapps.com:443...
      opened
      starting SSL for devapi.vnforapps.com:443...
      SSL established
      <- "POST /api.tokenization/api/v2/merchant/101266802 HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: devapi.vnforapps.com\r\nContent-Length: 551\r\n\r\n"
      <- "{\"amount\":100.0,\"purchaseNumber\":\"858169315\",\"externalTransactionId\":\"858169315\",\"currencyId\":604,\"firstName\":\"Longbob\",\"lastName\":\"Longsen\",\"cardNumber\":\"[FILTERED]\",\"cvv2Code\":[FILTERED],\"expirationYear\":\"2017\",\"expirationMonth\":\"09\",\"email\":\"visanetperutest@mailinator.com\",\"antifraud\":{\"billTo_street1\":\"456 My Street\",\"billTo_city\":\"Ottawa\",\"billTo_state\":\"ON\",\"billTo_country\":\"CA\",\"billTo_postalCode\":\"K1C2N6\",\"deviceFingerprintId\":\"deadbeef\",\"merchantDefineData\":{\"field3\":\"movil\",\"field91\":\"101266802\",\"field92\":\"Cabify\"}},\"createAlias\":false}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Date: Mon, 21 Mar 2016 07:21:09 GMT\r\n"
      -> "Server: WildFly/9\r\n"
      -> "X-Powered-By: Undertow/1\r\n"
      -> "Content-Length: 679\r\n"
      -> "Connection: Close\r\n"
      -> "\r\n"
      reading 679 bytes...
      -> "{\"errorCode\":0,\"errorMessage\":\"OK\",\"transactionUUID\":\"3db3c81a-835a-4db6-9e86-eb450c580b2c\",\"externalTransactionId\":\"858169315\",\"transactionDateTime\":1458544860693,\"transactionDuration\":0,\"merchantId\":\"101266802\",\"userTokenId\":null,\"aliasName\":null,\"data\":{\"FECHAYHORA_TX\":\"21/03/2016 02:23\",\"DSC_ECI\":\"Tarjeta no autenticada.\",\"DSC_COD_ACCION\":\"Operacion Autorizada\",\"NOM_EMISOR\":\"FINANCIERA CORDILLER\",\"RESPUESTA\":\"1\",\"ID_UNICO\":\"\",\"NUMORDEN\":\"858169315\",\"CODACCION\":\"000\",\"ETICKET\":\"3106040291071603210220450000\",\"IMP_AUTORIZADO\":\"100.00\",\"DECISIONCS\":\"1\",\"COD_AUTORIZA\":\"160351\",\"CODTIENDA\":\"101266802\",\"PAN\":\"450034******0016\",\"reviewTransaction\":\"false\",\"ORI_TARJETA\":\"N\"}}"
      read 679 bytes
      Conn close
      opening connection to devapi.vnforapps.com:443...
      opened
      starting SSL for devapi.vnforapps.com:443...
      SSL established
      <- "PUT /api.tokenization/api/v2/merchant/101266802/deposit/858169315 HTTP/1.1\r\nAuthorization: Basic [FILTERED]==\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: devapi.vnforapps.com\r\nContent-Length: 37\r\n\r\n"
      <- "{\"externalTransactionId\":\"858169315\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Date: Mon, 21 Mar 2016 07:21:36 GMT\r\n"
      -> "Server: WildFly/9\r\n"
      -> "X-Powered-By: Undertow/1\r\n"
      -> "Content-Length: 550\r\n"
      -> "Connection: Close\r\n"
      -> "\r\n"
      reading 550 bytes...
      -> "{\"errorCode\":0,\"errorMessage\":\"OK\",\"transactionUUID\":\"6dee4901-813a-40ab-b571-60ee450be2ea\",\"externalTransactionId\":\"858169315\",\"transactionDateTime\":1458544871523,\"transactionDuration\":0,\"merchantId\":\"101266802\",\"userTokenId\":null,\"aliasName\":null,\"data\":{\"FECHAYHORA_TX\":null,\"DSC_ECI\":null,\"DSC_COD_ACCION\":null,\"NOM_EMISOR\":null,\"ESTADO\":\"Depositado\",\"RESPUESTA\":\"1\",\"ID_UNICO\":null,\"NUMORDEN\":null,\"CODACCION\":null,\"ETICKET\":null,\"IMP_AUTORIZADO\":null,\"DECISIONCS\":null,\"COD_AUTORIZA\":null,\"CODTIENDA\":\"101266802\",\"PAN\":null,\"ORI_TARJETA\":null}}"
      read 550 bytes
      Conn close
    )
  end

  def successful_authorize_response
    <<-RESPONSE
    {
      "errorCode": 0,
      "errorMessage": "OK",
      "externalTransactionId": "987654321",
      "merchantId": "101266802"
    }
    RESPONSE
  end

  def failed_authorize_response_bad_card
    <<-RESPONSE
    {
      "errorCode": 400,
      "errorMessage": "[ ]"
    }
    RESPONSE
  end

  def failed_authorize_response_bad_email
    <<-RESPONSE
    {
      "errorCode": 400,
      "errorMessage": "El pedido ha sido rechazado por Decision Manager"
    }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    {
      "errorCode": 0,
      "errorMessage": "OK",
      "externalTransactionId": "987654321",
      "merchantId": "101266802"
    }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
    {
      "errorCode": 400,
      "errorMessage": "[ 'NUMORDEN 12233344 no se encuentra registrado', 'No se realizo el deposito' ]"
    }
    RESPONSE
  end

  def successful_verify_response
    <<-RESPONSE
    {
      "errorCode": 0,
      "errorMessage": "OK",
      "externalTransactionId": "987654321",
      "merchantId": "101266802"
    }
    RESPONSE
  end

  def failed_verify_response
    <<-RESPONSE
    {
      "errorCode": 400,
      "errorMessage": "[ ]"
    }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {
      "errorCode": 0,
      "errorMessage": "OK",
      "externalTransactionId": "987654321",
      "merchantId": "101266802"
    }
    RESPONSE
  end

  def failed_void_response_for_authorize
    <<-RESPONSE
    {
      "errorCode": 400,
      "errorMessage": "[ 'NUMORDEN no se encuentra registrado.', 'No se ha realizado la anulacion del pedido' ]"
    }
    RESPONSE
  end

  def failed_void_response_for_capture
    <<-RESPONSE
    {
      "errorCode": 400,
      "errorMessage": "[ 'NUMORDEN 122333444 no se encuentra registrado', 'No se realizo la anulacion del deposito' ]"
    }
    RESPONSE
  end
end
