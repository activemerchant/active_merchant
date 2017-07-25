require 'test_helper'

class MercadopagoTest < Test::Unit::TestCase
  def setup
    @gateway = MercadopagoGateway.new(fixtures(:mercadopago))
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      email: 'user@example.com',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @options[:order_id] = '2961861'
    @gateway.expects(:get_token).returns(successful_get_token)
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 2962636, response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:get_token).returns(successful_get_token)
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end


  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    response = @gateway.refund(@amount, '2961861',{order_id: '2961959'})
    assert_equal 2961959, response.authorization
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    response = @gateway.refund(@amount, '2961862',{order_id: '2961960'})
    assert_failure response

  end


  private

  def successful_get_token

    body = JSON.parse %q({"public_key":null,"card_id":null,"first_six_digits":"450995","luhn_validation":true,"date_used":null,"status":"active","date_due":"2017-02-14T13:42:15.857-04:00","live_mode":false,"card_number_length":16,"id":"770f95f03ebb7f18661e37b60f76ab00","security_code_length":3,"expiration_year":2019,"expiration_month":10,"date_last_updated":"2017-02-06T13:42:15.856-04:00","last_four_digits":"3704","cardholder":{"identification":{"number":"987698","type":"DNI"},"name":"APRO"},"date_created":"2017-02-06T13:42:15.856-04:00"})
    ActiveMerchant::Billing::Response.new(
        true,
        "",
        body,
        authorization: body['id'],
        test: true,
        error_code: nil
    )
  end

  def successful_purchase_response
    %q(
     {"id":2962636,"date_created":"2017-02-06T13:42:16.000-04:00","date_approved":"2017-02-06T13:42:17.000-04:00","date_last_updated":"2017-02-06T13:42:17.000-04:00","money_release_date":"2017-02-20T13:42:17.076-04:00","operation_type":"regular_payment","issuer_id":"310","payment_method_id":"visa","payment_type_id":"credit_card","status":"approved","status_detail":"accredited","currency_id":"ARS","description":"Store Purchase","live_mode":false,"sponsor_id":null,"authorization_code":null,"collector_id":242453511,"payer":{"type":"guest","id":null,"email":"joe@example.com","identification":{"type":"DNI","number":"987698"},"phone":{"area_code":null,"number":null,"extension":""},"first_name":"","last_name":null,"entity_type":null},"metadata":{},"additional_info":{"payer":{"phone":{"number":"(555)555-5555"},"address":{"zip_code":"K1C2N6","street_name":"456 My Street Apt 1"},"last_name":"Jim Smith"}},"order":{},"external_reference":null,"transaction_amount":1,"transaction_amount_refunded":0,"coupon_amount":0,"differential_pricing_id":null,"deduction_schema":null,"transaction_details":{"net_received_amount":0.94,"total_paid_amount":1,"overpaid_amount":0,"external_resource_url":null,"installment_amount":1,"financial_institution":null,"payment_method_reference_id":null},"fee_details":[{"type":"mercadopago_fee","amount":0.06,"fee_payer":"collector"}],"captured":true,"binary_mode":false,"call_for_authorize_id":null,"statement_descriptor":"WWW.MERCADOPAGO.COM","installments":1,"card":{"id":null,"first_six_digits":"450995","last_four_digits":"3704","expiration_month":10,"expiration_year":2019,"date_created":"2017-02-06T13:42:16.000-04:00","date_last_updated":"2017-02-06T13:42:16.000-04:00","cardholder":{"name":"APRO","identification":{"number":"987698","type":"DNI"}}},"notification_url":null,"refunds":[]}    )
  end

  def failed_purchase_response
    %q({"id":2961937,"date_created":"2017-02-06T12:28:09.000-04:00","date_approved":null,"date_last_updated":"2017-02-06T12:28:09.000-04:00","money_release_date":null,"operation_type":"regular_payment","issuer_id":"310","payment_method_id":"visa","payment_type_id":"credit_card","status":"rejected","status_detail":"cc_rejected_insufficient_amount","currency_id":"ARS","description":"Store Purchase","live_mode":false,"sponsor_id":null,"authorization_code":null,"collector_id":242453511,"payer":{"type":"guest","id":null,"email":"joe@example.com","identification":{"type":null,"number":null},"phone":{"area_code":null,"number":null,"extension":""},"first_name":"","last_name":null,"entity_type":null},"metadata":{},"additional_info":{"payer":{"phone":{"number":"(555)555-5555"},"address":{"zip_code":"K1C2N6","street_name":"456 My Street Apt 1"},"last_name":"Jim Smith"}},"order":{},"external_reference":null,"transaction_amount":1,"transaction_amount_refunded":0,"coupon_amount":0,"differential_pricing_id":null,"deduction_schema":null,"transaction_details":{"net_received_amount":0,"total_paid_amount":1,"overpaid_amount":0,"external_resource_url":null,"installment_amount":1,"financial_institution":null,"payment_method_reference_id":null},"fee_details":[],"captured":true,"binary_mode":false,"call_for_authorize_id":null,"statement_descriptor":"WWW.MERCADOPAGO.COM","installments":1,"card":{"id":null,"first_six_digits":"450995","last_four_digits":"3704","expiration_month":10,"expiration_year":2019,"date_created":"2017-02-06T12:28:09.000-04:00","date_last_updated":"2017-02-06T12:28:09.000-04:00","cardholder":{"name":"FUND","identification":{"number":"987698","type":"DNI"}}},"notification_url":null,"refunds":[]})
  end

  def successful_refund_response
    %q({"id":2961959,"payment_id":2961953,"amount":1,"metadata":{},"source":{"id":"242453511","name":"Owner","type":"collector"},"date_created":"2017-02-06T12:29:24.809-04:00","unique_sequence_number":null})
  end

  def failed_refund_response
    %q({"message":"Payment not found","error":"not_found","status":404,"cause":[{"code":2000,"description":"Payment not found","data":null}]})
  end


end
