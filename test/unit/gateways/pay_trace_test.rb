require 'test_helper'

class PayTraceTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PayTraceGateway.new(username: 'username', password: 'password')
    @visa_credit_card = credit_card('4012000098765439', verification_value: 999)
    @amount = 100
    @declined_amount = 112.00

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
    @level_data_options = {
      invoice_id: "inv1234",
      customer_reference_id: "PO123456",
      tax_amount: 8.10,
      national_tax_amount: 0.00,
      freight_amount: 0.00,
      duty_amount: 0.00,
      source_address: {
          zip: "99201"
      },
      shipping_address: {
           zip: "85284",
           country: "US"
      },
      additional_tax_amount: 0.00,
      additional_tax_included: true,
      line_items: [{
          additional_tax_amount: 0.40,
          additional_tax_included: true,
          additional_tax_rate: 0.08,
          amount: 1.00,
          debit_or_credit: "C",
          description: "business services",
          discount_amount: 3.27,
          discount_rate: 0.01,
          discount_included: true,
          merchant_tax_id: "12-123456",
          product_id: "sku1245",
          quantity: 1,
          tax_included: true,
          unit_of_measure: "EACH",
          unit_cost: 5.24
      }]
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, successful_purchase_response)
    response = @gateway.purchase(@amount, @visa_credit_card, @options)

    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, failed_purchase_response)
    response = @gateway.purchase(@declined_amount, @visa_credit_card, @options)

    assert_failure response
    assert_equal 'Your transaction was not approved.', response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, successful_authorize_response)
    response = @gateway.authorize(@amount, @visa_credit_card, @options)

    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, failed_authorize_response)
    response = @gateway.authorize(@declined_amount, @visa_credit_card, @options)

    assert_failure response
    assert_equal 'Your transaction was not approved.', response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, successful_capture_response)
    response = @gateway.capture(@amount, 123456789, @options)

    assert_success response
    assert_equal 'Your transaction was successfully captured.', response.message
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, failed_capture_response)
    response = @gateway.capture(@declined_amount, '', @options)

    assert_failure response
    assert_equal '811', response.error_code
    assert response.test?
  end
  def test_failed_transaction_capture
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, failed_transaction_capture_response)
    response = @gateway.capture(@declined_amount, 123456789, @options)

    assert_failure response
    assert_equal '816', response.error_code
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, successful_refund_response)
    response = @gateway.refund(@amount, @visa_credit_card, @options)

    assert_success response
    assert_equal 'Your transaction was successfully refunded.', response.message
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, failed_refund_response)
    response = @gateway.refund(@declined_amount, @visa_credit_card, @options)

    assert_failure response
    assert_equal '811', response.error_code
    assert response.test?
  end

  def test_failed_transaction_refund
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, failed_transaction_refund_response)
    response = @gateway.refund(@declined_amount, 123456789, @options)

    assert_failure response
    assert_equal '817', response.error_code
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, successful_void_response)
    response = @gateway.void(123456789)

    assert_success response
    assert_equal 'Your transaction was successfully voided.', response.message
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, failed_void_response)
    response = @gateway.void('')

    assert_failure response
    assert_equal '811', response.error_code
    assert response.test?
  end

  def test_failed_transaction_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, failed_transaction_void_response)
    response = @gateway.void(123456789)

    assert_failure response
    assert_equal '818', response.error_code
    assert response.test?
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@visa_credit_card)
    end.respond_with(successful_authentication_token_response, successful_authorize_response,
            successful_authentication_token_response, successful_void_response)
    assert_success response
    assert_equal 178963007, response.authorization
    assert_equal 'Your transaction was successfully approved.', response.message
    assert response.test?
  end

  def test_successful_verify_with_failed_void
    response = stub_comms do
      @gateway.verify(@visa_credit_card)
    end.respond_with(successful_authentication_token_response, successful_authorize_response,
            successful_authentication_token_response, failed_void_response)
    assert_success response
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@visa_credit_card)
    end.respond_with(successful_authentication_token_response, failed_authorize_response,
            successful_authentication_token_response, failed_void_response)
    assert_failure response
  end

  def test_successful_add_level_3_data
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, successful_level_3_data_response)
    response = @gateway.add_level_3_data(123456789, @level_data_options)

    assert_success response
    assert_equal 'Visa/MasterCard enhanced data was successfully added to Transaction ID 179509448. 1 line item records were created.', response.message
  end

  def test_failed_add_level_3_data
    @gateway.expects(:ssl_post).times(2).returns(successful_authentication_token_response, failed_level_3_data_response)
    response = @gateway.add_level_3_data('', @level_data_options)

    assert_failure response
    assert_equal 'One or more errors has occurred.', response.message
    assert_equal '58', response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-'PRE_SCRUBBED'
    opening connection to api.paytrace.com:443...
    opened
    starting SSL for api.paytrace.com:443...
    SSL established
    <- "POST /oauth/token HTTP/1.1\r\nContent-Type: application/json\r\nAccept: */*\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.paytrace.com\r\nContent-Length: 84\r\n\r\n"
    <- "{\"grant_type\":\"password\",\"username\":\"ActiveMerchant\",\"password\":\"ActiveMerchant123\"}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Content-Type: application/json; charset=utf-8\r\n"
    -> "Connection: close\r\n"
    -> "Status: 200 OK\r\n"
    -> "Cache-Control: no-store\r\n"
    -> "Pragma: no-cache\r\n"
    -> "X-XSS-Protection: 1; mode=block\r\n"
    -> "X-Request-Id: 8c6003fc-0f97-48ea-a762-ec0b34b58581\r\n"
    -> "ETag: W/\"f9ddae0c97032e6427552a99bb6da84f\"\r\n"
    -> "X-Frame-Options: SAMEORIGIN\r\n"
    -> "X-Runtime: 0.145620\r\n"
    -> "X-Content-Type-Options: nosniff\r\n"
    -> "Date: Thu, 12 Oct 2017 20:58:59 GMT\r\n"
    -> "Strict-Transport-Security: max-age=300\r\n"
    -> "Set-Cookie: TS0179310f=01bb9fcf1e2f59cb8c17b0101fe6c593d5eed92406f30bd1dee8736476fda16f7ddc8d99d2a9061e5f149da86d479f2b9cbf8453dd; Path=/; Secure; HTTPOnly\r\n"
    -> "Vary: Accept-Encoding\r\n"
    -> "Content-Encoding: gzip\r\n"
    -> "Transfer-Encoding: chunked\r\n"
    -> "\r\n"
    -> "a3\r\n"
    reading 163 bytes...
    -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x04\x03}\xCE1\n\xC30\f@\xD1\xBBx\xCE`Y\xB2$\xFB2\xC1V\x14\b\x8568\x19ZJ\xEF\xDE\xD0\x03t\xFD\x7Fy\xEF\xD0\xCC\xFC8\xE6\xF3q\xF3{\xA8\x01\b\x99\xA40K\xE6\x852'AV\x06\xF6\xAB\xD6\x7F\x130!b5\x8B\x90\x00!\x82\xE9\x9ARo9\x9A\xB1\xAEdX\x04\xA8P\xA4\x15\xBAfd\x14M\xA9e\xD4n\xAA\xA4\x82\xABH\x970\x85\x1Fe>_\xBB_\x9E\xEEm\xF8\xB8\xAA?\xF7m\xF81o\x97RR\x8CS\xB0\xE1\xED\xF4eng\xA8\x90\xA3(A\xC1\xF2\xF9\x02\xD6\xEB  \xD3\x00\x00\x00"
    read 163 bytes
    reading 2 bytes...
    -> "\r\n"
    read 2 bytes
    -> "0\r\n"
    -> "\r\n"
    Conn close
    opening connection to api.paytrace.com:443...
    opened
    starting SSL for api.paytrace.com:443...
    SSL established
    <- "POST /v1/transactions/sale/keyed HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer 143647966756d45627368616e647:143647966756d45627368616e647132333:cc01213101c8f22ba50cc68f4c397149404f1b853637822a538bc884873f77b7\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.paytrace.com\r\nContent-Length: 121\r\n\r\n"
    <- "{\"amount\":\"1.00\",\"credit_card\":{\"number\":\"4012000098765439\",\"expiration_year\":\"2018\",\"expiration_month\":\"9\"},\"csc\":\"999\"}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Content-Type: application/json; charset=utf-8\r\n"
    -> "Connection: close\r\n"
    -> "Status: 200 OK\r\n"
    -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
    -> "X-XSS-Protection: 1; mode=block\r\n"
    -> "X-Request-Id: fc48d7f3-93d7-40ad-af4d-9731dc4cc002\r\n"
    -> "ETag: W/\"33c660c5696066bd01b972600635493a\"\r\n"
    -> "X-Frame-Options: SAMEORIGIN\r\n"
    -> "X-Runtime: 2.015837\r\n"
    -> "X-Content-Type-Options: nosniff\r\n"
    -> "Date: Thu, 12 Oct 2017 20:59:02 GMT\r\n"
    -> "Strict-Transport-Security: max-age=300\r\n"
    -> "Set-Cookie: TS0179310f=01bb9fcf1e2c7bd5183111755f4e172d28623dcb0ff8545ef2039512a09e75dae382bdc82731ef4c1889258e325b4dffc997ec8586; Path=/; Secure; HTTPOnly\r\n"
    -> "Vary: Accept-Encoding\r\n"
    -> "Content-Encoding: gzip\r\n"
    -> "Transfer-Encoding: chunked\r\n"
    -> "\r\n"
    -> "dc\r\n"
    reading 220 bytes...
    -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x04\x03]O\xCDN\xC30\f~\x15\xCB\xE7\x82\x9Amh\xB4\xB7\xDE\x87\x98\x06B\xE2\x14\x99\xC4\x83\x896\xA9\xE2d\f!\xDE\x1D\xA3\x15\xA8\xF0\xF1\xFB\xF7\aJq\x8EE\xB0\xCD\xA9p\x85\x89e\x8CA\xD8\xBA\xE8\x19[S\x9B\n%S.b\a\x95\xD1\xB3\x82\xF8\x18K\x82\x9C(\b\xB9|\x88\x01\xDEH`\n\xDA\x97\xBE\x7F\a\x1A\xC7\x14\x8F\xEC/\xB1\xC2\x99\xD0\x1E\xBCf\xAE\ec\x96\xEB\xC5u\x85g\x19\xF5S\e\xDEwwuc\xD4\xF3K\xFC\x95v\xDB\xED\xEE\xF6\xA1\xDB\xC0Y\x04p\x01\xDD\xD4\x02\x14<\xB88\x8C=g\xF6\xDF\xF6\xA3\xD8\x9FO\xB0\xC5Z!'n\x0E\xDDPv/\n\xF3)s\n\xBA\xE0\xFFJTr yeo\x1D%oC\x19\x9E8i\xD8ivW\xABe\x83\x9F_0\x02`\x1DE\x01\x00\x00"
    read 220 bytes
    reading 2 bytes...
    -> "\r\n"
    read 2 bytes
    -> "0\r\n"
    -> "\r\n"
    Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-'POST_SCRUBBED'
    opening connection to api.paytrace.com:443...
    opened
    starting SSL for api.paytrace.com:443...
    SSL established
    <- "POST /oauth/token HTTP/1.1\r\nContent-Type: application/json\r\nAccept: */*\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.paytrace.com\r\nContent-Length: 84\r\n\r\n"
    <- "{\"grant_type\":\"password\",\"username\":\"[FILTERED]\",\"password\":\"[FILTERED]\"}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Content-Type: application/json; charset=utf-8\r\n"
    -> "Connection: close\r\n"
    -> "Status: 200 OK\r\n"
    -> "Cache-Control: no-store\r\n"
    -> "Pragma: no-cache\r\n"
    -> "X-XSS-Protection: 1; mode=block\r\n"
    -> "X-Request-Id: 8c6003fc-0f97-48ea-a762-ec0b34b58581\r\n"
    -> "ETag: W/\"f9ddae0c97032e6427552a99bb6da84f\"\r\n"
    -> "X-Frame-Options: SAMEORIGIN\r\n"
    -> "X-Runtime: 0.145620\r\n"
    -> "X-Content-Type-Options: nosniff\r\n"
    -> "Date: Thu, 12 Oct 2017 20:58:59 GMT\r\n"
    -> "Strict-Transport-Security: max-age=300\r\n"
    -> "Set-Cookie: TS0179310f=01bb9fcf1e2f59cb8c17b0101fe6c593d5eed92406f30bd1dee8736476fda16f7ddc8d99d2a9061e5f149da86d479f2b9cbf8453dd; Path=/; Secure; HTTPOnly\r\n"
    -> "Vary: Accept-Encoding\r\n"
    -> "Content-Encoding: gzip\r\n"
    -> "Transfer-Encoding: chunked\r\n"
    -> "\r\n"
    -> "a3\r\n"
    reading 163 bytes...
    -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x04\x03}\xCE1\n\xC30\f@\xD1\xBBx\xCE`Y\xB2$\xFB2\xC1V\x14\b\x8568\x19ZJ\xEF\xDE\xD0\x03t\xFD\x7Fy\xEF\xD0\xCC\xFC8\xE6\xF3q\xF3{\xA8\x01\b\x99\xA40K\xE6\x852'AV\x06\xF6\xAB\xD6\x7F\x130!b5\x8B\x90\x00!\x82\xE9\x9ARo9\x9A\xB1\xAEdX\x04\xA8P\xA4\x15\xBAfd\x14M\xA9e\xD4n\xAA\xA4\x82\xABH\x970\x85\x1Fe>_\xBB_\x9E\xEEm\xF8\xB8\xAA?\xF7m\xF81o\x97RR\x8CS\xB0\xE1\xED\xF4eng\xA8\x90\xA3(A\xC1\xF2\xF9\x02\xD6\xEB  \xD3\x00\x00\x00"
    read 163 bytes
    reading 2 bytes...
    -> "\r\n"
    read 2 bytes
    -> "0\r\n"
    -> "\r\n"
    Conn close
    opening connection to api.paytrace.com:443...
    opened
    starting SSL for api.paytrace.com:443...
    SSL established
    <- "POST /v1/transactions/sale/keyed HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.paytrace.com\r\nContent-Length: 121\r\n\r\n"
    <- "{\"amount\":\"1.00\",\"credit_card\":{\"number\":\"[FILTERED]\",\"expiration_year\":\"2018\",\"expiration_month\":\"9\"},\"csc\":\"[FILTERED]\"}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Content-Type: application/json; charset=utf-8\r\n"
    -> "Connection: close\r\n"
    -> "Status: 200 OK\r\n"
    -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
    -> "X-XSS-Protection: 1; mode=block\r\n"
    -> "X-Request-Id: fc48d7f3-93d7-40ad-af4d-9731dc4cc002\r\n"
    -> "ETag: W/\"33c660c5696066bd01b972600635493a\"\r\n"
    -> "X-Frame-Options: SAMEORIGIN\r\n"
    -> "X-Runtime: 2.015837\r\n"
    -> "X-Content-Type-Options: nosniff\r\n"
    -> "Date: Thu, 12 Oct 2017 20:59:02 GMT\r\n"
    -> "Strict-Transport-Security: max-age=300\r\n"
    -> "Set-Cookie: TS0179310f=01bb9fcf1e2c7bd5183111755f4e172d28623dcb0ff8545ef2039512a09e75dae382bdc82731ef4c1889258e325b4dffc997ec8586; Path=/; Secure; HTTPOnly\r\n"
    -> "Vary: Accept-Encoding\r\n"
    -> "Content-Encoding: gzip\r\n"
    -> "Transfer-Encoding: chunked\r\n"
    -> "\r\n"
    -> "dc\r\n"
    reading 220 bytes...
    -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x04\x03]O\xCDN\xC30\f~\x15\xCB\xE7\x82\x9Amh\xB4\xB7\xDE\x87\x98\x06B\xE2\x14\x99\xC4\x83\x896\xA9\xE2d\f!\xDE\x1D\xA3\x15\xA8\xF0\xF1\xFB\xF7\aJq\x8EE\xB0\xCD\xA9p\x85\x89e\x8CA\xD8\xBA\xE8\x19[S\x9B\n%S.b\a\x95\xD1\xB3\x82\xF8\x18K\x82\x9C(\b\xB9|\x88\x01\xDEH`\n\xDA\x97\xBE\x7F\a\x1A\xC7\x14\x8F\xEC/\xB1\xC2\x99\xD0\x1E\xBCf\xAE\ec\x96\xEB\xC5u\x85g\x19\xF5S\e\xDEwwuc\xD4\xF3K\xFC\x95v\xDB\xED\xEE\xF6\xA1\xDB\xC0Y\x04p\x01\xDD\xD4\x02\x14<\xB88\x8C=g\xF6\xDF\xF6\xA3\xD8\x9FO\xB0\xC5Z!'n\x0E\xDDPv/\n\xF3)s\n\xBA\xE0\xFFJTr yeo\x1D%oC\x19\x9E8i\xD8ivW\xABe\x83\x9F_0\x02`\x1DE\x01\x00\x00"
    read 220 bytes
    reading 2 bytes...
    -> "\r\n"
    read 2 bytes
    -> "0\r\n"
    -> "\r\n"
    Conn close
    POST_SCRUBBED
  end

  def successful_authentication_token_response
    %({"access_token":"143647966756d45627368616e647:143647966756d45627368616e647132333:e1d68ca375e89dea80f7f3009ba3c52d965d1126c85ebc90edd9e6c751c4bf05","token_type":"bearer","expires_in":7200,"created_at":1507667632})
  end

  def successful_purchase_response
    %({"success":true,"response_code":101,"status_message":"Your transaction was successfully approved.","transaction_id":178349480,"approval_code":"TAS867","approval_message":"APPROVAL TAS867  - Approved and completed","avs_response":"0","csc_response":"Match","external_transaction_id":"","masked_card_number":"xxxxxxxxxxxx5439"})
  end

  def failed_purchase_response
    %({"success":false,"response_code":102,"status_message":"Your transaction was not approved.","transaction_id":178803407,"approval_code":"","approval_message":"    DECLINE      - Do not honor","avs_response":"0","csc_response":"Match","discretionary_data":{"BALANCEAMOUNT":"11111.11"},"external_transaction_id":"","masked_card_number":"xxxxxxxxxxxx5439"})
  end

  def successful_authorize_response
    %({"success":true,"response_code":101,"status_message":"Your transaction was successfully approved.","transaction_id":178963007,"approval_code":"TAS363","approval_message":"APPROVAL TAS363  - Approved and completed","avs_response":"0","csc_response":"Match","external_transaction_id":"","masked_card_number":"xxxxxxxxxxxx5439"})
  end

  def failed_authorize_response
    %({"success":false,"response_code":102,"status_message":"Your transaction was not approved.","transaction_id":178965251,"approval_code":"","approval_message":"    DECLINE      - Do not honor","avs_response":"0","csc_response":"Match","discretionary_data":{"BALANCEAMOUNT":"11111.11"},"external_transaction_id":"","masked_card_number":"xxxxxxxxxxxx5439"})
  end

  def successful_capture_response
    %({"success":true,"response_code":112,"status_message":"Your transaction was successfully captured.","transaction_id":178968803,"external_transaction_id":""})
  end

  def failed_capture_response
    %({"success":false,"response_code":1,"status_message":"One or more errors has occurred.","errors":{"811":["The Transaction ID that you provided was not found."]},"external_transaction_id":""})
  end

  def failed_transaction_capture_response
    %({"success":false,"response_code":1,"status_message":"One or more errors has occurred.","errors":{"816":["The Transaction ID that you provided could not be captured. Only uncaptured, approved authorizations can be captured."]},"external_transaction_id":""})
  end

  def successful_refund_response
    %({"success":true,"response_code":106,"status_message":"Your transaction was successfully refunded.","transaction_id":179066852,"external_transaction_id":"","masked_card_number":"xxxxxxxxxxxx5439"})
  end

  def failed_refund_response
    %({"success":false,"response_code":1,"status_message":"One or more errors has occurred.","errors":{"811":["The Transaction ID that you provided was not found."]},"external_transaction_id":""})
  end

  def failed_transaction_refund_response
    %({"success":false,"response_code":1,"status_message":"One or more errors has occurred.","errors":{"817":["The Transaction ID that you provided could not be refunded. Only settled transactions can be refunded.  Please try to void the transaction instead."]},"external_transaction_id":""})
  end

  def successful_void_response
    %({"success":true,"response_code":109,"status_message":"Your transaction was successfully voided.","transaction_id":179081332})
  end

  def failed_void_response
    %({"success":false,"response_code":1,"status_message":"One or more errors has occurred.","errors":{"811":["The Transaction ID that you provided was not found."]}})
  end

  def failed_transaction_void_response
    %({"success":false,"response_code":1,"status_message":"One or more errors has occurred.","errors":{"818":["The Transaction ID that you provided could not be voided. Only transactions that are pending settlement can be voided."]}})
  end

  def successful_level_3_data_response
    %({"success":true,"response_code":170,"status_message":"Visa/MasterCard enhanced data was successfully added to Transaction ID 179509448. 1 line item records were created."})
  end

  def failed_level_3_data_response
    %({"success":false,"response_code":1,"status_message":"One or more errors has occurred.","errors":{"58":["Please provide a valid Transaction ID."]}})
  end
end
