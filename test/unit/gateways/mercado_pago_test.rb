require 'test_helper'

class MercadoPagoTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = MercadoPagoGateway.new(access_token: 'access_token')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).at_most(2).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal "4141491|1.0", response.authorization
    assert_equal "accredited", response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).at_most(2).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "rejected", response.error_code
    assert_equal "cc_rejected_other_reason", response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).at_most(2).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal "4261941|1.0", response.authorization
    assert_equal "pending_capture", response.message
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).at_most(2).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "rejected", response.error_code
    assert_equal "cc_rejected_other_reason", response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway.capture(@amount, "authorization|amount")
    assert_success response

    assert_equal "4261941|1.0", response.authorization
    assert_equal "accredited", response.message
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, "")
    assert_failure response

    assert_equal "|1.0", response.authorization
    assert_equal "Method not allowed", response.message
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'authorization|1.0', @options)
    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, '', @options)
    assert_failure response
    assert_equal nil, response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)

    response = @gateway.void("authorization|amount")
    assert_success response

    assert_equal "4261966|", response.authorization
    assert_equal "by_collector", response.message
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void("")
    assert_failure response

    assert_equal "|", response.authorization
    assert_equal "Method not allowed", response.message
    assert response.test?
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).at_most(3).returns(successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal "by_collector", response.message
    assert response.test?
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_request).at_most(3).returns(failed_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response

    assert_equal "Method not allowed", response.message
    assert response.test?
  end

  def test_failed_verify
    @gateway.expects(:ssl_request).at_most(2).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response

    assert_equal "cc_rejected_other_reason", response.message
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_sends_american_express_as_amex
    credit_card = credit_card('378282246310005', brand: 'american_express')

    response = stub_comms do
      @gateway.purchase(@amount, credit_card, @options)
    end.check_request do |endpoint, data, headers|
      if data =~ /"payment_method_id"/
        assert_match(%r(amex), data)
      end
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '4141491|1.0', response.authorization
  end

  def test_sends_diners_club_as_diners
    credit_card = credit_card('30569309025904', brand: 'diners_club')

    response = stub_comms do
      @gateway.purchase(@amount, credit_card, @options)
    end.check_request do |endpoint, data, headers|
      if data =~ /"payment_method_id"/
        assert_match(%r(diners), data)
      end
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '4141491|1.0', response.authorization
  end

  def test_sends_mastercard_as_master
    credit_card = credit_card('5555555555554444', brand: 'master')

    response = stub_comms do
      @gateway.purchase(@amount, credit_card, @options)
    end.check_request do |endpoint, data, headers|
      if data =~ /"payment_method_id"/
        assert_match(%r(master), data)
      end
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '4141491|1.0', response.authorization
  end

  private

  def pre_scrubbed
    %q(
      opening connection to api.mercadopago.com:443...
      opened
      starting SSL for api.mercadopago.com:443...
      SSL established
      <- "POST /v1/card_tokens?access_token=TEST-8527269031909288-071213-0fc96cb7cd3633189bfbe29f63722700__LB_LA__-263489584 HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.mercadopago.com\r\nContent-Length: 140\r\n\r\n"
      <- "{\"card_number\":\"4509953566233704\",\"security_code\":\"123\",\"expiration_month\":9,\"expiration_year\":2018,\"cardholder\":{\"name\":\"Longbob Longsen\"}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "X-Request-Id: eb7a95a0-dccb-4580-9a69-534f6faf0bd6\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Date: Thu, 13 Jul 2017 17:37:58 GMT\r\n"
      -> "Connection: close\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Strict-Transport-Security: max-age=16070400\r\n"
      -> "Set-Cookie: TS016da221=0119b547a2244bba3789910575ac019d7d44d644026217ca433918a8c8fd9ff83de9d4b3c095adc76ee58870b56cd33041797db9e2; Path=/; Secure; HTTPOnly\r\n"
      -> "Vary: Accept-Encoding, User-Agent\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "\r\n"
      Conn close
      opening connection to api.mercadopago.com:443...
      opened
      starting SSL for api.mercadopago.com:443...
      SSL established
      <- "POST /v1/payments?access_token=TEST-8527269031909288-071213-0fc96cb7cd3633189bfbe29f63722700__LB_LA__-263489584 HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.mercadopago.com\r\nContent-Length: 395\r\n\r\n"
      <- "{\"transaction_amount\":5.0,\"description\":\"Store Purchase\",\"installments\":1,\"order\":{\"type\":\"mercadopago\",\"id\":2554731505684667137},\"token\":\"02ed9760103508d54361da8741a22a9e\",\"payment_method_id\":\"visa\",\"additional_info\":{\"payer\":{\"address\":{\"zip_code\":\"K1C2N6\",\"street_number\":\"456\",\"street_name\":\"My Street\"}}},\"payer\":{\"email\":\"user+br@example.com\",\"first_name\":\"Longbob\",\"last_name\":\"Longsen\"}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Thu, 13 Jul 2017 17:37:59 GMT\r\n"
      -> "Content-Type: application/json;charset=UTF-8\r\n"
      -> "Connection: close\r\n"
      -> "X-Response-Status: approved/accredited\r\n"
      -> "X-Caller-Id: 263489584\r\n"
      -> "Vary: Accept,Accept-Encoding, User-Agent\r\n"
      -> "Cache-Control: max-age=0\r\n"
      -> "ETag: 1deee4b03ae344416c5863ac0d92c13e\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Frame-Options: DENY\r\n"
      -> "X-Request-Id: ccb324d1-8365-42dd-8e9a-734488220777\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "Strict-Transport-Security: max-age=15724800\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Headers: Content-Type\r\n"
      -> "Access-Control-Allow-Methods: PUT, GET, POST, DELETE, OPTIONS\r\n"
      -> "Access-Control-Max-Age: 86400\r\n"
      -> "Set-Cookie: TS016da221=0119b547a287375accd901052e4871cecbc881599be32e9bcb508701e62cabee4424801a25969778d1c93e2c57c2fd0a8a934c9817; Path=/; Secure; HTTPOnly\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "\r\n"
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to api.mercadopago.com:443...
      opened
      starting SSL for api.mercadopago.com:443...
      SSL established
      <- "POST /v1/card_tokens?access_token=[FILTERED] HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.mercadopago.com\r\nContent-Length: 140\r\n\r\n"
      <- "{\"card_number\":\"[FILTERED]\",\"security_code\":\"[FILTERED]\",\"expiration_month\":9,\"expiration_year\":2018,\"cardholder\":{\"name\":\"Longbob Longsen\"}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "X-Request-Id: eb7a95a0-dccb-4580-9a69-534f6faf0bd6\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Date: Thu, 13 Jul 2017 17:37:58 GMT\r\n"
      -> "Connection: close\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Strict-Transport-Security: max-age=16070400\r\n"
      -> "Set-Cookie: TS016da221=0119b547a2244bba3789910575ac019d7d44d644026217ca433918a8c8fd9ff83de9d4b3c095adc76ee58870b56cd33041797db9e2; Path=/; Secure; HTTPOnly\r\n"
      -> "Vary: Accept-Encoding, User-Agent\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "\r\n"
      Conn close
      opening connection to api.mercadopago.com:443...
      opened
      starting SSL for api.mercadopago.com:443...
      SSL established
      <- "POST /v1/payments?access_token=[FILTERED] HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.mercadopago.com\r\nContent-Length: 395\r\n\r\n"
      <- "{\"transaction_amount\":5.0,\"description\":\"Store Purchase\",\"installments\":1,\"order\":{\"type\":\"mercadopago\",\"id\":2554731505684667137},\"token\":\"02ed9760103508d54361da8741a22a9e\",\"payment_method_id\":\"visa\",\"additional_info\":{\"payer\":{\"address\":{\"zip_code\":\"K1C2N6\",\"street_number\":\"456\",\"street_name\":\"My Street\"}}},\"payer\":{\"email\":\"user+br@example.com\",\"first_name\":\"Longbob\",\"last_name\":\"Longsen\"}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Thu, 13 Jul 2017 17:37:59 GMT\r\n"
      -> "Content-Type: application/json;charset=UTF-8\r\n"
      -> "Connection: close\r\n"
      -> "X-Response-Status: approved/accredited\r\n"
      -> "X-Caller-Id: 263489584\r\n"
      -> "Vary: Accept,Accept-Encoding, User-Agent\r\n"
      -> "Cache-Control: max-age=0\r\n"
      -> "ETag: 1deee4b03ae344416c5863ac0d92c13e\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Frame-Options: DENY\r\n"
      -> "X-Request-Id: ccb324d1-8365-42dd-8e9a-734488220777\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "Strict-Transport-Security: max-age=15724800\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Headers: Content-Type\r\n"
      -> "Access-Control-Allow-Methods: PUT, GET, POST, DELETE, OPTIONS\r\n"
      -> "Access-Control-Max-Age: 86400\r\n"
      -> "Set-Cookie: TS016da221=0119b547a287375accd901052e4871cecbc881599be32e9bcb508701e62cabee4424801a25969778d1c93e2c57c2fd0a8a934c9817; Path=/; Secure; HTTPOnly\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "\r\n"
      Conn close
    )
  end

  def successful_purchase_response
    %(
      {"id":4141491,"date_created":"2017-07-06T09:49:35.000-04:00","date_approved":"2017-07-06T09:49:35.000-04:00","date_last_updated":"2017-07-06T09:49:35.000-04:00","date_of_expiration":null,"money_release_date":"2017-07-18T09:49:35.000-04:00","operation_type":"regular_payment","issuer_id":"166","payment_method_id":"visa","payment_type_id":"credit_card","status":"approved","status_detail":"accredited","currency_id":"MXN","description":"Store Purchase","live_mode":false,"sponsor_id":null,"authorization_code":null,"related_exchange_rate":null,"collector_id":261735089,"payer":{"type":"guest","id":null,"email":"user@example.com","identification":{"type":null,"number":null},"phone":{"area_code":null,"number":null,"extension":""},"first_name":"First User","last_name":"User","entity_type":null},"metadata":{},"additional_info":{"payer":{"address":{"zip_code":"K1C2N6","street_name":"My Street","street_number":"456"}}},"order":{"type":"mercadopago","id":"2326513804447055222"},"external_reference":null,"transaction_amount":5,"transaction_amount_refunded":0,"coupon_amount":0,"differential_pricing_id":null,"deduction_schema":null,"transaction_details":{"net_received_amount":0.14,"total_paid_amount":5,"overpaid_amount":0,"external_resource_url":null,"installment_amount":5,"financial_institution":null,"payment_method_reference_id":null,"payable_deferral_period":null,"acquirer_reference":null},"fee_details":[{"type":"mercadopago_fee","amount":4.86,"fee_payer":"collector"}],"captured":true,"binary_mode":false,"call_for_authorize_id":null,"statement_descriptor":"WWW.MERCADOPAGO.COM","installments":1,"card":{"id":null,"first_six_digits":"450995","last_four_digits":"3704","expiration_month":9,"expiration_year":2018,"date_created":"2017-07-06T09:49:35.000-04:00","date_last_updated":"2017-07-06T09:49:35.000-04:00","cardholder":{"name":"Longbob Longsen","identification":{"number":null,"type":null}}},"notification_url":null,"refunds":[],"processing_mode":null,"merchant_account_id":null,"acquirer":null,"merchant_number":null}
    )
  end

  def failed_purchase_response
    %(
      {"id":4142297,"date_created":"2017-07-06T10:13:32.000-04:00","date_approved":null,"date_last_updated":"2017-07-06T10:13:32.000-04:00","date_of_expiration":null,"money_release_date":null,"operation_type":"regular_payment","issuer_id":"166","payment_method_id":"visa","payment_type_id":"credit_card","status":"rejected","status_detail":"cc_rejected_other_reason","currency_id":"MXN","description":"Store Purchase","live_mode":false,"sponsor_id":null,"authorization_code":null,"related_exchange_rate":null,"collector_id":261735089,"payer":{"type":"guest","id":null,"email":"user@example.com","identification":{"type":null,"number":null},"phone":{"area_code":null,"number":null,"extension":""},"first_name":"First User","last_name":"User","entity_type":null},"metadata":{},"additional_info":{"payer":{"address":{"zip_code":"K1C2N6","street_name":"My Street","street_number":"456"}}},"order":{"type":"mercadopago","id":"830943860538524456"},"external_reference":null,"transaction_amount":5,"transaction_amount_refunded":0,"coupon_amount":0,"differential_pricing_id":null,"deduction_schema":null,"transaction_details":{"net_received_amount":0,"total_paid_amount":5,"overpaid_amount":0,"external_resource_url":null,"installment_amount":5,"financial_institution":null,"payment_method_reference_id":null,"payable_deferral_period":null,"acquirer_reference":null},"fee_details":[],"captured":true,"binary_mode":false,"call_for_authorize_id":null,"statement_descriptor":"WWW.MERCADOPAGO.COM","installments":1,"card":{"id":null,"first_six_digits":"400030","last_four_digits":"2220","expiration_month":9,"expiration_year":2018,"date_created":"2017-07-06T10:13:32.000-04:00","date_last_updated":"2017-07-06T10:13:32.000-04:00","cardholder":{"name":"Longbob Longsen","identification":{"number":null,"type":null}}},"notification_url":null,"refunds":[],"processing_mode":null,"merchant_account_id":null,"acquirer":null,"merchant_number":null}
    )
  end

  def successful_authorize_response
    %(
      {"id":4261941,"date_created":"2017-07-13T14:24:46.000-04:00","date_approved":null,"date_last_updated":"2017-07-13T14:24:46.000-04:00","date_of_expiration":null,"money_release_date":null,"operation_type":"regular_payment","issuer_id":"25","payment_method_id":"visa","payment_type_id":"credit_card","status":"authorized","status_detail":"pending_capture","currency_id":"BRL","description":"Store Purchase","live_mode":false,"sponsor_id":null,"authorization_code":null,"related_exchange_rate":null,"collector_id":263489584,"payer":{"type":"guest","id":null,"email":"user+br@example.com","identification":{"type":null,"number":null},"phone":{"area_code":null,"number":null,"extension":null},"first_name":null,"last_name":null,"entity_type":null},"metadata":{},"additional_info":{"payer":{"address":{"zip_code":"K1C2N6","street_name":"My Street","street_number":"456"}}},"order":{"type":"mercadopago","id":"2294029672081601730"},"external_reference":null,"transaction_amount":5,"transaction_amount_refunded":0,"coupon_amount":0,"differential_pricing_id":null,"deduction_schema":null,"transaction_details":{"net_received_amount":0,"total_paid_amount":5,"overpaid_amount":0,"external_resource_url":null,"installment_amount":5,"financial_institution":null,"payment_method_reference_id":null,"payable_deferral_period":null,"acquirer_reference":null},"fee_details":[],"captured":false,"binary_mode":false,"call_for_authorize_id":null,"statement_descriptor":"WWW.MERCADOPAGO.COM","installments":1,"card":{"id":null,"first_six_digits":"450995","last_four_digits":"3704","expiration_month":9,"expiration_year":2018,"date_created":"2017-07-13T14:24:46.000-04:00","date_last_updated":"2017-07-13T14:24:46.000-04:00","cardholder":{"name":"Longbob Longsen","identification":{"number":null,"type":null}}},"notification_url":null,"refunds":[],"processing_mode":"aggregator","merchant_account_id":null,"acquirer":null,"merchant_number":null}
    )
  end

  def failed_authorize_response
    %(
      {"id":4261953,"date_created":"2017-07-13T14:25:33.000-04:00","date_approved":null,"date_last_updated":"2017-07-13T14:25:33.000-04:00","date_of_expiration":null,"money_release_date":null,"operation_type":"regular_payment","issuer_id":"25","payment_method_id":"visa","payment_type_id":"credit_card","status":"rejected","status_detail":"cc_rejected_other_reason","currency_id":"BRL","description":"Store Purchase","live_mode":false,"sponsor_id":null,"authorization_code":null,"related_exchange_rate":null,"collector_id":263489584,"payer":{"type":"guest","id":null,"email":"user+br@example.com","identification":{"type":null,"number":null},"phone":{"area_code":null,"number":null,"extension":null},"first_name":null,"last_name":null,"entity_type":null},"metadata":{},"additional_info":{"payer":{"address":{"zip_code":"K1C2N6","street_name":"My Street","street_number":"456"}}},"order":{"type":"mercadopago","id":"7528376941458928221"},"external_reference":null,"transaction_amount":5,"transaction_amount_refunded":0,"coupon_amount":0,"differential_pricing_id":null,"deduction_schema":null,"transaction_details":{"net_received_amount":0,"total_paid_amount":5,"overpaid_amount":0,"external_resource_url":null,"installment_amount":5,"financial_institution":null,"payment_method_reference_id":null,"payable_deferral_period":null,"acquirer_reference":null},"fee_details":[],"captured":false,"binary_mode":false,"call_for_authorize_id":null,"statement_descriptor":"WWW.MERCADOPAGO.COM","installments":1,"card":{"id":null,"first_six_digits":"400030","last_four_digits":"2220","expiration_month":9,"expiration_year":2018,"date_created":"2017-07-13T14:25:33.000-04:00","date_last_updated":"2017-07-13T14:25:33.000-04:00","cardholder":{"name":"Longbob Longsen","identification":{"number":null,"type":null}}},"notification_url":null,"refunds":[],"processing_mode":"aggregator","merchant_account_id":null,"acquirer":null,"merchant_number":null}
    )
  end

  def successful_capture_response
    %(
      {"id":4261941,"date_created":"2017-07-13T14:24:46.000-04:00","date_approved":"2017-07-13T14:24:47.000-04:00","date_last_updated":"2017-07-13T14:24:47.000-04:00","date_of_expiration":null,"money_release_date":"2017-07-27T14:24:47.000-04:00","operation_type":"regular_payment","issuer_id":"25","payment_method_id":"visa","payment_type_id":"credit_card","status":"approved","status_detail":"accredited","currency_id":"BRL","description":"Store Purchase","live_mode":false,"sponsor_id":null,"authorization_code":null,"related_exchange_rate":null,"collector_id":263489584,"payer":{"type":"guest","id":null,"email":"user+br@example.com","identification":{"type":null,"number":null},"phone":{"area_code":null,"number":null,"extension":null},"first_name":null,"last_name":null,"entity_type":null},"metadata":{},"additional_info":{"payer":{"address":{"zip_code":"K1C2N6","street_name":"My Street","street_number":"456"}}},"order":{"type":"mercadopago","id":"2294029672081601730"},"external_reference":null,"transaction_amount":5,"transaction_amount_refunded":0,"coupon_amount":0,"differential_pricing_id":null,"deduction_schema":null,"transaction_details":{"net_received_amount":4.75,"total_paid_amount":5,"overpaid_amount":0,"external_resource_url":null,"installment_amount":5,"financial_institution":null,"payment_method_reference_id":null,"payable_deferral_period":null,"acquirer_reference":null},"fee_details":[{"type":"mercadopago_fee","amount":0.25,"fee_payer":"collector"}],"captured":true,"binary_mode":false,"call_for_authorize_id":null,"statement_descriptor":"WWW.MERCADOPAGO.COM","installments":1,"card":{"id":null,"first_six_digits":"450995","last_four_digits":"3704","expiration_month":9,"expiration_year":2018,"date_created":"2017-07-13T14:24:46.000-04:00","date_last_updated":"2017-07-13T14:24:46.000-04:00","cardholder":{"name":"Longbob Longsen","identification":{"number":null,"type":null}}},"notification_url":null,"refunds":[],"processing_mode":"aggregator","merchant_account_id":null,"acquirer":null,"merchant_number":null}
    )
  end

  def failed_capture_response
    %(
      {"message":"Method not allowed","error":"method_not_allowed","status":405,"cause":[{"code":"Method not allowed","description":"Method not allowed","data":null}]}
    )
  end

  def successful_refund_response
    %(
      {"id":4247757,"payment_id":4247751,"amount":5,"metadata":{},"source":{"id":"261735089","name":"Spreedly Integrations","type":"collector"},"date_created":"2017-07-12T14:45:08.752-04:00","unique_sequence_number":null}
    )
  end

  def failed_refund_response
    %(
      {"message":"Resource /payments/refunds/ not found.","error":"not_found","status":404,"cause":[]}
    )
  end

  def successful_void_response
    %(
      {"id":4261966,"date_created":"2017-07-13T14:26:56.000-04:00","date_approved":null,"date_last_updated":"2017-07-13T14:26:57.000-04:00","date_of_expiration":null,"money_release_date":null,"operation_type":"regular_payment","issuer_id":"25","payment_method_id":"visa","payment_type_id":"credit_card","status":"cancelled","status_detail":"by_collector","currency_id":"BRL","description":"Store Purchase","live_mode":false,"sponsor_id":null,"authorization_code":null,"related_exchange_rate":null,"collector_id":263489584,"payer":{"type":"guest","id":null,"email":"user+br@example.com","identification":{"type":null,"number":null},"phone":{"area_code":null,"number":null,"extension":null},"first_name":null,"last_name":null,"entity_type":null},"metadata":{},"additional_info":{"payer":{"address":{"zip_code":"K1C2N6","street_name":"My Street","street_number":"456"}}},"order":{"type":"mercadopago","id":"6688620487994029432"},"external_reference":null,"transaction_amount":5,"transaction_amount_refunded":0,"coupon_amount":0,"differential_pricing_id":null,"deduction_schema":null,"transaction_details":{"net_received_amount":0,"total_paid_amount":5,"overpaid_amount":0,"external_resource_url":null,"installment_amount":5,"financial_institution":null,"payment_method_reference_id":null,"payable_deferral_period":null,"acquirer_reference":null},"fee_details":[],"captured":false,"binary_mode":false,"call_for_authorize_id":null,"statement_descriptor":"WWW.MERCADOPAGO.COM","installments":1,"card":{"id":null,"first_six_digits":"450995","last_four_digits":"3704","expiration_month":9,"expiration_year":2018,"date_created":"2017-07-13T14:26:56.000-04:00","date_last_updated":"2017-07-13T14:26:56.000-04:00","cardholder":{"name":"Longbob Longsen","identification":{"number":null,"type":null}}},"notification_url":null,"refunds":[],"processing_mode":"aggregator","merchant_account_id":null,"acquirer":null,"merchant_number":null}
    )
  end

  def failed_void_response
    %(
      {"message":"Method not allowed","error":"method_not_allowed","status":405,"cause":[{"code":"Method not allowed","description":"Method not allowed","data":null}]}
    )
  end
end
