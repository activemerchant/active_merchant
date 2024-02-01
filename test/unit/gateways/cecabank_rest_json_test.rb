require 'test_helper'

class CecabankJsonTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CecabankJsonGateway.new(
      merchant_id: '12345678',
      acquirer_bin: '12345678',
      terminal_id: '00000003',
      cypher_key: 'enc_key',
      encryption_key: '00112233445566778899AABBCCDDEEFF00001133445566778899AABBCCDDEEAA',
      initiator_vector: '0000000000000000'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      description: 'Store Purchase'
    }

    @three_d_secure = {
      version: '2.2.0',
      eci: '02',
      cavv: '4F80DF50ADB0F9502B91618E9B704790EABA35FDFC972DDDD0BF498C6A75E492',
      ds_transaction_id: 'a2bf089f-cefc-4d2c-850f-9153827fe070',
      acs_transaction_id: '18c353b0-76e3-4a4c-8033-f14fe9ce39dc',
      authentication_response_status: 'Y',
      three_ds_server_trans_id: '9bd9aa9c-3beb-4012-8e52-214cccb25ec5'
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

  def test_successful_stored_credentials_with_network_transaction_id_as_gsf
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    @options.merge!({ network_transaction_id: '12345678901234567890' })
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

  def test_purchase_without_exemption_type
    @options[:exemption_type] = nil
    @options[:three_d_secure] = @three_d_secure

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      data = JSON.parse(data)
      params = JSON.parse(Base64.decode64(data['parametros']))
      three_d_secure = JSON.parse(params['ThreeDsResponse'])
      assert_nil three_d_secure['exemption_type']
      assert_match params['exencionSCA'], 'NONE'
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_with_low_value_exemption
    @options[:exemption_type] = 'low_value_exemption'
    @options[:three_d_secure] = @three_d_secure

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      data = JSON.parse(data)
      params = JSON.parse(Base64.decode64(data['parametros']))
      three_d_secure = JSON.parse(params['ThreeDsResponse'])
      assert_match three_d_secure['exemption_type'], 'low_value_exemption'
      assert_match params['exencionSCA'], 'LOW'
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_with_transaction_risk_analysis_exemption
    @options[:exemption_type] = 'transaction_risk_analysis_exemption'
    @options[:three_d_secure] = @three_d_secure

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      data = JSON.parse(data)
      params = JSON.parse(Base64.decode64(data['parametros']))
      three_d_secure = JSON.parse(params['ThreeDsResponse'])
      assert_match three_d_secure['exemption_type'], 'transaction_risk_analysis_exemption'
      assert_match params['exencionSCA'], 'TRA'
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_without_threed_secure_data
    @options[:three_d_secure] = nil

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      data = JSON.parse(data)
      params = JSON.parse(Base64.decode64(data['parametros']))
      assert_nil params['ThreeDsResponse']
    end.respond_with(successful_purchase_response)
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def transcript
    <<~RESPONSE
      "opening connection to tpv.ceca.es:443...\nopened\nstarting SSL for tpv.ceca.es:443...\nSSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384\n<- \"POST /tpvweb/rest/procesos/compra HTTP/1.1\\r\\nContent-Type: application/json\\r\\nHost: tpv.ceca.es\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nContent-Length: 1397\\r\\n\\r\\n\"\n<- \"{\\\"parametros\\\":\\\"eyJhY2Npb24iOiJSRVNUX0FVVE9SSVpBQ0lPTiIsIm51bU9wZXJhY2lvbiI6ImYxZDdlNjBlMDYzMTJiNjI5NDEzOTUxM2YwMGQ2YWM4IiwiaW1wb3J0ZSI6IjEwMCIsInRpcG9Nb25lZGEiOiI5NzgiLCJleHBvbmVudGUiOiIyIiwiZW5jcnlwdGVkRGF0YSI6IjhlOWZhY2RmMDk5NDFlZTU0ZDA2ODRiNDNmNDNhMmRmOGM4ZWE5ODlmYTViYzYyOTM4ODFiYWVjNDFiYjU4OGNhNDc3MWI4OTFmNTkwMWVjMmJhZmJhOTBmMDNkM2NiZmUwNTJlYjAzMDU4Zjk1MGYyNzY4YTk3OWJiZGQxNmJlZmIyODQ2Zjc2MjkyYTFlODYzMDNhNTVhYTIzNjZkODA5MDEyYzlhNzZmYTZiOTQzOWNlNGQ3MzY5NTYwOTNhMDAwZTk5ZDMzNmVhZDgwMjBmOTk5YjVkZDkyMTFjMjE5ZWRhMjVmYjVkZDY2YzZiOTMxZWY3MjY5ZjlmMmVjZGVlYTc2MWRlMDEyZmFhMzg3MDlkODcyNTI4ODViYjI1OThmZDI2YTQzMzNhNDEwMmNmZTg4YjM1NTJjZWU0Yzc2IiwiZXhlbmNpb25TQ0EiOiJOT05FIiwiVGhyZWVEc1Jlc3BvbnNlIjoie1wiZXhlbXB0aW9uX3R5cGVcIjpudWxsLFwidGhyZWVfZHNfdmVyc2lvblwiOlwiMi4yLjBcIixcImRpcmVjdG9yeV9zZXJ2ZXJfdHJhbnNhY3Rpb25faWRcIjpcImEyYmYwODlmLWNlZmMtNGQyYy04NTBmLTkxNTM4MjdmZTA3MFwiLFwiYWNzX3RyYW5zYWN0aW9uX2lkXCI6XCIxOGMzNTNiMC03NmUzLTRhNGMtODAzMy1mMTRmZTljZTM5ZGNcIixcImF1dGhlbnRpY2F0aW9uX3Jlc3BvbnNlX3N0YXR1c1wiOlwiWVwiLFwidGhyZWVfZHNfc2VydmVyX3RyYW5zX2lkXCI6XCI5YmQ5YWE5Yy0zYmViLTQwMTItOGU1Mi0yMTRjY2NiMjVlYzVcIixcImVjb21tZXJjZV9pbmRpY2F0b3JcIjpcIjAyXCIsXCJlbnJvbGxlZFwiOm51bGwsXCJhbW91bnRcIjpcIjEwMFwifSIsIm1lcmNoYW50SUQiOiIxMDY5MDA2NDAiLCJhY3F1aXJlckJJTiI6IjAwMDA1NTQwMDAiLCJ0ZXJtaW5hbElEIjoiMDAwMDAwMDMifQ==\\\",\\\"cifrado\\\":\\\"SHA2\\\",\\\"firma\\\":\\\"ac7e5eb06b675be6c6f58487bbbaa1ddc07518e216cb0788905caffd911eea87\\\"}\"\n-> \"HTTP/1.1 200 OK\\r\\n\"\n-> \"Date: Thu, 14 Dec 2023 15:52:41 GMT\\r\\n\"\n-> \"Server: Apache\\r\\n\"\n-> \"Strict-Transport-Security: max-age=31536000; includeSubDomains\\r\\n\"\n-> \"X-XSS-Protection: 1; mode=block\\r\\n\"\n-> \"X-Content-Type-Options: nosniff\\r\\n\"\n-> \"Content-Length: 103\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"Content-Type: application/json\\r\\n\"\n-> \"\\r\\n\"\nreading 103 bytes...\n-> \"{\\\"cifrado\\\":\\\"SHA2\\\",\\\"parametros\\\":\\\"eyJudW1BdXQiOiIxMDEwMDAiLCJyZWZlcmVuY2lhIjoiMTIwMDQzOTQ4MzIzMTIxNDE2NDg0NjYwMDcwMDAiLCJjb2RBdXQiOiIwMDAifQ==\\\",\\\"firma\\\":\\\"5ce066be8892839d6aa6da15405c9be8987642f4245fac112292084a8532a538\\\",\\\"fecha\\\":\\\"231214164846089\\\",\\\"idProceso\\\":\\\"106900640-adeda8b09b84630d6247b53748ab9c66\\\"}\"\nread 300 bytes\nConn close\n"
    RESPONSE
  end

  def scrubbed_transcript
    <<~RESPONSE
      "opening connection to tpv.ceca.es:443...\nopened\nstarting SSL for tpv.ceca.es:443...\nSSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384\n<- \"POST /tpvweb/rest/procesos/compra HTTP/1.1\\r\\nContent-Type: application/json\\r\\nHost: tpv.ceca.es\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nContent-Length: 1397\\r\\n\\r\\n\"\n<- \"{\\\"parametros\\\":\\\"eyJhY2Npb24iOiJSRVNUX0FVVE9SSVpBQ0lPTiIsIm51bU9wZXJhY2lvbiI6ImYxZDdlNjBlMDYzMTJiNjI5NDEzOTUxM2YwMGQ2YWM4IiwiaW1wb3J0ZSI6IjEwMCIsInRpcG9Nb25lZGEiOiI5NzgiLCJleHBvbmVudGUiOiIyIiwiZW5jcnlwdGVkRGF0YSI6ImEyZjczODJjMDdiZGYxYWZiZDE3YWJiMGQ3NTNmMzJlYmIzYTFjNGY4ZGNmMjYxZWQ2YTkxMmQ3MzlkNzE2ZjA1MDBiOTg5NzliY2I1MzY0NTRlMGE2ZmJiYzVlNjJlNjgxZjgyMTEwNGFiNjUzOTYyMjA4NmMwZGM2MzgyYWRmNjRkOGFjZWYwY2U5MDBjMzJlZmFjM2Q5YmJhM2UxZGY3NDY2NzU3NWNiYjMzYTczMDU3NGYzMzJmMGNlNTliOTU5MzM4NjQxOGUwYjIyNDJiOTJmZDg2MDczM2QxNzhiZDZkNGIyZGMwMzE2ZGRmNTAzMTQ5N2I1YWViMjRlMzQiLCJleGVuY2lvblNDQSI6Ik5PTkUiLCJUaHJlZURzUmVzcG9uc2UiOiJ7XCJleGVtcHRpb25fdHlwZVwiOm51bGwsXCJ0aHJlZV9kc192ZXJzaW9uXCI6XCIyLjIuMFwiLFwiZGlyZWN0b3J5X3NlcnZlcl90cmFuc2FjdGlvbl9pZFwiOlwiYTJiZjA4OWYtY2VmYy00ZDJjLTg1MGYtOTE1MzgyN2ZlMDcwXCIsXCJhY3NfdHJhbnNhY3Rpb25faWRcIjpcIjE4YzM1M2IwLTc2ZTMtNGE0Yy04MDMzLWYxNGZlOWNlMzlkY1wiLFwiYXV0aGVudGljYXRpb25fcmVzcG9uc2Vfc3RhdHVzXCI6XCJZXCIsXCJ0aHJlZV9kc19zZXJ2ZXJfdHJhbnNfaWRcIjpcIjliZDlhYTljLTNiZWItNDAxMi04ZTUyLTIxNGNjY2IyNWVjNVwiLFwiZWNvbW1lcmNlX2luZGljYXRvclwiOlwiMDJcIixcImVucm9sbGVkXCI6bnVsbCxcImFtb3VudFwiOlwiMTAwXCJ9IiwibWVyY2hhbnRJRCI6IjEwNjkwMDY0MCIsImFjcXVpcmVyQklOIjoiMDAwMDU1NDAwMCIsInRlcm1pbmFsSUQiOiIwMDAwMDAwMyJ9\\\",\\\"cifrado\\\":\\\"SHA2\\\",\\\"firma\\\":\\\"ac7e5eb06b675be6c6f58487bbbaa1ddc07518e216cb0788905caffd911eea87\\\"}\"\n-> \"HTTP/1.1 200 OK\\r\\n\"\n-> \"Date: Thu, 14 Dec 2023 15:52:41 GMT\\r\\n\"\n-> \"Server: Apache\\r\\n\"\n-> \"Strict-Transport-Security: max-age=31536000; includeSubDomains\\r\\n\"\n-> \"X-XSS-Protection: 1; mode=block\\r\\n\"\n-> \"X-Content-Type-Options: nosniff\\r\\n\"\n-> \"Content-Length: 103\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"Content-Type: application/json\\r\\n\"\n-> \"\\r\\n\"\nreading 103 bytes...\n-> \"{\\\"cifrado\\\":\\\"SHA2\\\",\\\"parametros\\\":\\\"eyJudW1BdXQiOiIxMDEwMDAiLCJyZWZlcmVuY2lhIjoiMTIwMDQzOTQ4MzIzMTIxNDE2NDg0NjYwMDcwMDAiLCJjb2RBdXQiOiIwMDAifQ==\\\",\\\"firma\\\":\\\"5ce066be8892839d6aa6da15405c9be8987642f4245fac112292084a8532a538\\\",\\\"fecha\\\":\\\"231214164846089\\\",\\\"idProceso\\\":\\\"106900640-adeda8b09b84630d6247b53748ab9c66\\\"}\"\nread 300 bytes\nConn close\n"
    RESPONSE
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
