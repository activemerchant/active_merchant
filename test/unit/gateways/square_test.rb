require 'test_helper'

class SquareTest < Test::Unit::TestCase
  def setup
    @gateway = SquareGateway.new(access_token: 'token')

    @amount = 200
    @refund_amount = 100

    @card_nonce = 'cnon:card-nonce-ok'
    @declined_card_nonce = 'cnon:card-nonce-declined'

    @options = {
      email: 'customer@example.com',
      billing_address: address(),
    }
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @card_nonce, @options)

    assert_instance_of Response, response
    assert_success response
    assert_equal 'iqrBxAil6rmDtr7cak9g9WO8uaB', response.authorization
    assert_equal 'APPROVED', response.params['payment']['status']
    assert response.test?
  end

  def test_unsuccessful_authorize
    @gateway.expects(:ssl_request).returns(unsuccessful_authorize_response)

    assert response = @gateway.authorize(@amount, @card_nonce, @options)

    assert_instance_of Response, response
    assert_success response
    assert_equal 'iqrBxAil6rmDtr7cak9g9WO8uaB', response.authorization
    assert_equal 'FAILED', response.params['payment']['status']
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_purchase_capture_reponse)

    assert response = @gateway.capture('EdMl5lwmBxd3ZvsvinkAT5LtvaB')

    assert_instance_of Response, response
    assert_success response
    assert_equal 'EdMl5lwmBxd3ZvsvinkAT5LtvaB', response.authorization
    assert_equal 'COMPLETED', response.params['payment']['status']
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_purchase_void_response)

    assert response = @gateway.void('EdMl5lwmBxd3ZvsvinkAT5LtvaB')

    assert_instance_of Response, response
    assert_success response
    assert_equal 'EdMl5lwmBxd3ZvsvinkAT5LtvaB', response.authorization
    assert_equal 'CANCELED', response.params['payment']['status']
    assert response.test?
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @card_nonce, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'iqrBxAil6rmDtr7cak9g9WO8uaB', response.authorization
    assert_equal 'COMPLETED', response.params['payment']['status']
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_request).returns(unsuccessful_purchase_response)

    assert response = @gateway.purchase(@amount, @card_nonce, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'iqrBxAil6rmDtr7cak9g9WO8uaB', response.authorization
    assert_equal 'FAILED', response.params['payment']['status']
    assert response.test?
  end

  def test_successful_purchase_then_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    assert response = @gateway.refund(@refund_amount, 'UNOE3kv2BZwqHlJ830RCt5YCuaB', @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'UNOE3kv2BZwqHlJ830RCt5YCuaB_xVteEWVFkXDvKN1ddidfJWipt8p9whmElKT5mZtJ7wZ', response.authorization
    assert_equal 'PENDING', response.params['refund']['status']
    assert_equal @refund_amount, response.params['refund']['amount_money']['amount']
    assert_equal 'Customer Canceled', response.params['refund']['reason']
    assert response.test?
  end

  def test_successful_store
    @gateway.expects(:ssl_request).twice.returns(successful_new_customer_response, successful_new_card_response)

    @options[:idempotency_key] = SecureRandom.hex(10)

    assert response = @gateway.store(@card_nonce, @options)

    assert_instance_of MultiResponse, response
    assert_success response
    assert_equal 2, response.responses.size

    customer_response = response.responses[0]
    assert_not_nil customer_response.params['customer']['id']

    card_response = response.responses[1]
    assert_not_nil card_response.params['card']['id']

    assert response.test?
  end

  def test_successful_store_then_update
    @gateway.expects(:ssl_request).returns(successful_update_response)

    @options[:billing_address][:name] = 'Tom Smith'
    assert response = @gateway.update_customer('JDKYHBWT1D4F8MFH63DBMEN8Y4', @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'JDKYHBWT1D4F8MFH63DBMEN8Y4', response.authorization
    assert_equal 'Tom', response.params['customer']['given_name']
    assert_equal 'Smith', response.params['customer']['family_name']
    assert response.test?
  end

  def test_transcript_scrubbing
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    "opening connection to connect.squareupsandbox.com:443...\n" \
    "opened\n" \
    "starting SSL for connect.squareupsandbox.com:443...\n" \
    "SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256\n" \
    "<- \"POST /v2/payments HTTP/1.1\\r\\nContent-Type: application/json\\r\\nAuthorization: Bearer 098123098123098123\\r\\nSquare-Version: 2019-10-23\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nHost: connect.squareupsandbox.com\\r\\nContent-Length: 142\\r\\n\\r\\n\"\n" \
    "<- \"{\\\"source_id\\\":\\\"cnon:card-nonce-ok\\\",\\\"idempotency_key\\\":\\\"af43257576422c182b5c\\\",\\\"amount_money\\\":{\\\"amount\\\":200,\\\"currency\\\":\\\"USD\\\"},\\\"autocomplete\\\":true}\"\n" \
    "-> \"HTTP/1.1 200 OK\\r\\n\"\n" \
    "-> \"Date: Mon, 11 Nov 2019 23:35:36 GMT\\r\\n\"\n" \
    "-> \"Frame-Options: DENY\\r\\n\"\n" \
    "-> \"X-Frame-Options: DENY\\r\\n\"\n" \
    "-> \"X-Content-Type-Options: nosniff\\r\\n\"\n" \
    "-> \"X-Xss-Protection: 1; mode=block\\r\\n\"\n" \
    "-> \"Content-Type: application/json\\r\\n\"\n" \
    "-> \"Square-Version: 2019-10-23\\r\\n\"\n" \
    "-> \"Squareup--Connect--V2--Common--Versionmetadata-Bin: CgoyMDE5LTEwLTIz\\r\\n\"\n" \
    "-> \"Vary: Accept-Encoding, User-Agent\\r\\n\"\n" \
    "-> \"Content-Encoding: gzip\\r\\n\"\n" \
    "-> \"Content-Length: 474\\r\\n\"\n" \
    "-> \"X-Envoy-Upstream-Service-Time: 441\\r\\n\"\n" \
    "-> \"Strict-Transport-Security: max-age=604800; includeSubDomains\\r\\n\"\n" \
    "-> \"Server: envoy\\r\\n\"\n" \
    "-> \"Connection: close\\r\\n\"\n" \
    "-> \"\\r\\n\"\n" \
    "reading 474 bytes...\n" \
    "-> \"\\x1F\\x8B\\b\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x8DR\\xDB\\x8E\\xDA0\\x10}\\xEFW ?\\xAE\\x96*\\xCE\\r\\x96\\xB7\\x00NUn\\xCB\\xE6\\xB6\\xB0/\\x96\\x93\\x98\\x12\\x1A\\x92`;n\\xB3+\\xFE\\xBDv\\xE8J\\xBC\\xB5R$\\xC7\\xE7\\x9C\\x9993\\x9E\\x0F\\xD0\\x90\\xEEL+\\x01&\\x83\\x0FP\\xE4\\xEA\\x00?\\xD3\\xD4w.\\x87\\xE2\\xC2\\x02W4\\x87e\\xB7\\x90\\xE9z3:\\xB5d\\n\\x1EA\\xC6(\\x114\\xC7D\\x87\\x00\\xD3\\x80OC\\b\\xD5\\x17\\x99\\xD6\\xC4r&\\x96\\xFB\\xD5u\\xE1\\x9B\\x12\\xB6M\\xFE\\x0F\\xE1\\xD8\\x18i!9\\xD7m%\\xF0\\xB9\\xAEh\\xD7\\xDB\\xB8\\x01\\xEA\\xD74\\fU\\xB0e\\x8CV\\x99\\xA6@\\x1C\\xCE\\xC1\\xF5\\x11pAD\\xCB50{^oW(Bs\\x95\\x87\\xD7-\\xCB(\\x16]C{\\xCA\\v4\\x9A\\x11\\x96\\xE3\\x9C\\nR\\x94\\xBC\\xCF~\\x17\\xECm\\xA38@\\x9F\\xAA\\x9E\\xED\\xE5)#U?\\no\\x8D\\x82\\xEF3o\\x83\\xD1n\\e\\xA00T\\xCA\\x92p\\x81mM\\xBA\\x8Ec(\\x80\\xFEn\\xB4wqT\\x18\\x84\\xB7{G\\t\\xEB\\xFD\\x9B\\n8\\x14\\xD5\\x0F\\xCA\\x1AV\\xF4=\\x01~\\x19\\xC2\\xE1;\\x1A\\xA1#]]x\\x11o\\xA4\\xB4\\xDB\\xE3\\x8E\\e\\xBB(x:m=_\\x8E\\xE1\\xCB\\xF8\\xB48\\x99\\x81\\x9D\\x8B\\xD7\\x83\\xBD\\x92\\xBF\\xFC\\xF5\\xF4\\xBD\\xC4\\xE1\\xC8\\xAD\\x17\\\"\\xE7\\x8E/\\x13OUN\\x8BJ'\\xB4F\\xD0t-=\\x17\\xF5\\x8E\\xAC\\xC3g*\\x8Euo\\x7F\\x89\\xF6\\xB7\\xEE\\xA4\\xC4wm'\\t\\xF6f3\\xB4\\xBD\\x8D\\x8DH~GzIxOj\\x82\\xEA\\xFDP#\\xE4\\x19+\\x1AQ\\xD4}\\xD1\\xF0e\\xF00G\\xBE\\x17\\xAF\\xA2A\\x84\\xC2h\\xA0\\x82\\x9E\\xE3M\\xA4m\\x94uF\\xB4\\x0E\\xDF\\xF6\\xC9L\\\"?\\xD9{\\xD6\\xDA0\\x96H\\xE5\\xACYN\\xD9_\\x8E\\xBA\\x94Ve{\\x99\\xDA\\xAF<\\x90\\xB4\\x81\\xD2\\x87\\xDF\\xA6\\xE1f\\x15Fo{\\xA5\\x15\\xB5 \\xE5\\xFF\\xAF\\xC6\\xF5\\xFA\\xE5\\x0F\\xF7\\x80\\xC4p\\xD2\\x02\\x00\\x00\"\n" \
    "read 474 bytes\n" \
    "Conn close\n"
  end

  def post_scrubbed
    "opening connection to connect.squareupsandbox.com:443...\n" \
    "opened\n" \
    "starting SSL for connect.squareupsandbox.com:443...\n" \
    "SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256\n" \
    "<- \"POST /v2/payments HTTP/1.1\\r\\nContent-Type: application/json\\r\\nAuthorization: Bearer [FILTERED]\\r\\nSquare-Version: 2019-10-23\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nHost: connect.squareupsandbox.com\\r\\nContent-Length: 142\\r\\n\\r\\n\"\n" \
    "<- \"{\\\"source_id\\\":[FILTERED],\\\"idempotency_key\\\":\\\"af43257576422c182b5c\\\",\\\"amount_money\\\":{\\\"amount\\\":200,\\\"currency\\\":\\\"USD\\\"},\\\"autocomplete\\\":true}\"\n" \
    "-> \"HTTP/1.1 200 OK\\r\\n\"\n" \
    "-> \"Date: Mon, 11 Nov 2019 23:35:36 GMT\\r\\n\"\n" \
    "-> \"Frame-Options: DENY\\r\\n\"\n" \
    "-> \"X-Frame-Options: DENY\\r\\n\"\n" \
    "-> \"X-Content-Type-Options: nosniff\\r\\n\"\n" \
    "-> \"X-Xss-Protection: 1; mode=block\\r\\n\"\n" \
    "-> \"Content-Type: application/json\\r\\n\"\n" \
    "-> \"Square-Version: 2019-10-23\\r\\n\"\n" \
    "-> \"Squareup--Connect--V2--Common--Versionmetadata-Bin: CgoyMDE5LTEwLTIz\\r\\n\"\n" \
    "-> \"Vary: Accept-Encoding, User-Agent\\r\\n\"\n" \
    "-> \"Content-Encoding: gzip\\r\\n\"\n" \
    "-> \"Content-Length: 474\\r\\n\"\n" \
    "-> \"X-Envoy-Upstream-Service-Time: 441\\r\\n\"\n" \
    "-> \"Strict-Transport-Security: max-age=604800; includeSubDomains\\r\\n\"\n" \
    "-> \"Server: envoy\\r\\n\"\n" \
    "-> \"Connection: close\\r\\n\"\n" \
    "-> \"\\r\\n\"\n" \
    "reading 474 bytes...\n" \
    "-> \"\\x1F\\x8B\\b\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x8DR\\xDB\\x8E\\xDA0\\x10}\\xEFW ?\\xAE\\x96*\\xCE\\r\\x96\\xB7\\x00NUn\\xCB\\xE6\\xB6\\xB0/\\x96\\x93\\x98\\x12\\x1A\\x92`;n\\xB3+\\xFE\\xBDv\\xE8J\\xBC\\xB5R$\\xC7\\xE7\\x9C\\x9993\\x9E\\x0F\\xD0\\x90\\xEEL+\\x01&\\x83\\x0FP\\xE4\\xEA\\x00?\\xD3\\xD4w.\\x87\\xE2\\xC2\\x02W4\\x87e\\xB7\\x90\\xE9z3:\\xB5d\\n\\x1EA\\xC6(\\x114\\xC7D\\x87\\x00\\xD3\\x80OC\\b\\xD5\\x17\\x99\\xD6\\xC4r&\\x96\\xFB\\xD5u\\xE1\\x9B\\x12\\xB6M\\xFE\\x0F\\xE1\\xD8\\x18i!9\\xD7m%\\xF0\\xB9\\xAEh\\xD7\\xDB\\xB8\\x01\\xEA\\xD74\\fU\\xB0e\\x8CV\\x99\\xA6@\\x1C\\xCE\\xC1\\xF5\\x11pAD\\xCB50{^oW(Bs\\x95\\x87\\xD7-\\xCB(\\x16]C{\\xCA\\v4\\x9A\\x11\\x96\\xE3\\x9C\\nR\\x94\\xBC\\xCF~\\x17\\xECm\\xA38@\\x9F\\xAA\\x9E\\xED\\xE5)#U?\\no\\x8D\\x82\\xEF3o\\x83\\xD1n\\e\\xA00T\\xCA\\x92p\\x81mM\\xBA\\x8Ec(\\x80\\xFEn\\xB4wqT\\x18\\x84\\xB7{G\\t\\xEB\\xFD\\x9B\\n8\\x14\\xD5\\x0F\\xCA\\x1AV\\xF4=\\x01~\\x19\\xC2\\xE1;\\x1A\\xA1#]]x\\x11o\\xA4\\xB4\\xDB\\xE3\\x8E\\e\\xBB(x:m=_\\x8E\\xE1\\xCB\\xF8\\xB48\\x99\\x81\\x9D\\x8B\\xD7\\x83\\xBD\\x92\\xBF\\xFC\\xF5\\xF4\\xBD\\xC4\\xE1\\xC8\\xAD\\x17\\\"\\xE7\\x8E/\\x13OUN\\x8BJ'\\xB4F\\xD0t-=\\x17\\xF5\\x8E\\xAC\\xC3g*\\x8Euo\\x7F\\x89\\xF6\\xB7\\xEE\\xA4\\xC4wm'\\t\\xF6f3\\xB4\\xBD\\x8D\\x8DH~GzIxOj\\x82\\xEA\\xFDP#\\xE4\\x19+\\x1AQ\\xD4}\\xD1\\xF0e\\xF00G\\xBE\\x17\\xAF\\xA2A\\x84\\xC2h\\xA0\\x82\\x9E\\xE3M\\xA4m\\x94uF\\xB4\\x0E\\xDF\\xF6\\xC9L\\\"?\\xD9{\\xD6\\xDA0\\x96H\\xE5\\xACYN\\xD9_\\x8E\\xBA\\x94Ve{\\x99\\xDA\\xAF<\\x90\\xB4\\x81\\xD2\\x87\\xDF\\xA6\\xE1f\\x15Fo{\\xA5\\x15\\xB5 \\xE5\\xFF\\xAF\\xC6\\xF5\\xFA\\xE5\\x0F\\xF7\\x80\\xC4p\\xD2\\x02\\x00\\x00\"\n" \
    "read 474 bytes\n" \
    "Conn close\n"
  end

  def successful_authorize_response
    <<-RESPONSE
    {
      "payment": {
        "id": "iqrBxAil6rmDtr7cak9g9WO8uaB",
        "created_at": "2019-07-10T13:23:49.154Z",
        "updated_at": "2019-07-10T13:23:49.446Z",
        "amount_money": {
          "amount": 200,
          "currency": "USD"
        },
        "app_fee_money": {
          "amount": 10,
          "currency": "USD"
        },
        "total_money": {
          "amount": 200,
          "currency": "USD"
        },
        "status": "APPROVED",
        "source_type": "CARD",
        "card_details": {
          "status": "CAPTURED",
          "card": {
            "card_brand": "VISA",
            "last_4": "2796",
            "exp_month": 7,
            "exp_year": 2026,
            "fingerprint": "sq-1-TpmjbNBMFdibiIjpQI5LiRgNUBC7u1689i0TgHjnlyHEWYB7tnn-K4QbW4ttvtaqXw"
          },
          "entry_method": "ON_FILE",
          "cvv_status": "CVV_ACCEPTED",
          "avs_status": "AVS_ACCEPTED",
          "auth_result_code": "nsAyY2"
        },
        "location_id": "XK3DBG77NJBFX",
        "order_id": "qHkNOb03hMgEgoP3gyzFBDY3cg4F",
        "reference_id": "123456",
        "note": "Brief description",
        "customer_id": "VDKXEEKPJN48QDG3BGGFAK05P8"
      }
    }
    RESPONSE
  end

  def unsuccessful_authorize_response
    <<-RESPONSE
    {
      "payment": {
        "id": "iqrBxAil6rmDtr7cak9g9WO8uaB",
        "created_at": "2019-07-10T13:23:49.154Z",
        "updated_at": "2019-07-10T13:23:49.446Z",
        "amount_money": {
          "amount": 200,
          "currency": "USD"
        },
        "app_fee_money": {
          "amount": 10,
          "currency": "USD"
        },
        "total_money": {
          "amount": 200,
          "currency": "USD"
        },
        "status": "FAILED",
        "source_type": "CARD",
        "card_details": {
          "status": "CAPTURED",
          "card": {
            "card_brand": "VISA",
            "last_4": "2796",
            "exp_month": 7,
            "exp_year": 2026,
            "fingerprint": "sq-1-TpmjbNBMFdibiIjpQI5LiRgNUBC7u1689i0TgHjnlyHEWYB7tnn-K4QbW4ttvtaqXw"
          },
          "entry_method": "ON_FILE",
          "cvv_status": "CVV_ACCEPTED",
          "avs_status": "AVS_ACCEPTED",
          "auth_result_code": "nsAyY2"
        },
        "location_id": "XK3DBG77NJBFX",
        "order_id": "qHkNOb03hMgEgoP3gyzFBDY3cg4F",
        "reference_id": "123456",
        "note": "Brief description",
        "customer_id": "VDKXEEKPJN48QDG3BGGFAK05P8"
      }
    }
    RESPONSE
  end

  def successful_purchase_capture_reponse
    <<-RESPONSE
    {
      "payment": {
        "id": "EdMl5lwmBxd3ZvsvinkAT5LtvaB",
        "created_at": "2019-07-10T13:39:55.317Z",
        "updated_at": "2019-07-10T13:40:05.982Z",
        "amount_money": {
          "amount": 200,
          "currency": "USD"
        },
        "app_fee_money": {
          "amount": 10,
          "currency": "USD"
        },
        "total_money": {
          "amount": 200,
          "currency": "USD"
        },
        "status": "COMPLETED",
        "source_type": "CARD",
        "card_details": {
          "status": "CAPTURED",
          "card": {
            "card_brand": "VISA",
            "last_4": "2796",
            "exp_month": 7,
            "exp_year": 2026,
            "fingerprint": "sq-1-TpmjbNBMFdibiIjpQI5LiRgNUBC7u1689i0TgHjnlyHEWYB7tnn-K4QbW4ttvtaqXw"
          },
          "entry_method": "ON_FILE",
          "cvv_status": "CVV_ACCEPTED",
          "avs_status": "AVS_ACCEPTED",
          "auth_result_code": "MhIjEN"
        },
        "location_id": "XK3DBG77NJBFX",
        "order_id": "iJbzEHMhcwydeLbN3Apg5ZAjGi4F",
        "reference_id": "123456",
        "note": "Brief description",
        "customer_id": "VDKXEEKPJN48QDG3BGGFAK05P8"
      }
    }
    RESPONSE
  end

  def successful_purchase_void_response
    <<-RESPONSE
    {
      "payment": {
        "id": "EdMl5lwmBxd3ZvsvinkAT5LtvaB",
        "created_at": "2019-07-10T13:39:55.317Z",
        "updated_at": "2019-07-10T13:40:05.982Z",
        "amount_money": {
          "amount": 200,
          "currency": "USD"
        },
        "app_fee_money": {
          "amount": 10,
          "currency": "USD"
        },
        "total_money": {
          "amount": 200,
          "currency": "USD"
        },
        "status": "CANCELED",
        "source_type": "CARD",
        "card_details": {
          "status": "CAPTURED",
          "card": {
            "card_brand": "VISA",
            "last_4": "2796",
            "exp_month": 7,
            "exp_year": 2026,
            "fingerprint": "sq-1-TpmjbNBMFdibiIjpQI5LiRgNUBC7u1689i0TgHjnlyHEWYB7tnn-K4QbW4ttvtaqXw"
          },
          "entry_method": "ON_FILE",
          "cvv_status": "CVV_ACCEPTED",
          "avs_status": "AVS_ACCEPTED",
          "auth_result_code": "MhIjEN"
        },
        "location_id": "XK3DBG77NJBFX",
        "order_id": "iJbzEHMhcwydeLbN3Apg5ZAjGi4F",
        "reference_id": "123456",
        "note": "Brief description",
        "customer_id": "VDKXEEKPJN48QDG3BGGFAK05P8"
      }
    }
    RESPONSE
  end

  def successful_purchase_response
    <<-RESPONSE
    {
      "payment": {
        "id": "iqrBxAil6rmDtr7cak9g9WO8uaB",
        "created_at": "2019-07-10T13:23:49.154Z",
        "updated_at": "2019-07-10T13:23:49.446Z",
        "amount_money": {
          "amount": 200,
          "currency": "USD"
        },
        "app_fee_money": {
          "amount": 10,
          "currency": "USD"
        },
        "total_money": {
          "amount": 200,
          "currency": "USD"
        },
        "status": "COMPLETED",
        "source_type": "CARD",
        "card_details": {
          "status": "CAPTURED",
          "card": {
            "card_brand": "VISA",
            "last_4": "2796",
            "exp_month": 7,
            "exp_year": 2026,
            "fingerprint": "sq-1-TpmjbNBMFdibiIjpQI5LiRgNUBC7u1689i0TgHjnlyHEWYB7tnn-K4QbW4ttvtaqXw"
          },
          "entry_method": "ON_FILE",
          "cvv_status": "CVV_ACCEPTED",
          "avs_status": "AVS_ACCEPTED",
          "auth_result_code": "nsAyY2"
        },
        "location_id": "XK3DBG77NJBFX",
        "order_id": "qHkNOb03hMgEgoP3gyzFBDY3cg4F",
        "reference_id": "123456",
        "note": "Brief description",
        "customer_id": "VDKXEEKPJN48QDG3BGGFAK05P8"
      }
    }
    RESPONSE
  end

  def unsuccessful_purchase_response
    <<-RESPONSE
    {
      "payment": {
        "id": "iqrBxAil6rmDtr7cak9g9WO8uaB",
        "created_at": "2019-07-10T13:23:49.154Z",
        "updated_at": "2019-07-10T13:23:49.446Z",
        "amount_money": {
          "amount": 200,
          "currency": "USD"
        },
        "app_fee_money": {
          "amount": 10,
          "currency": "USD"
        },
        "total_money": {
          "amount": 200,
          "currency": "USD"
        },
        "status": "FAILED",
        "source_type": "CARD",
        "card_details": {
          "status": "CAPTURED",
          "card": {
            "card_brand": "VISA",
            "last_4": "2796",
            "exp_month": 7,
            "exp_year": 2026,
            "fingerprint": "sq-1-TpmjbNBMFdibiIjpQI5LiRgNUBC7u1689i0TgHjnlyHEWYB7tnn-K4QbW4ttvtaqXw"
          },
          "entry_method": "ON_FILE",
          "cvv_status": "CVV_ACCEPTED",
          "avs_status": "AVS_ACCEPTED",
          "auth_result_code": "nsAyY2"
        },
        "location_id": "XK3DBG77NJBFX",
        "order_id": "qHkNOb03hMgEgoP3gyzFBDY3cg4F",
        "reference_id": "123456",
        "note": "Brief description",
        "customer_id": "VDKXEEKPJN48QDG3BGGFAK05P8"
      }
    }
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    {
      "refund": {
        "id": "UNOE3kv2BZwqHlJ830RCt5YCuaB_xVteEWVFkXDvKN1ddidfJWipt8p9whmElKT5mZtJ7wZ",
        "reason": "Customer Canceled",
        "status": "PENDING",
        "amount_money": {
          "amount": 100,
          "currency": "USD"
        },
        "payment_id": "UNOE3kv2BZwqHlJ830RCt5YCuaB",
        "created_at": "2018-10-17T20:41:55.520Z",
        "updated_at": "2018-10-17T20:41:55.520Z"
      }
    }
    RESPONSE
  end

  def successful_new_customer_response
    <<-RESPONSE
    {
      "customer": {
        "id": "JDKYHBWT1D4F8MFH63DBMEN8Y4"
      }
    }
    RESPONSE
  end

  def successful_new_card_response
    <<-RESPONSE
    {
      "card": {
        "id": "icard-card_id",
         "card_brand": "VISA",
         "last_4": "1111",
         "exp_month": 11,
         "exp_year": 2018,
         "cardholder_name": "Amelia Earhart",
         "billing_address": {
           "address_line_1": "500 Electric Ave",
           "address_line_2": "Suite 600",
           "locality": "New York",
           "administrative_district_level_1": "NY",
           "postal_code": "10003",
           "country": "US"
         }
      }
    }
    RESPONSE
  end

  def successful_update_response
    <<-RESPONSE
    {
      "customer": {
        "id": "JDKYHBWT1D4F8MFH63DBMEN8Y4",
        "created_at": "2016-03-23T20:21:54.859Z",
        "updated_at": "2016-03-25T20:21:55Z",
        "given_name": "Tom",
        "family_name": "Smith",
        "email_address": "New.Amelia.Earhart@example.com",
        "address": {
          "address_line_1": "500 Electric Ave",
          "address_line_2": "Suite 600",
          "locality": "New York",
          "administrative_district_level_1": "NY",
          "postal_code": "10003",
          "country": "US"
        },
        "reference_id": "YOUR_REFERENCE_ID",
        "note": "updated customer note",
        "groups": [
          {
            "id": "16894e93-96eb-4ced-b24b-f71d42bf084c",
            "name": "Aviation Enthusiasts"
          }
        ]
      }
    }
    RESPONSE
  end
end
