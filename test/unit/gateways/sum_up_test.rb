require 'test_helper'

class SumUpTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = SumUpGateway.new(
      access_token: 'sup_sk_ABC123',
      pay_to_email: 'example@example.com'
    )
    @credit_card = credit_card
    @amount = 100

    @options = {
      payment_type: 'card',
      billing_address: address,
      description: 'Store Purchase',
      partner_id: 'PartnerId',
      order_id: SecureRandom.uuid
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_create_checkout_response)
    @gateway.expects(:ssl_request).returns(successful_complete_checkout_response)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response

    assert_equal 'PENDING', response.message
    refute_empty response.params
    assert response.test?
  end

  def test_successful_purchase_with_options
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      json_data = JSON.parse(data)
      if checkout_ref = json_data['checkout_reference']
        assert_match /#{@options[:partner_id]}-#{@options[:order_id]}/, checkout_ref
      end
    end.respond_with(successful_create_checkout_response)
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_complete_checkout_array_response)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response

    assert_equal SumUpGateway::STANDARD_ERROR_CODE_MAPPING[:multiple_invalid_parameters], response.error_code
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)
    response = @gateway.refund(nil, 'c0887be5-9fd2-4018-a531-e573e0298fdd22')
    assert_failure response
    assert_equal 'The transaction is not refundable in its current state', response.message
    assert_equal 'CONFLICT', response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_success_from
    response = @gateway.send(:parse, successful_complete_checkout_response)
    success_from = @gateway.send(:success_from, response.symbolize_keys)
    assert_equal true, success_from
  end

  def test_message_from
    response = @gateway.send(:parse, successful_complete_checkout_response)
    message_from = @gateway.send(:message_from, true, response.symbolize_keys)
    assert_equal 'PENDING', message_from
  end

  def test_authorization_from
    response = @gateway.send(:parse, successful_complete_checkout_response)
    authorization_from = @gateway.send(:authorization_from, response.symbolize_keys)
    assert_equal '8d8336a1-32e2-4f96-820a-5c9ee47e76fc', authorization_from
  end

  def test_format_errors
    responses = @gateway.send(:parse, failed_complete_checkout_array_response)
    error_code = @gateway.send(:format_errors, responses)
    assert_equal format_errors_response, error_code
  end

  def test_error_code_from
    response = @gateway.send(:parse, failed_complete_checkout_response)
    error_code_from = @gateway.send(:error_code_from, false, response.symbolize_keys)
    assert_equal 'CHECKOUT_SESSION_IS_EXPIRED', error_code_from
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
    opening connection to api.sumup.com:443...
    opened
    starting SSL for api.sumup.com:443...
    SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
    <- \"POST /v0.1/checkouts HTTP/1.1\\r\
    Content-Type: application/json\\r\
    Authorization: Bearer sup_sk_ABC123\\r\
    Connection: close\\r\
    Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\
    Accept: */*\\r\
    User-Agent: Ruby\\r\
    Host: api.sumup.com\\r\
    Content-Length: 422\\r\
    \\r\
    \"
    <- \"{\\\"pay_to_email\\\":\\\"example@example.com\\\",\\\"redirect_url\\\":null,\\\"return_url\\\":null,\\\"checkout_reference\\\":\\\"14c812fc-4689-4b8a-a4d7-ed21bf3c39ff\\\",\\\"amount\\\":\\\"1.00\\\",\\\"currency\\\":\\\"USD\\\",\\\"description\\\":\\\"Store Purchase\\\",\\\"personal_details\\\":{\\\"address\\\":{\\\"city\\\":\\\"Ottawa\\\",\\\"state\\\":\\\"ON\\\",\\\"country\\\":\\\"CA\\\",\\\"line_1\\\":\\\"456 My Street\\\",\\\"postal_code\\\":\\\"K1C2N6\\\"},\\\"email\\\":null,\\\"first_name\\\":\\\"Longbob\\\",\\\"last_name\\\":\\\"Longsen\\\",\\\"tax_id\\\":null},\\\"customer_id\\\":null}\"
    -> \"HTTP/1.1 201 Created\\r\
    \"
    -> \"Date: Thu, 14 Sep 2023 05:15:41 GMT\\r\
    \"
    -> \"Content-Type: application/json;charset=UTF-8\\r\
    \"
    -> \"Content-Length: 360\\r\
    \"
    -> \"Connection: close\\r\
    \"
    -> \"x-powered-by: Express\\r\
    \"
    -> \"access-control-allow-origin: *\\r\
    \"
    -> \"x-fong-id: 723b20084f2c, 723b20084f2c, 723b20084f2c 5df223126f1c\\r\
    \"
    -> \"cf-cache-status: DYNAMIC\\r\
    \"
    -> \"vary: Accept-Encoding\\r\
    \"
    -> \"apigw-requestid: LOyHiheuDoEEJSA=\\r\
    \"
    -> \"set-cookie: __cf_bm=1unGPonmyW_H8VRqo.O6h20hrSJ_0GtU3VqD9i3uYkI-1694668540-0-AaYQ1MVLyKxcwSNy8oNS5t/uVdk5ZU6aFPI/yvVcohm0Fm+Kltk55ngpG/Bms3cvRtxVX9DidO4ziiP2IsQcM41uJZq6TrcgLUD7KbJfJwV8; path=/; expires=Thu, 14-Sep-23 05:45:40 GMT; domain=.sumup.com; HttpOnly; Secure; SameSite=None\\r\
    \"
    -> \"x-op-gateway: true\\r\
    \"
    -> \"Set-Cookie: __cf_bm=OYzsPf_HGhiUfF0EETH_zOM74zPZpYhmqI.FJxehmpY-1694668541-0-AWVAexX304k53VB3HIhdyg+uP4ElzrS23jwIAdPGccfN5DM/81TE0ioW7jb7kA3jCZDuGENGofaZz0pBwSr66lRiWu9fdAzdUIbwNDOBivWY; path=/; expires=Thu, 14-Sep-23 05:45:41 GMT; domain=.sumup.com; HttpOnly; Secure; SameSite=None\\r\
    \"
    -> \"Server: cloudflare\\r\
    \"
    -> \"CF-RAY: 80662747af463995-BOG\\r\
    \"
    -> \"\\r\
    \"
    reading 360 bytes...
    -> \"{\\\"checkout_reference\\\":\\\"14c812fc-4689-4b8a-a4d7-ed21bf3c39ff\\\",\\\"amount\\\":1.0,\\\"currency\\\":\\\"USD\\\",\\\"pay_to_email\\\":\\\"example@example.com\\\",\\\"merchant_code\\\":\\\"MTVU2XGK\\\",\\\"description\\\":\\\"Store Purchase\\\",\\\"id\\\":\\\"70f71869-ed81-40b0-b2d8-c98f80f4c39d\\\",\\\"status\\\":\\\"PENDING\\\",\\\"date\\\":\\\"2023-09-14T05:15:40.000+00:00\\\",\\\"merchant_name\\\":\\\"Spreedly\\\",\\\"purpose\\\":\\\"CHECKOUT\\\",\\\"transactions\\\":[]}\"
    read 360 bytes
    Conn close
    opening connection to api.sumup.com:443...
    opened
    starting SSL for api.sumup.com:443...
    SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
    <- \"PUT /v0.1/checkouts/70f71869-ed81-40b0-b2d8-c98f80f4c39d HTTP/1.1\\r\
    Content-Type: application/json\\r\
    Authorization: Bearer sup_sk_ABC123\\r\
    Connection: close\\r\
    Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\
    Accept: */*\\r\
    User-Agent: Ruby\\r\
    Host: api.sumup.com\\r\
    Content-Length: 136\\r\
    \\r\
    \"
    <- \"{\\\"payment_type\\\":\\\"card\\\",\\\"card\\\":{\\\"name\\\":\\\"Longbob Longsen\\\",\\\"number\\\":\\\"4000100011112224\\\",\\\"expiry_month\\\":\\\"09\\\",\\\"expiry_year\\\":\\\"24\\\",\\\"cvv\\\":\\\"123\\\"}}\"
    -> \"HTTP/1.1 200 OK\\r\
    \"
    -> \"Date: Thu, 14 Sep 2023 05:15:41 GMT\\r\
    \"
    -> \"Content-Type: application/json\\r\
    \"
    -> \"Transfer-Encoding: chunked\\r\
    \"
    -> \"Connection: close\\r\
    \"
    -> \"x-powered-by: Express\\r\
    \"
    -> \"access-control-allow-origin: *\\r\
    \"
    -> \"x-fong-id: 8a116d29420e, 8a116d29420e, 8a116d29420e a534b6871710\\r\
    \"
    -> \"cf-cache-status: DYNAMIC\\r\
    \"
    -> \"vary: Origin, Access-Control-Request-Method, Access-Control-Request-Headers\\r\
    \"
    -> \"apigw-requestid: LOyHoggJjoEEMxA=\\r\
    \"
    -> \"set-cookie: __cf_bm=AoWMlPJNg1_THatbGnZchhj7K0QaqwlU0SqYrlDJ.78-1694668541-0-AdHrPpd/94p0oyLJWzsEUYatqVZMiJ0i1BJICEiprAo8AMDiya+V3OjljwbCpaNQNAPFVJpX1S4KxIFEUEeeNfAJv1HOjjaToNYhJuhLQ1NT; path=/; expires=Thu, 14-Sep-23 05:45:41 GMT; domain=.sumup.com; HttpOnly; Secure; SameSite=None\\r\
    \"
    -> \"x-op-gateway: true\\r\
    \"
    -> \"Set-Cookie: __cf_bm=UcJRX.Pe233lWIyCGlqNICBOhruxwESN41sDCDfzQBQ-1694668541-0-ASJ/Wl84HRovjKIq/p+Re8GrxkxHM1XvbDE/mXT/4r7PYA1cpTzG2uhp7WEkqVpEj7FCb2ahP5ExApEWWx0JDut8Uhx1SeQJHYFR/26E8BTv; path=/; expires=Thu, 14-Sep-23 05:45:41 GMT; domain=.sumup.com; HttpOnly; Secure; SameSite=None\\r\
    \"
    -> \"Server: cloudflare\\r\
    \"
    -> \"CF-RAY: 8066274e3a95399b-BOG\\r\
    \"
    -> \"Content-Encoding: gzip\\r\
    \"
    -> \"\\r\
    \"
    -> \"1bc\\r\
    \"
    reading 444 bytes...
    -> \"\\x1F\\x8B\\b\\x00\\x00\\x00\\x00\\x00\\x00\\x03|\\x92[\\x8B\\xDB0\\x10\\x85\\xFFJ\\x99\\xD7ZA\\x92\\x15G\\xD6S!1\\xDB\\xB2\\xCD\\x85\\x8D]RJ1\\xB2$wMm\\xD9Hr\\xC1,\\xFB\\xDF\\x8B\\xF6R\\x1A\\xBA\\xF4\\xF50G\\xF3\\xCD9z\\x00uo\\xD4\\xCFq\\x0E\\xB53\\xADq\\xC6*\\x03\\x02\\bS\\x9C\\xD0V!\\x96\\xF1\\x1C\\xB1\\x86K$\\x99\\xDE \\xA3)i\\xDAT\\xA5y\\xDBB\\x02r\\x18g\\e@\\x90\\x15N@\\xCD.\\xDA\\x17\\x10P\\x9Dw\\x90\\xC0$\\x97:\\x8C\\xB5\\x19d\\xD7\\x83\\x80\\xCE\\x06\\xF3\\xC3\\xC9\\xD0\\x8D\\xD6\\x7F\\xF0\\x933F\\xF7\\xCBJ\\x8D\\x03$0\\x18\\xA7\\xEE\\xA5\\r\\xB5\\x1Au\\xDC\\xBF/\\xBFT\\xF4rs\\v\\th\\xE3\\x95\\xEB\\xA6h\\x03\\x01\\xE70:\\xF3\\xEE4\\xC7qo \\x81N\\x83\\x80\\rn7\\x84g92\\x9A\\x13\\xC4p\\x83QC5G*\\xE7-\\xC7-Si\\xAE!\\x01\\x1Fd\\x98=\\b8\\x15\\x87\\xDD\\xA7\\xC3M|]\\x86\\xB8\\x8Fb\\x9A\\\"\\x9C#\\xC2J\\xBC\\x16d-\\x18^a\\x8C\\xDFc,0\\xFE\\x9B\\xCF\\xCA!\\xCE\\x9F_\\xF0\\xE3\\x95\\xB3\\x9BF\\x1F\\xC5\\xED\\xC7b{{\\xACJH 8i\\xBDTO\\xB7\\x82\\xF8\\xF6\\xF0\\x8C\\x893\\xCD\\x15[S\\xD4\\xB2\\xD4 \\x96R\\x8E8\\xC7\"
    -> \")\\xE2\\xBAU\\x9A\\xF0\\x94\\xD0&\\xBD6\\xBF\\xE6Q\\xEE(\\xADN\\x97\\xCF\\x97\\xF2\\xFFa]\\x15\\xF2K\\x86\\xFAU\\xC0Q\\b\\xDDt-\\xFCSY\\xE8\\x06\\xE3\\x83\\x1C\\xA673!+\\xC6\\xF3?\\x99\\xBC\\x91\\xE6$\\x97\\xC1\\xD8P\\x87e\\x8A`\\xC5\\xF6\\xB8\\x87\\x04\\x8C\\rn\\xA9\\x87g\\xD8mu.\\x8F\\xFB\\xE2\\xAE.\\x0E\\xE5\\xDD\\xD7X\\xA0\\xF5A\\xF6}\\xF4\\xF9Z\\xBD\\xE0'O\\xBF\\xC5Y\\xD9\\xD71\\xB95\\xC9\\xE8\\x06\\xA7,\\xA3\\x8F\\xDF\\x1F\\x7F\\x03\\x00\\x00\\xFF\\xFF\\x03\\x00\\xB5\\x12\\xCA\\x11\\xB3\\x02\\x00\\x00\"
    read 444 bytes
    reading 2 bytes...
    -> \"\\r\
    \"
    read 2 bytes
    -> \"0\\r\
    \"
    -> \"\\r\
    \"
    Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
    opening connection to api.sumup.com:443...
    opened
    starting SSL for api.sumup.com:443...
    SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
    <- \"POST /v0.1/checkouts HTTP/1.1\\r\
    Content-Type: application/json\\r\
    Authorization: Bearer [FILTERED]\\r\
    Connection: close\\r\
    Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\
    Accept: */*\\r\
    User-Agent: Ruby\\r\
    Host: api.sumup.com\\r\
    Content-Length: 422\\r\
    \\r\
    \"
    <- \"{\\\"pay_to_email\\\":\\\"[FILTERED]\",\\\"redirect_url\\\":null,\\\"return_url\\\":null,\\\"checkout_reference\\\":\\\"14c812fc-4689-4b8a-a4d7-ed21bf3c39ff\\\",\\\"amount\\\":\\\"1.00\\\",\\\"currency\\\":\\\"USD\\\",\\\"description\\\":\\\"Store Purchase\\\",\\\"personal_details\\\":{\\\"address\\\":{\\\"city\\\":\\\"Ottawa\\\",\\\"state\\\":\\\"ON\\\",\\\"country\\\":\\\"CA\\\",\\\"line_1\\\":\\\"456 My Street\\\",\\\"postal_code\\\":\\\"K1C2N6\\\"},\\\"email\\\":null,\\\"first_name\\\":\\\"Longbob\\\",\\\"last_name\\\":\\\"Longsen\\\",\\\"tax_id\\\":null},\\\"customer_id\\\":null}\"
    -> \"HTTP/1.1 201 Created\\r\
    \"
    -> \"Date: Thu, 14 Sep 2023 05:15:41 GMT\\r\
    \"
    -> \"Content-Type: application/json;charset=UTF-8\\r\
    \"
    -> \"Content-Length: 360\\r\
    \"
    -> \"Connection: close\\r\
    \"
    -> \"x-powered-by: Express\\r\
    \"
    -> \"access-control-allow-origin: *\\r\
    \"
    -> \"x-fong-id: 723b20084f2c, 723b20084f2c, 723b20084f2c 5df223126f1c\\r\
    \"
    -> \"cf-cache-status: DYNAMIC\\r\
    \"
    -> \"vary: Accept-Encoding\\r\
    \"
    -> \"apigw-requestid: LOyHiheuDoEEJSA=\\r\
    \"
    -> \"set-cookie: __cf_bm=1unGPonmyW_H8VRqo.O6h20hrSJ_0GtU3VqD9i3uYkI-1694668540-0-AaYQ1MVLyKxcwSNy8oNS5t/uVdk5ZU6aFPI/yvVcohm0Fm+Kltk55ngpG/Bms3cvRtxVX9DidO4ziiP2IsQcM41uJZq6TrcgLUD7KbJfJwV8; path=/; expires=Thu, 14-Sep-23 05:45:40 GMT; domain=.sumup.com; HttpOnly; Secure; SameSite=None\\r\
    \"
    -> \"x-op-gateway: true\\r\
    \"
    -> \"Set-Cookie: __cf_bm=OYzsPf_HGhiUfF0EETH_zOM74zPZpYhmqI.FJxehmpY-1694668541-0-AWVAexX304k53VB3HIhdyg+uP4ElzrS23jwIAdPGccfN5DM/81TE0ioW7jb7kA3jCZDuGENGofaZz0pBwSr66lRiWu9fdAzdUIbwNDOBivWY; path=/; expires=Thu, 14-Sep-23 05:45:41 GMT; domain=.sumup.com; HttpOnly; Secure; SameSite=None\\r\
    \"
    -> \"Server: cloudflare\\r\
    \"
    -> \"CF-RAY: 80662747af463995-BOG\\r\
    \"
    -> \"\\r\
    \"
    reading 360 bytes...
    -> \"{\\\"checkout_reference\\\":\\\"14c812fc-4689-4b8a-a4d7-ed21bf3c39ff\\\",\\\"amount\\\":1.0,\\\"currency\\\":\\\"USD\\\",\\\"pay_to_email\\\":\\\"[FILTERED]\",\\\"merchant_code\\\":\\\"MTVU2XGK\\\",\\\"description\\\":\\\"Store Purchase\\\",\\\"id\\\":\\\"70f71869-ed81-40b0-b2d8-c98f80f4c39d\\\",\\\"status\\\":\\\"PENDING\\\",\\\"date\\\":\\\"2023-09-14T05:15:40.000+00:00\\\",\\\"merchant_name\\\":\\\"Spreedly\\\",\\\"purpose\\\":\\\"CHECKOUT\\\",\\\"transactions\\\":[]}\"
    read 360 bytes
    Conn close
    opening connection to api.sumup.com:443...
    opened
    starting SSL for api.sumup.com:443...
    SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
    <- \"PUT /v0.1/checkouts/70f71869-ed81-40b0-b2d8-c98f80f4c39d HTTP/1.1\\r\
    Content-Type: application/json\\r\
    Authorization: Bearer [FILTERED]\\r\
    Connection: close\\r\
    Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\
    Accept: */*\\r\
    User-Agent: Ruby\\r\
    Host: api.sumup.com\\r\
    Content-Length: 136\\r\
    \\r\
    \"
    <- \"{\\\"payment_type\\\":\\\"card\\\",\\\"card\\\":{\\\"name\\\":\\\"Longbob Longsen\\\",\\\"number\\\":\\\"[FILTERED]\",\\\"expiry_month\\\":\\\"09\\\",\\\"expiry_year\\\":\\\"24\\\",\\\"cvv\\\":\\\"[FILTERED]\"}}\"
    -> \"HTTP/1.1 200 OK\\r\
    \"
    -> \"Date: Thu, 14 Sep 2023 05:15:41 GMT\\r\
    \"
    -> \"Content-Type: application/json\\r\
    \"
    -> \"Transfer-Encoding: chunked\\r\
    \"
    -> \"Connection: close\\r\
    \"
    -> \"x-powered-by: Express\\r\
    \"
    -> \"access-control-allow-origin: *\\r\
    \"
    -> \"x-fong-id: 8a116d29420e, 8a116d29420e, 8a116d29420e a534b6871710\\r\
    \"
    -> \"cf-cache-status: DYNAMIC\\r\
    \"
    -> \"vary: Origin, Access-Control-Request-Method, Access-Control-Request-Headers\\r\
    \"
    -> \"apigw-requestid: LOyHoggJjoEEMxA=\\r\
    \"
    -> \"set-cookie: __cf_bm=AoWMlPJNg1_THatbGnZchhj7K0QaqwlU0SqYrlDJ.78-1694668541-0-AdHrPpd/94p0oyLJWzsEUYatqVZMiJ0i1BJICEiprAo8AMDiya+V3OjljwbCpaNQNAPFVJpX1S4KxIFEUEeeNfAJv1HOjjaToNYhJuhLQ1NT; path=/; expires=Thu, 14-Sep-23 05:45:41 GMT; domain=.sumup.com; HttpOnly; Secure; SameSite=None\\r\
    \"
    -> \"x-op-gateway: true\\r\
    \"
    -> \"Set-Cookie: __cf_bm=UcJRX.Pe233lWIyCGlqNICBOhruxwESN41sDCDfzQBQ-1694668541-0-ASJ/Wl84HRovjKIq/p+Re8GrxkxHM1XvbDE/mXT/4r7PYA1cpTzG2uhp7WEkqVpEj7FCb2ahP5ExApEWWx0JDut8Uhx1SeQJHYFR/26E8BTv; path=/; expires=Thu, 14-Sep-23 05:45:41 GMT; domain=.sumup.com; HttpOnly; Secure; SameSite=None\\r\
    \"
    -> \"Server: cloudflare\\r\
    \"
    -> \"CF-RAY: 8066274e3a95399b-BOG\\r\
    \"
    -> \"Content-Encoding: gzip\\r\
    \"
    -> \"\\r\
    \"
    -> \"1bc\\r\
    \"
    reading 444 bytes...
    -> \"\\x1F\\x8B\\b\\x00\\x00\\x00\\x00\\x00\\x00\\x03|\\x92[\\x8B\\xDB0\\x10\\x85\\xFFJ\\x99\\xD7ZA\\x92\\x15G\\xD6S!1\\xDB\\xB2\\xCD\\x85\\x8D]RJ1\\xB2$wMm\\xD9Hr\\xC1,\\xFB\\xDF\\x8B\\xF6R\\x1A\\xBA\\xF4\\xF50G\\xF3\\xCD9z\\x00uo\\xD4\\xCFq\\x0E\\xB53\\xADq\\xC6*\\x03\\x02\\bS\\x9C\\xD0V!\\x96\\xF1\\x1C\\xB1\\x86K$\\x99\\xDE \\xA3)i\\xDAT\\xA5y\\xDBB\\x02r\\x18g\\e@\\x90\\x15N@\\xCD.\\xDA\\x17\\x10P\\x9Dw\\x90\\xC0$\\x97:\\x8C\\xB5\\x19d\\xD7\\x83\\x80\\xCE\\x06\\xF3\\xC3\\xC9\\xD0\\x8D\\xD6\\x7F\\xF0\\x933F\\xF7\\xCBJ\\x8D\\x03$0\\x18\\xA7\\xEE\\xA5\\r\\xB5\\x1Au\\xDC\\xBF/\\xBFT\\xF4rs\\v\\th\\xE3\\x95\\xEB\\xA6h\\x03\\x01\\xE70:\\xF3\\xEE4\\xC7qo \\x81N\\x83\\x80\\rn7\\x84g92\\x9A\\x13\\xC4p\\x83QC5G*\\xE7-\\xC7-Si\\xAE!\\x01\\x1Fd\\x98=\\b8\\x15\\x87\\xDD\\xA7\\xC3M|]\\x86\\xB8\\x8Fb\\x9A\\\"\\x9C#\\xC2J\\xBC\\x16d-\\x18^a\\x8C\\xDFc,0\\xFE\\x9B\\xCF\\xCA!\\xCE\\x9F_\\xF0\\xE3\\x95\\xB3\\x9BF\\x1F\\xC5\\xED\\xC7b{{\\xACJH 8i\\xBDTO\\xB7\\x82\\xF8\\xF6\\xF0\\x8C\\x893\\xCD\\x15[S\\xD4\\xB2\\xD4 \\x96R\\x8E8\\xC7\"
    -> \")\\xE2\\xBAU\\x9A\\xF0\\x94\\xD0&\\xBD6\\xBF\\xE6Q\\xEE(\\xADN\\x97\\xCF\\x97\\xF2\\xFFa]\\x15\\xF2K\\x86\\xFAU\\xC0Q\\b\\xDDt-\\xFCSY\\xE8\\x06\\xE3\\x83\\x1C\\xA673!+\\xC6\\xF3?\\x99\\xBC\\x91\\xE6$\\x97\\xC1\\xD8P\\x87e\\x8A`\\xC5\\xF6\\xB8\\x87\\x04\\x8C\\rn\\xA9\\x87g\\xD8mu.\\x8F\\xFB\\xE2\\xAE.\\x0E\\xE5\\xDD\\xD7X\\xA0\\xF5A\\xF6}\\xF4\\xF9Z\\xBD\\xE0'O\\xBF\\xC5Y\\xD9\\xD71\\xB95\\xC9\\xE8\\x06\\xA7,\\xA3\\x8F\\xDF\\x1F\\x7F\\x03\\x00\\x00\\xFF\\xFF\\x03\\x00\\xB5\\x12\\xCA\\x11\\xB3\\x02\\x00\\x00\"
    read 444 bytes
    reading 2 bytes...
    -> \"\\r\
    \"
    read 2 bytes
    -> \"0\\r\
    \"
    -> \"\\r\
    \"
    Conn close
    POST_SCRUBBED
  end

  def successful_create_checkout_response
    <<-RESPONSE
    {
      "checkout_reference": "e86ba553-b3d0-49f6-b4b5-18bd67502db2",
      "amount": 1.0,
      "currency": "USD",
      "pay_to_email": "example@example.com",
      "merchant_code": "ABC123",
      "description": "Store Purchase",
      "id": "8d8336a1-32e2-4f96-820a-5c9ee47e76fc",
      "status": "PENDING",
      "date": "2023-09-14T00:26:37.000+00:00",
      "merchant_name": "Spreedly",
      "purpose": "CHECKOUT",
      "transactions": []
    }
    RESPONSE
  end

  def successful_complete_checkout_response
    <<-RESPONSE
    {
      "checkout_reference": "e86ba553-b3d0-49f6-b4b5-18bd67502db2",
      "amount": 1.0,
      "currency": "USD",
      "pay_to_email": "example@example.com",
      "merchant_code": "ABC123",
      "description": "Store Purchase",
      "id": "8d8336a1-32e2-4f96-820a-5c9ee47e76fc",
      "status": "PENDING",
      "date": "2023-09-14T00: 26: 37.000+00: 00",
      "merchant_name": "Spreedly",
      "purpose": "CHECKOUT",
      "transactions": [{
        "id": "1bce6072-1865-4a90-887f-cb7fda97b300",
        "transaction_code": "TDMNUPS33H",
        "merchant_code": "MTVU2XGK",
        "amount": 1.0,
        "vat_amount": 0.0,
        "tip_amount": 0.0,
        "currency": "USD",
        "timestamp": "2023-09-14T00:26:38.420+00:00",
        "status": "PENDING",
        "payment_type": "ECOM",
        "entry_mode": "CUSTOMER_ENTRY",
        "installments_count": 1,
        "internal_id": 5162527027
      }]
    }
    RESPONSE
  end

  def failed_complete_checkout_response
    <<-RESPONSE
    {
      "type": "https://developer.sumup.com/docs/problem/session-expired/",
      "title": "Conflict",
      "status": 409,
      "detail": "The checkout session 79c866c2-0b2d-470d-925a-37ddc8855ec2 is expired",
      "instance": "79a4ed94d177, 79a4ed94d177 c24ac3136c71",
      "error_code": "CHECKOUT_SESSION_IS_EXPIRED",
      "message": "Checkout is expired"
    }
    RESPONSE
  end

  def failed_complete_checkout_array_response
    <<-RESPONSE
    [
      {
        "message": "Validation error",
        "param": "card",
        "error_code": "The card is expired"
      },
      {
        "message": "Validation error",
        "param": "card",
        "error_code": "The value located under the \'$.card.number\' path is not a valid card number"
      }
    ]
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
    {
      "message": "The transaction is not refundable in its current state",
      "error_code": "CONFLICT"
    }
    RESPONSE
  end

  def format_errors_response
    {
      error_code: 'MULTIPLE_INVALID_PARAMETERS',
      message: 'Validation error',
      errors: [{ error_code: 'The card is expired', param: 'card' }, { error_code: "The value located under the '$.card.number' path is not a valid card number", param: 'card' }]
    }
  end
end
