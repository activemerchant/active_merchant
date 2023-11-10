require 'test_helper'

class CecabankJsonTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CecabankJsonGateway.new(
      merchant_id: '12345678',
      acquirer_bin: '12345678',
      terminal_id: '00000003',
      cypher_key: 'enc_key'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      description: 'Store Purchase'
    }
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '12004172282310181802446007000#1#100', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_failure response
    assert_equal '27', response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, 'reference', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '12204172322310181826516007000#1#100', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)
    response = @gateway.capture(@amount, 'reference', @options)

    assert_failure response
    assert_equal '807', response.error_code
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '12004172192310181720006007000#1#100', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_equal '27', response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    assert response = @gateway.refund(@amount, 'reference', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '12204172352310181847426007000#1#100', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    assert response = @gateway.refund(@amount, 'reference', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)

    assert response = @gateway.void('12204172352310181847426007000#1#10', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '14204172402310181906166007000#1#10', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    assert response = @gateway.void('reference', @options)
    assert_failure response
    assert response.test?
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def transcript
    "opening connection to tpv.ceca.es:443...\nopened\nstarting SSL for tpv.ceca.es:443...\nSSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384\n<- \"POST /tpvweb/rest/procesos/compra HTTP/1.1\\r\\nContent-Type: application/json\\r\\nHost: tpv.ceca.es\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nContent-Length: 1145\\r\\n\\r\\n\"\n<- \"{\\\"parametros\\\":\\\"eyJhY2Npb24iOiJSRVNUX0FVVE9SSVpBQ0lPTiIsIm51bU9wZXJhY2lvbiI6IjcwNDBhYjJhMGFkOTQ5NmM2MjhiMTAyZTgzNzEyMGIxIiwiaW1wb3J0ZSI6IjEwMCIsInRpcG9Nb25lZGEiOiI5NzgiLCJleHBvbmVudGUiOiIyIiwicGFuIjoiNDUwNzY3MDAwMTAwMDAwOSIsImNhZHVjaWRhZCI6IjIwMjMxMiIsImN2djIiOiI5ODkiLCJleGVuY2lvblNDQSI6bnVsbCwiVGhyZWVEc1Jlc3BvbnNlIjoie1wiZXhlbXB0aW9uX3R5cGVcIjpudWxsLFwidGhyZWVfZHNfdmVyc2lvblwiOlwiMi4yLjBcIixcImF1dGhlbnRpY2F0aW9uX3ZhbHVlXCI6XCI0RjgwREY1MEFEQjBGOTUwMkI5MTYxOEU5QjcwNDc5MEVBQkEzNUZERkM5NzJEREREMEJGNDk4QzZBNzVFNDkyXCIsXCJkaXJlY3Rvcnlfc2VydmVyX3RyYW5zYWN0aW9uX2lkXCI6XCJhMmJmMDg5Zi1jZWZjLTRkMmMtODUwZi05MTUzODI3ZmUwNzBcIixcImFjc190cmFuc2FjdGlvbl9pZFwiOlwiMThjMzUzYjAtNzZlMy00YTRjLTgwMzMtZjE0ZmU5Y2UzOWRjXCIsXCJhdXRoZW50aWNhdGlvbl9yZXNwb25zZV9zdGF0dXNcIjpcIllcIixcInRocmVlX2RzX3NlcnZlcl90cmFuc19pZFwiOlwiOWJkOWFhOWMtM2JlYi00MDEyLThlNTItMjE0Y2NjYjI1ZWM1XCIsXCJlY29tbWVyY2VfaW5kaWNhdG9yXCI6XCIwMlwiLFwiZW5yb2xsZWRcIjpudWxsLFwiYW1vdW50XCI6XCIxMDBcIn0iLCJtZXJjaGFudElEIjoiMTA2OTAwNjQwIiwiYWNxdWlyZXJCSU4iOiIwMDAwNTU0MDAwIiwidGVybWluYWxJRCI6IjAwMDAwMDAzIn0=\\\",\\\"cifrado\\\":\\\"SHA2\\\",\\\"firma\\\":\\\"712cc9dcc17af686d220f36d68605f91e27fb0ffee448d2d8701aaa9a5068448\\\"}\"\n-> \"HTTP/1.1 200 OK\\r\\n\"\n-> \"Date: Sat, 04 Nov 2023 00:34:09 GMT\\r\\n\"\n-> \"Server: Apache\\r\\n\"\n-> \"Strict-Transport-Security: max-age=31536000; includeSubDomains\\r\\n\"\n-> \"X-XSS-Protection: 1; mode=block\\r\\n\"\n-> \"X-Content-Type-Options: nosniff\\r\\n\"\n-> \"Content-Length: 300\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"Content-Type: application/json\\r\\n\"\n-> \"\\r\\n\"\nreading 300 bytes...\n-> \"{\\\"cifrado\\\":\\\"SHA2\\\",\\\"parametros\\\":\\\"eyJudW1BdXQiOiIxMDEwMDAiLCJyZWZlcmVuY2lhIjoiMTIwMDQyMjM3MTIzMTEwNDAxMzQxMDYwMDcwMDAiLCJjb2RBdXQiOiIwMDAifQ==\\\",\\\"firma\\\":\\\"6be9465e38a4bd28935688fdd3e34cf703c4f23f0e104eae03824838efa583b5\\\",\\\"fecha\\\":\\\"231104013412182\\\",\\\"idProceso\\\":\\\"106900640-7040ab2a0ad9496c628b102e837120b1\\\"}\"\nread 300 bytes\nConn close\n"
  end

  def scrubbed_transcript
    "opening connection to tpv.ceca.es:443...\nopened\nstarting SSL for tpv.ceca.es:443...\nSSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384\n<- \"POST /tpvweb/rest/procesos/compra HTTP/1.1\\r\\nContent-Type: application/json\\r\\nHost: tpv.ceca.es\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nContent-Length: 1145\\r\\n\\r\\n\"\n<- \"{\\\"parametros\\\":\\\"eyJhY2Npb24iOiJSRVNUX0FVVE9SSVpBQ0lPTiIsIm51bU9wZXJhY2lvbiI6IjcwNDBhYjJhMGFkOTQ5NmM2MjhiMTAyZTgzNzEyMGIxIiwiaW1wb3J0ZSI6IjEwMCIsInRpcG9Nb25lZGEiOiI5NzgiLCJleHBvbmVudGUiOiIyIiwicGFuIjoiW0ZJTFRFUkVEXSIsImNhZHVjaWRhZCI6IltGSUxURVJFRF0iLCJjdnYyIjoiW0ZJTFRFUkVEXSIsImV4ZW5jaW9uU0NBIjpudWxsLCJUaHJlZURzUmVzcG9uc2UiOiJ7XCJleGVtcHRpb25fdHlwZVwiOm51bGwsXCJ0aHJlZV9kc192ZXJzaW9uXCI6XCIyLjIuMFwiLFwiYXV0aGVudGljYXRpb25fdmFsdWVcIjpcIjRGODBERjUwQURCMEY5NTAyQjkxNjE4RTlCNzA0NzkwRUFCQTM1RkRGQzk3MkREREQwQkY0OThDNkE3NUU0OTJcIixcImRpcmVjdG9yeV9zZXJ2ZXJfdHJhbnNhY3Rpb25faWRcIjpcImEyYmYwODlmLWNlZmMtNGQyYy04NTBmLTkxNTM4MjdmZTA3MFwiLFwiYWNzX3RyYW5zYWN0aW9uX2lkXCI6XCIxOGMzNTNiMC03NmUzLTRhNGMtODAzMy1mMTRmZTljZTM5ZGNcIixcImF1dGhlbnRpY2F0aW9uX3Jlc3BvbnNlX3N0YXR1c1wiOlwiWVwiLFwidGhyZWVfZHNfc2VydmVyX3RyYW5zX2lkXCI6XCI5YmQ5YWE5Yy0zYmViLTQwMTItOGU1Mi0yMTRjY2NiMjVlYzVcIixcImVjb21tZXJjZV9pbmRpY2F0b3JcIjpcIjAyXCIsXCJlbnJvbGxlZFwiOm51bGwsXCJhbW91bnRcIjpcIjEwMFwifSIsIm1lcmNoYW50SUQiOiIxMDY5MDA2NDAiLCJhY3F1aXJlckJJTiI6IjAwMDA1NTQwMDAiLCJ0ZXJtaW5hbElEIjoiMDAwMDAwMDMifQ==\\\",\\\"cifrado\\\":\\\"SHA2\\\",\\\"firma\\\":\\\"712cc9dcc17af686d220f36d68605f91e27fb0ffee448d2d8701aaa9a5068448\\\"}\"\n-> \"HTTP/1.1 200 OK\\r\\n\"\n-> \"Date: Sat, 04 Nov 2023 00:34:09 GMT\\r\\n\"\n-> \"Server: Apache\\r\\n\"\n-> \"Strict-Transport-Security: max-age=31536000; includeSubDomains\\r\\n\"\n-> \"X-XSS-Protection: 1; mode=block\\r\\n\"\n-> \"X-Content-Type-Options: nosniff\\r\\n\"\n-> \"Content-Length: 300\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"Content-Type: application/json\\r\\n\"\n-> \"\\r\\n\"\nreading 300 bytes...\n-> \"{\\\"cifrado\\\":\\\"SHA2\\\",\\\"parametros\\\":\\\"eyJudW1BdXQiOiIxMDEwMDAiLCJyZWZlcmVuY2lhIjoiMTIwMDQyMjM3MTIzMTEwNDAxMzQxMDYwMDcwMDAiLCJjb2RBdXQiOiIwMDAifQ==\\\",\\\"firma\\\":\\\"6be9465e38a4bd28935688fdd3e34cf703c4f23f0e104eae03824838efa583b5\\\",\\\"fecha\\\":\\\"231104013412182\\\",\\\"idProceso\\\":\\\"106900640-7040ab2a0ad9496c628b102e837120b1\\\"}\"\nread 300 bytes\nConn close\n"
  end

  def successful_authorize_response
    <<~RESPONSE
      {
        "cifrado":"SHA2",
        "parametros":"eyJudW1BdXQiOiIxMDEwMDAiLCJyZWZlcmVuY2lhIjoiMTIwMDQxNzIyODIzMTAxODE4MDI0NDYwMDcwMDAiLCJjb2RBdXQiOiIwMDAifQ==",
        "firma":"2271f18614f9e3bf1f1d0bde7c23d2d9b576087564fd6cb4474f14f5727eaff2",
        "fecha":"231018180245479",
        "idProceso":"106900640-9da0de26e0e81697f7629566b99a1b73"
      }
    RESPONSE
  end

  def failed_authorize_response
    <<~RESPONSE
      {
        "fecha":"231018180927186",
        "idProceso":"106900640-9cfe017407164563ca5aa7a0877d2ade",
        "codResult":"27"
      }
    RESPONSE
  end

  def successful_capture_response
    <<~RESPONSE
      {
        "cifrado":"SHA2",
        "parametros":"eyJudW1BdXQiOiIxMDEwMDAiLCJyZWZlcmVuY2lhIjoiMTIyMDQxNzIzMjIzMTAxODE4MjY1MTYwMDcwMDAiLCJjb2RBdXQiOiI5MDAifQ==",
        "firma":"9dead8ef2bf1f82cde1954cefaa9eca67b630effed7f71a5fd3bb3bd2e6e0808",
        "fecha":"231018182651711",
        "idProceso":"106900640-5b03c604fd76ecaf8715a29c482f3040"
      }
    RESPONSE
  end

  def failed_capture_response
    <<~RESPONSE
      {
        "fecha":"231018183020560",
        "idProceso":"106900640-d0cab45d2404960b65fe02445e97b7e2",
        "codResult":"807"
      }
    RESPONSE
  end

  def successful_purchase_response
    <<~RESPONSE
      {
        "cifrado":"SHA2",
        "parametros":"eyJudW1BdXQiOiIxMDEwMDAiLCJyZWZlcmVuY2lhIjoiMTIwMDQxNzIxOTIzMTAxODE3MjAwMDYwMDcwMDAiLCJjb2RBdXQiOiIwMDAifQ==",
        "firma":"da751ff809f54842ff26aed009cdce2d1a3b613cb3be579bb17af2e3ab36aa37",
        "fecha":"231018172001775",
        "idProceso":"106900640-bd4bd321774c51ec91cf24ca6bbca913"
      }
    RESPONSE
  end

  def failed_purchase_response
    <<~RESPONSE
      {
        "fecha":"231018174516102",
        "idProceso":"106900640-29c9d010e2e8c33872a4194df4e7a544",
        "codResult":"27"
      }
    RESPONSE
  end

  def successful_refund_response
    <<~RESPONSE
      {
        "cifrado":"SHA2",
        "parametros":"eyJtZXJjaGFudElEIjoiMTA2OTAwNjQwIiwiYWNxdWlyZXJCSU4iOiIwMDAwNTU0MDAwIiwidGVybWluYWxJRCI6IjAwMDAwMDAzIiwibnVtT3BlcmFjaW9uIjoiOGYyOTJiYTcwMmEzMTZmODIwMmEzZGFjY2JhMjFmZWMiLCJpbXBvcnRlIjoiMTAwIiwibnVtQXV0IjoiMTAxMDAwIiwicmVmZXJlbmNpYSI6IjEyMjA0MTcyMzUyMzEwMTgxODQ3NDI2MDA3MDAwIiwidGlwb09wZXJhY2lvbiI6IkQiLCJwYWlzIjoiMDAwIiwiY29kQXV0IjoiOTAwIn0=",
        "firma":"37591482e4d1dce6317c6d7de6a6c9b030c0618680eaefb4b42b0d8af3854773",
        "fecha":"231018184743876",
        "idProceso":"106900640-8f292ba702a316f8202a3daccba21fec"
      }
    RESPONSE
  end

  def failed_refund_response
    <<~RESPONSE
      {
        "fecha":"231018185809202",
        "idProceso":"106900640-fc93d837dba2003ad767d682e6eb5d5f",
        "codResult":"15"
      }
    RESPONSE
  end

  def successful_void_response
    <<~RESPONSE
      {
        "cifrado":"SHA2",
        "parametros":"eyJtZXJjaGFudElEIjoiMTA2OTAwNjQwIiwiYWNxdWlyZXJCSU4iOiIwMDAwNTU0MDAwIiwidGVybWluYWxJRCI6IjAwMDAwMDAzIiwibnVtT3BlcmFjaW9uIjoiMDNlMTkwNTU4NWZlMmFjM2M4N2NiYjY4NGUyMjYwZDUiLCJpbXBvcnRlIjoiMTAwIiwibnVtQXV0IjoiMTAxMDAwIiwicmVmZXJlbmNpYSI6IjE0MjA0MTcyNDAyMzEwMTgxOTA2MTY2MDA3MDAwIiwidGlwb09wZXJhY2lvbiI6IkQiLCJwYWlzIjoiMDAwIiwiY29kQXV0IjoiNDAwIn0=",
        "firma":"af55904b24cb083e6514b86456b107fdb8ebfc715aed228321ad959b13ef2b23",
        "fecha":"231018190618224",
        "idProceso":"106900640-03e1905585fe2ac3c87cbb684e2260d5"
      }
    RESPONSE
  end

  def failed_void_response
    <<~RESPONSE
      {
        "fecha":"231018191116348",
        "idProceso":"106900640-d7ca10f4fae36b2ad81f330eeb1ce509",
        "codResult":"15"
      }
    RESPONSE
  end
end
