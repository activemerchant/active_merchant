require 'test_helper'

class PlaceToPayTest < Test::Unit::TestCase
  include CommStub
  def setup
    @gateway = PlaceToPayGateway.new(login: 'login', secret_key: 'secret_key')
    
    @amount = 100

    @payer = {
      name: "Erika",
      surname: "Howe",
      email: "cwilliamson@hotmail.com",
      documentType: "CC",
      document: "3572264088",
      mobile: "3006108300"
    }
    payment = {
      description: 'Cum vitae et consequatur quas adipisci ut rem.',
      amount: {
        currency: @gateway.default_currency,
        total: @amount
      }
    }
    instrument = {
      card: {
        installments: 1
      }
    }

    @credit_card_approved_visa = credit_card('4110760000000081', month: 12, year: 2023, verification_value: '123', first_name: @payer[:name], last_name: @payer[:surname])
    @credit_card_rejected_visa = credit_card('4110760000000016', month: 12, year: 2023, verification_value: '123', first_name: @payer[:name], last_name: @payer[:surname])

    @options = {
      payer: @payer,
      payment: payment,
      instrument: instrument
    }

  end

  def test_successful_purchase

    @options[:payment][:reference] = "TEST_" + Time.now.strftime("%Y%m%d_%H%M%S%3N")

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card_approved_visa, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<description>.+<\/description>/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'Aprobada', response.message
    assert_equal '999999', response.authorization
    assert response.test? 
  end

  def test_failed_purchase
    #@gateway.expects(:ssl_post).returns(failed_purchase_response)

    @options[:payment][:reference] = "TEST_" + Time.now.strftime("%Y%m%d_%H%M%S%3N")
    response = @gateway.purchase(@amount, @credit_card_rejected_visa, @options)
    #assert_failure response
    assert_equal 'Rechazada', response.message
    #assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code  
  end

  # def test_successful_refund; end

  # def test_failed_refund; end

  # def test_successful_void; end

  # def test_failed_void; end

  # def test_successful_verify; end

  # def test_successful_verify_with_failed_void; end

  # def test_failed_verify; end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to api-co-dev.placetopay.ws:443...
      opened
      starting SSL for api-co-dev.placetopay.ws:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256
      <- "POST /gateway/process HTTP/1.1\r\nContent-Type: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: api-co-dev.placetopay.ws\r\nContent-Length: 603\r\n\r\n"
      <- "{\"auth\":{\"login\":\"11caf20f5cd408c9b22c7f0693e2f676\",\"tranKey\":\"j0eeo7QkGKbQaL+oBTRlYC20Zup/yjE73nDfiaPbj8U=\",\"seed\":\"2023-01-03T14:41:46-03:00\",\"nonce\":\"NDVjNDhjY2UyZTJkN2ZiZGVhMWFmYzUxYzdjNmFkMjY=\"},\"payer\":{\"name\":\"Erika\",\"surname\":\"Howe\",\"email\":\"cwilliamson@hotmail.com\",\"documentType\":\"CC\",\"document\":\"3572264088\",\"mobile\":\"3006108300\"},\"payment\":{\"description\":\"Cum vitae et consequatur quas adipisci ut rem.\",\"amount\":{\"currency\":\"COP\",\"total\":100},\"reference\":\"transcript_20230103_144146279\"},\"instrument\":{\"card\":{\"installments\":1,\"number\":\"4110760000000081\",\"expiration\":\"12/12\",\"cvv\":\"123\"}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 988\r\n"
      -> "Connection: close\r\n"
      -> "Date: Tue, 03 Jan 2023 17:41:47 GMT\r\n"
      -> "x-amzn-RequestId: 2f37d55a-3fd2-47fe-a767-aa7a58d3267b\r\n"
      -> "x-amz-apigw-id: eLVSMHTSIAMFuLQ=\r\n"
      -> "Cache-Control: no-cache, private\r\n"
      -> "X-Amzn-Trace-Id: Root=1-63b468da-0b86c22c391bd4055f050798;Sampled=0\r\n"
      -> "x-amzn-Remapped-Date: Tue, 03 Jan 2023 17:41:47 GMT\r\n"
      -> "X-Cache: Miss from cloudfront\r\n"
      -> "Via: 1.1 dfe38bddfe2e252d54a7cc2e361b6cb6.cloudfront.net (CloudFront)\r\n"
      -> "X-Amz-Cf-Pop: EZE50-P1\r\n"
      -> "X-Amz-Cf-Id: fdjSPF-Akmh9QVLa-RX108u5K2P0GB5E4LPhWVVXomgDHMZLWN3TbQ==\r\n"
      -> "\r\n"
      reading 988 bytes...
      -> "{\"status\":{\"status\":\"APPROVED\",\"reason\":\"00\",\"message\":\"Aprobada\",\"date\":\"2023-01-03T12:41:47-05:00\"},\"date\":\"2023-01-03T12:41:47-05:00\",\"transactionDate\":\"2023-01-03T12:41:47-05:00\",\"internalReference\":418653,\"reference\":\"transcript_20230103_144146279\",\"paymentMethod\":\"ID_VS\",\"franchise\":\"visa\",\"franchiseName\":\"Visa\",\"issuerName\":\"BANCO DE GUAYAQUIL, S.A.\",\"amount\":{\"currency\":\"COP\",\"total\":100},\"conversion\":{\"from\":{\"currency\":\"COP\",\"total\":100},\"to\":{\"currency\":\"USD\",\"total\":0.02},\"factor\":0.000206},\"authorization\":\"999999\",\"receipt\":\"418653\",\"type\":\"AUTH_ONLY\",\"refunded\":false,\"lastDigits\":\"0081\",\"provider\":\"INTERDIN\",\"discount\":null,\"processorFields\":{\"id\":\"4294789932ba8aa7ec09d1c227ebc35f\",\"b24\":\"00\"},\"additional\":{\"merchantCode\":\"12345678\",\"terminalNumber\":\"12345678\",\"credit\":{\"code\":1,\"type\":\"00\",\"groupCode\":\"C\",\"installments\":1},\"totalAmount\":0.02,\"interestAmount\":0,\"installmentAmount\":0.02,\"iceAmount\":0,\"batch\":null,\"line\":null,\"bin\":\"411076\",\"expiration\":\"1212\"}}"
      read 988 bytes
      Conn close
      PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to api-co-dev.placetopay.ws:443...
      opened
      starting SSL for api-co-dev.placetopay.ws:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256
      <- "POST /gateway/process HTTP/1.1\r\nContent-Type: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: api-co-dev.placetopay.ws\r\nContent-Length: 603\r\n\r\n"
      <- "{\"auth\":{\"login\":\"11caf20f5cd408c9b22c7f0693e2f676\",\"tranKey\":\"[FILTERED]\",\"seed\":\"2023-01-03T14:41:46-03:00\",\"nonce\":\"NDVjNDhjY2UyZTJkN2ZiZGVhMWFmYzUxYzdjNmFkMjY=\"},\"payer\":{\"name\":\"Erika\",\"surname\":\"Howe\",\"email\":\"cwilliamson@hotmail.com\",\"documentType\":\"CC\",\"document\":\"3572264088\",\"mobile\":\"3006108300\"},\"payment\":{\"description\":\"Cum vitae et consequatur quas adipisci ut rem.\",\"amount\":{\"currency\":\"COP\",\"total\":100},\"reference\":\"transcript_20230103_144146279\"},\"instrument\":{\"card\":{\"installments\":1,\"number\":\"[FILTERED]\",\"expiration\":\"12/12\",\"cvv\":\"[FILTERED]\"}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 988\r\n"
      -> "Connection: close\r\n"
      -> "Date: Tue, 03 Jan 2023 17:41:47 GMT\r\n"
      -> "x-amzn-RequestId: 2f37d55a-3fd2-47fe-a767-aa7a58d3267b\r\n"
      -> "x-amz-apigw-id: eLVSMHTSIAMFuLQ=\r\n"
      -> "Cache-Control: no-cache, private\r\n"
      -> "X-Amzn-Trace-Id: Root=1-63b468da-0b86c22c391bd4055f050798;Sampled=0\r\n"
      -> "x-amzn-Remapped-Date: Tue, 03 Jan 2023 17:41:47 GMT\r\n"
      -> "X-Cache: Miss from cloudfront\r\n"
      -> "Via: 1.1 dfe38bddfe2e252d54a7cc2e361b6cb6.cloudfront.net (CloudFront)\r\n"
      -> "X-Amz-Cf-Pop: EZE50-P1\r\n"
      -> "X-Amz-Cf-Id: fdjSPF-Akmh9QVLa-RX108u5K2P0GB5E4LPhWVVXomgDHMZLWN3TbQ==\r\n"
      -> "\r\n"
      reading 988 bytes...
      -> "{\"status\":{\"status\":\"APPROVED\",\"reason\":\"00\",\"message\":\"Aprobada\",\"date\":\"2023-01-03T12:41:47-05:00\"},\"date\":\"2023-01-03T12:41:47-05:00\",\"transactionDate\":\"2023-01-03T12:41:47-05:00\",\"internalReference\":418653,\"reference\":\"transcript_20230103_144146279\",\"paymentMethod\":\"ID_VS\",\"franchise\":\"visa\",\"franchiseName\":\"Visa\",\"issuerName\":\"BANCO DE GUAYAQUIL, S.A.\",\"amount\":{\"currency\":\"COP\",\"total\":100},\"conversion\":{\"from\":{\"currency\":\"COP\",\"total\":100},\"to\":{\"currency\":\"USD\",\"total\":0.02},\"factor\":0.000206},\"authorization\":\"999999\",\"receipt\":\"418653\",\"type\":\"AUTH_ONLY\",\"refunded\":false,\"lastDigits\":\"0081\",\"provider\":\"INTERDIN\",\"discount\":null,\"processorFields\":{\"id\":\"4294789932ba8aa7ec09d1c227ebc35f\",\"b24\":\"00\"},\"additional\":{\"merchantCode\":\"12345678\",\"terminalNumber\":\"12345678\",\"credit\":{\"code\":1,\"type\":\"00\",\"groupCode\":\"C\",\"installments\":1},\"totalAmount\":0.02,\"interestAmount\":0,\"installmentAmount\":0.02,\"iceAmount\":0,\"batch\":null,\"line\":null,\"bin\":\"411076\",\"expiration\":\"1212\"}}"
      read 988 bytes
      Conn close
      POST_SCRUBBED
  end

  def successful_purchase_response
    <<-RESPONSE
    {
      "status": {
        "status": "APPROVED",
        "reason": "00",
        "message": "Aprobada",
        "date": "2023-01-03T13:02:19-05:00"
      },
      "date": "2023-01-03T13:02:19-05:00",
      "transactionDate": "2023-01-03T13:02:19-05:00",
      "internalReference": 418655,
      "reference": "TEST_20230103_150219114",
      "paymentMethod": "ID_VS",
      "franchise": "visa",
      "franchiseName": "Visa",
      "issuerName": "BANCO DE GUAYAQUIL, S.A.",
      "amount": {
        "currency": "COP",
        "total": 100
      },
      "conversion": {
        "from": {
          "currency": "COP",
          "total": 100
        },
        "to": {
          "currency": "USD",
          "total": 0.02
        },
        "factor": 0.000206
      },
      "authorization": "999999",
      "receipt": "418655",
      "type": "AUTH_ONLY",
      "refunded": false,
      "lastDigits": "0081",
      "provider": "INTERDIN",
      "discount": null,
      "processorFields": {
        "id": "d87dee7109eca8d1d0a019788a4a06e9",
        "b24": "00"
      },
      "additional": {
        "merchantCode": "12345678",
        "terminalNumber": "12345678",
        "credit": {
          "code": 1,
          "type": "00",
          "groupCode": "C",
          "installments": 1
        },
        "totalAmount": 0.02,
        "interestAmount": 0,
        "installmentAmount": 0.02,
        "iceAmount": 0,
        "batch": null,
        "line": null,
        "bin": "411076",
        "expiration": "1212"
      }
    }
    RESPONSE
  end

  def failed_purchase_response; 
    <<-RESPONSE
    {
      "status": {
        "status": "REJECTED",
        "reason": "05",
        "message": "Rechazada",
        "date": "2023-01-03T13:04:05-05:00"
      },
      "date": "2023-01-03T13:04:05-05:00",
      "transactionDate": "2023-01-03T13:04:05-05:00",
      "internalReference": 418656,
      "reference": "TEST_20230103_150404971",
      "paymentMethod": "ID_VS",
      "franchise": "visa",
      "franchiseName": "Visa",
      "issuerName": "BANCO DE GUAYAQUIL, S.A.",
      "amount": {
        "currency": "COP",
        "total": 100
      },
      "conversion": {
        "from": {
          "currency": "COP",
          "total": 100
        },
        "to": {
          "currency": "USD",
          "total": 0.02
        },
        "factor": 0.000206
      },
      "authorization": "000000",
      "receipt": "418656",
      "type": "AUTH_ONLY",
      "refunded": false,
      "lastDigits": "0016",
      "provider": "INTERDIN",
      "discount": null,
      "processorFields": {
        "id": "b29bd9593277694a941db80267eae4ab",
        "b24": "05"
      },
      "additional": {
        "merchantCode": "12345678",
        "terminalNumber": "12345678",
        "credit": {
          "code": 1,
          "type": "00",
          "groupCode": "C",
          "installments": 1
        },
        "totalAmount": 0.02,
        "interestAmount": 0,
        "installmentAmount": 0.02,
        "iceAmount": 0,
        "batch": null,
        "line": null,
        "bin": "411076",
        "expiration": "1212"
      }
    }
    RESPONSE
  end

  def successful_refund_response; end

  def failed_refund_response; end

  def successful_void_response; end

  def failed_void_response; end
end
