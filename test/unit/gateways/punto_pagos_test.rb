require 'test_helper'

class PuntoPagosTest < Test::Unit::TestCase
  include CommStub

  def setup
    @url = PuntoPagosGateway.test_url
    Time.stubs(:now).returns(Time.new(1984, 6, 4))
    @timestamp = 'Mon, 04 Jun 1984 00:00:00 GMT'
    @gateway = PuntoPagosGateway.new(key: "KEY", secret: "SECRET")
    @amount = 9999
    @trx_id = 10
    @token = 'P54L1SGNVJHE6VV1'
    @authorization = 'PP KEY:Q2AsxwHWW3Bfe9bO56KVixzJDig='

    @purchase_options = { trx_id: @trx_id }

    @details_options = {
      trx_id: @trx_id,
      amount: @amount,
      token: @token
    }

    @notification_options = {
      trx_id: @trx_id,
      amount: @amount,
      token: @token,
      authorization: @authorization,
      timestamp: @timestamp
    }
  end

  def test_urls
    assert_equal 'http://sandbox.puntopagos.com', PuntoPagosGateway.test_url
    assert_equal 'https://www.puntopagos.com', PuntoPagosGateway.live_url
  end

  def test_default_currency
    assert_equal 'CLP', PuntoPagosGateway.default_currency
  end

  def test_currencies_without_fractions
    assert_equal %w(CLP), PuntoPagosGateway.currencies_without_fractions
  end

  def test_supported_countries
    assert_equal %w(CL), PuntoPagosGateway.supported_countries
  end

  def test_money_format
    assert_equal :cents, PuntoPagosGateway.money_format
  end

  def test_homepage_url
    assert_equal 'https://www.puntopagos.com', PuntoPagosGateway.homepage_url
  end

  def test_display_name
    assert_equal 'Punto Pagos', PuntoPagosGateway.display_name
  end

  def test_initialize_with_missing_secret_credential
    assert_raise_message("Missing required parameter: secret") do
      PuntoPagosGateway.new(key: "KEY")
    end
  end

  def test_initialize_with_missing_key_credential
    assert_raise_message("Missing required parameter: key") do
      PuntoPagosGateway.new(secret: "SECRET")
    end
  end

  def test_successful_purchase_setup
    response = stub_comms do
      @gateway.setup_purchase(@amount, @purchase_options)
    end.check_request do |endpoint, data, headers|
      expected_data = { 'trx_id' => '10', 'monto' => '100.00' }
      check_punto_pagos_request(endpoint, data, headers, expected_data, 'transaccion/crear')
    end.respond_with(successful_purchase_setup_response)

    assert_purchase_setup_success(response)
  end

  def test_successful_purchase_setup_with_payment_method
    @purchase_options[:payment_method] = :ripley

    response = stub_comms do
      @gateway.setup_purchase(@amount, @purchase_options)
    end.check_request do |endpoint, data, headers|
      expected_data = { 'medio_pago' => 10, 'trx_id' => '10', 'monto' => '100.00' }
      check_punto_pagos_request(endpoint, data, headers, expected_data, 'transaccion/crear')
    end.respond_with(successful_purchase_setup_response)

    assert_purchase_setup_success(response)
  end

  def test_failed_purchase_setup_with_invalid_trx_id
    @purchase_options = { trx_id: "" }

    response = stub_comms do
      @gateway.setup_purchase(@amount, @purchase_options)
    end.check_request do |endpoint, data, headers|
      expected_data = { 'trx_id' => '', 'monto' => '100.00' }
      check_punto_pagos_request(endpoint, data, headers, expected_data, 'transaccion/crear')
    end.respond_with(failed_purchase_setup_response)

    assert_purchase_setup_failure(response)
  end

  def test_failed_purchase_setup_with_missing_trx_id
    assert_raise_message("Missing required parameter: trx_id") do
      @gateway.setup_purchase(@amount, {})
    end
  end

  def test_failed_purchase_setup_with_invalid_payment_method
    @purchase_options[:payment_method] = 'invalid'

    assert_raise_message("Invalid payment type: invalid") do
      @gateway.setup_purchase(@amount, @purchase_options)
    end
  end

  def test_failed_purchase_setup_with_unsupported_currency
    @purchase_options[:currency] = 'USD'

    assert_raise_message("Unsupported currency: USD") do
      @gateway.setup_purchase(@amount, @purchase_options)
    end
  end

  def test_redirect_url_for
    assert_equal("#{@url}/transaccion/procesar/#{@token}", @gateway.redirect_url_for(@token))
  end

  def test_successful_details
    response = stub_comms(@gateway, :ssl_get) do
      @gateway.details_for(@details_options)
    end.check_request do |endpoint, headers|
      check_punto_pagos_request(endpoint, nil, headers, nil, "transaccion/#{@token}")
    end.respond_with(successful_details_response)

    assert_details_success(response)
  end

  def test_failed_details
    response = stub_comms(@gateway, :ssl_get) do
      @gateway.details_for(@details_options)
    end.check_request do |endpoint, headers|
      check_punto_pagos_request(endpoint, nil, headers, nil, "transaccion/#{@token}")
    end.respond_with(failed_details_response)

    assert_details_failure(response, '6', 'Transaccion incompleta')
  end

  def test_failed_details_with_missing_token
    @details_options.delete(:token)

    assert_raise_message("Missing required parameter: token") do
      @gateway.details_for(@details_options)
    end
  end

  def test_failed_details_with_missing_trx_id
    @details_options.delete(:trx_id)

    assert_raise_message("Missing required parameter: trx_id") do
      @gateway.details_for(@details_options)
    end
  end

  def test_failed_details_with_missing_amount
    @details_options.delete(:amount)

    assert_raise_message("Missing required parameter: amount") do
      @gateway.details_for(@details_options)
    end
  end

  def test_successful_notification
    response = stub_comms(@gateway, :ssl_get) do
      @gateway.notificate(@notification_options)
    end.check_request do |endpoint, headers|
      check_punto_pagos_request(endpoint, nil, headers, nil, "transaccion/#{@token}")
    end.respond_with(successful_details_response)

    assert_notification_success(response)
  end

  def test_notification_with_incomplete_transaction
    @notification_options[:error] = 'error'

    response = stub_comms(@gateway, :ssl_get) do
      @gateway.notificate(@notification_options)
    end.check_request do |endpoint, headers|
      check_punto_pagos_request(endpoint, nil, headers, nil, "transaccion/#{@token}")
    end.respond_with(failed_details_response)

    assert_notification_failure(response, 'Transaccion incompleta')
  end

  def test_failed_notification_with_missing_token
    @notification_options.delete(:token)

    assert_raise_message("Missing required parameter: token") do
      @gateway.notificate(@notification_options)
    end
  end

  def test_failed_notification_with_missing_trx_id
    @notification_options.delete(:trx_id)

    assert_raise_message("Missing required parameter: trx_id") do
      @gateway.notificate(@notification_options)
    end
  end

  def test_failed_notification_with_missing_amount
    @notification_options.delete(:amount)

    assert_raise_message("Missing required parameter: amount") do
      @gateway.notificate(@notification_options)
    end
  end

  def test_failed_notification_with_missing_timestamp
    @notification_options.delete(:timestamp)

    assert_raise_message("Missing required parameter: timestamp") do
      @gateway.notificate(@notification_options)
    end
  end

  def test_failed_notification_with_missing_authorization
    @notification_options.delete(:authorization)

    assert_raise_message("Missing required parameter: authorization") do
      @gateway.notificate(@notification_options)
    end
  end

  def test_failed_notification_with_invalid_timestamp
    @notification_options[:timestamp] = "invalid"

    assert_raise_message("Invalid notification signature") do
      @gateway.notificate(@notification_options)
    end
  end

  def test_failed_notification_with_invalid_authorization
    @notification_options[:authorization] = "invalid"

    assert_raise_message("Invalid notification signature") do
      @gateway.notificate(@notification_options)
    end
  end

  def test_scrub
    assert_equal(post_scrubbed, @gateway.scrub(pre_scrubbed))
  end

  private

  def check_punto_pagos_request(endpoint, data, headers, expected_data, action)
    assert_equal("#{@url}/#{action}", endpoint)
    assert_equal(expected_data, JSON.parse(data)) if data && expected_data
    assert_equal(@timestamp, headers["Fecha"])
    assert_match(/\APP\sKEY:.+=\z/, headers["Autorizacion"])
  end

  def assert_details_success(response)
    assert_success(response)
    assert(response.test?)
    assert_equal(@token, response.token)
    assert_equal(@trx_id.to_s, response.trx_id)
    assert_equal('Success', response.message)
    assert_equal('00', response.code)
    assert_equal('codigo_autorizacion', response.auth_code)
    assert_equal('fecha_aprobacion', response.approved_at)
    assert_equal('medio_pago', response.payment_method)
    assert_equal('medio_pago_descripcion', response.payment_method_description)
    assert_equal('monto', response.amount)
    assert_equal('num_cuotas', response.shares)
    assert_equal('valor_cuota', response.share_value)
    assert_equal('tipo_cuotas', response.share_type)
    assert_equal('numero_tarjeta', response.card_number)
    assert_equal('numero_operacion', response.operation_number)
    assert_equal('primer_vencimiento', response.first_expiration)
    assert_equal('tipo_pago', response.payment_type)
  end

  def assert_purchase_setup_success(response)
    assert_success(response)
    assert_equal(@token, response.authorization)
    assert_equal('Success', response.message)
    assert(response.test?)
  end

  def assert_notification_success(response)
    assert_equal('00', response[:respuesta])
    assert_equal(@token, response[:token])
  end

  def assert_purchase_setup_failure(response)
    assert_failure(response)
    assert_nil(response.authorization)
    assert(response.test?)
  end

  def assert_details_failure(response, code, message)
    assert_failure(response)
    assert(response.test?)
    assert_equal(message, response.message)
    assert_equal(code, response.code)
    assert_equal(@token, response.token)
    assert_equal(@token, response.authorization)
  end

  def assert_notification_failure(response, error)
    assert_equal('99', response[:respuesta])
    assert_equal(@token, response[:token])
    assert_equal(error, response[:error])
  end

  def successful_purchase_setup_response
    <<-RESPONSE
    {
      "error": null,
      "monto": "100.00",
      "respuesta": "00",
      "token": "#{@token}",
      "trx_id": "10"
    }
    RESPONSE
  end

  def failed_purchase_setup_response
    <<-RESPONSE
    {
      "error": "Input string was not in a correct format.",
      "monto": "0",
      "respuesta": "99",
      "token": null,
      "trx_id": null
    }
    RESPONSE
  end

  def successful_details_response
    <<-RESPONSE
    {
      "codigo_autorizacion": "codigo_autorizacion",
      "error": null,
      "fecha_aprobacion": "fecha_aprobacion",
      "medio_pago": "medio_pago",
      "medio_pago_descripcion": "medio_pago_descripcion",
      "monto": "monto",
      "num_cuotas": "num_cuotas",
      "numero_operacion": "numero_operacion",
      "numero_tarjeta": "numero_tarjeta",
      "primer_vencimiento": "primer_vencimiento",
      "respuesta": "00",
      "tipo_cuotas": "tipo_cuotas",
      "tipo_pago": "tipo_pago",
      "token": "#{@token}",
      "trx_id": "#{@trx_id}",
      "valor_cuota": "valor_cuota"
    }
    RESPONSE
  end

  def failed_details_response
    <<-RESPONSE
    {
      "codigo_autorizacion": null,
      "error": "Transaccion incompleta",
      "fecha_aprobacion": null,
      "medio_pago": null,
      "medio_pago_descripcion": null,
      "monto": 0,
      "num_cuotas": 0,
      "numero_operacion": 0,
      "numero_tarjeta": null,
      "primer_vencimiento": null,
      "respuesta": "6",
      "tipo_cuotas": null,
      "tipo_pago": null,
      "token": "#{@token}",
      "trx_id": null,
      "valor_cuota": 0
    }
    RESPONSE
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to sandbox.puntopagos.com:80...
      opened
      <- "POST /transaccion/crear HTTP/1.1\r\nContent-Type: application/json; charset=utf-8\r\nAccept: application/json\r\nAccept-Charset: utf-8\r\nFecha: Thu, 01 Mar 2018 00:00:00 GMT\r\nAutorizacion: PP Qxp1tuu5410mIEKKS1cx:j3ke5PzhZSH6X+5/iXeKtiNkmwQ=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.puntopagos.com\r\nContent-Length: 48\r\n\r\n"
      <- "{\"trx_id\":\"10\",\"monto\":\"100.00\",\"medio_pago\":10}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: private\r\n"
      -> "Content-Length: 87\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Server: Microsoft-IIS/7.0\r\n"
      -> "X-AspNet-Version: 4.0.30319\r\n"
      -> "Date: Fri, 09 Mar 2018 17:02:39 GMT\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 87 bytes...
      -> "{\"error\":null,\"monto\":100.00,\"respuesta\":\"00\",\"token\":\"P5C20F7EACAHQM5E\",\"trx_id\":\"10\"}"
      read 87 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to sandbox.puntopagos.com:80...
      opened
      <- "POST /transaccion/crear HTTP/1.1\r\nContent-Type: application/json; charset=utf-8\r\nAccept: application/json\r\nAccept-Charset: utf-8\r\nFecha: Thu, 01 Mar 2018 00:00:00 GMT\r\nAutorizacion: [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.puntopagos.com\r\nContent-Length: 48\r\n\r\n"
      <- "{\"trx_id\":\"10\",\"monto\":\"100.00\",\"medio_pago\":10}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: private\r\n"
      -> "Content-Length: 87\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Server: Microsoft-IIS/7.0\r\n"
      -> "X-AspNet-Version: 4.0.30319\r\n"
      -> "Date: Fri, 09 Mar 2018 17:02:39 GMT\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 87 bytes...
      -> "{\"error\":null,\"monto\":100.00,\"respuesta\":\"00\",\"token\":\"P5C20F7EACAHQM5E\",\"trx_id\":\"10\"}"
      read 87 bytes
      Conn close
    POST_SCRUBBED
  end
end
