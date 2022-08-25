require 'test_helper'

class PayComTest < Test::Unit::TestCase
  def setup
    @gateway = PayComGateway.new(api_key: 'UNIT_TEST')
    @amount = 100
    @credit_card = CreditCard.new(
      :first_name         => 'Test',
      :last_name          => 'abcdfg',
      :month              => '11',
      :year               => '24',
      :number             => '4018810000150015',
      :verification_value => '123'
    )

    @declined_card = CreditCard.new(
      :first_name         => 'Test',
      :last_name          => 'abcdfg',
      :month              => '11',
      :year               => '24',
      :number             => '4000000000001091',
      :verification_value => '123'
    )
    @options = {
      billing_address: {
        address_line1: "23/2 115 Kirkton Avenue",
        address_line2: "",
        city: "Glasgow",
        postal_code: "G13 3EN",
        country: "GB",
      },
      consumer_details: {
        email: "consumer2@pay.com",
        first_name: "John",
        last_name: "Doe",
        phone: "447123456789"
      },
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '217971049529081856', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).twice.returns(successful_authorize_response, successful_capture_response)

    auth = @gateway.authorize(@amount, @declined_card, @options)
    capture = @gateway.capture(@amount, auth.authorization)

    assert_success capture
    assert_equal 'Transaction approved', capture.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    auth = @gateway.authorize(@amount, @declined_card, @options)
    capture = @gateway.capture(@amount, '')

    assert_failure capture
    assert_equal 'Authorization id must be provided for capture', capture.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).twice.returns(successful_purchase_response, successful_refund_response)

    purchase = @gateway.purchase(@amount, @credit_card, @options)
    refund = @gateway.refund(@amount, purchase.authorization)

    assert_success refund
    assert_equal 'Transaction approved', refund.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    purchase = @gateway.purchase(@amount, @credit_card, @options)
    refund = @gateway.refund(@amount, '')

    assert_failure refund
    assert_equal 'Authorization id must be provided for refund', refund.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).twice.returns(successful_authorize_response, successful_void_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    void = @gateway.void(auth.authorization)

    assert_success void
    assert_equal 'Transaction approved', void.message
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    auth = @gateway.authorize(@amount, @declined_card, @options)
    void = @gateway.void('')

    assert_failure void
    assert_equal 'Authorization id must be provided for void', void.message
  end

  private

  def successful_purchase_response
    '{"id":"217971049529081856","resource":"payment","amount":1,"amount_cancelled":0,"amount_capturable":0,"amount_received":1,"amount_refunded":0,"approved":true,"approved_amount":1,"billing":{"address_line1":"23/2 115 Kirkton Avenue","address_line2":null,"city":"Glasgow","country":"GB","postal_code":"G13 3EN","state":null},"capture_method":"immediately","consumer":{"id":"217971048073660416","email":"consumer2@pay.com","first_name":"John","last_name":"Doe","phone":"447123456789","reference":"217971048073660416"},"created_at":"2022-08-25T11:39:07.959Z","currency":"USD","metadata":{},"payment_method":{"card":{"address_line1_check":"UNAVAILABLE","address_postal_code_check":"UNAVAILABLE","bin":"401881","brand":"Visa","card_category":"CONSUMER","card_type":"CREDIT","cvc_check":"PASS","expiry_month":"11","expiry_year":"24","fingerprint":"","issuer_country":"MT","issuer_name":"Bank of Valletta p.l.c","last_four_digits":"0015","name":"Test abcdfg"},"multiple":[],"type":"card","unique_identifier":"144045414033658880"},"processed_at":"2022-08-25T11:39:12.000Z","recurring_type":null,"reference":null,"result":{"auth_code":"274908","retrieval_reference_number":"223722700792","scheme_id":"202223725000858","status_code":0,"status_message":"Approved or completed successfully"},"shipping":null,"source":"payment_method","statement_descriptor":null,"status":"CAPTURED","three_ds":null,"transactions":[{"id":"217971049529081856","amount":1,"approved":true,"created_at":"2022-08-25T11:39:07.959Z","currency":"USD","metadata":{},"payment_id":"217971049529081856","reference":null,"resource":"transaction","result":{"auth_code":"274908","retrieval_reference_number":"223722700792","scheme_id":"202223725000858","status_code":0,"status_message":"Approved or completed successfully"},"type":"CAPTURE"}],"type":"REGULAR"}'
  end

  def failed_purchase_response
    '{"id":"217971946262891520","resource":"payment","amount":1,"amount_cancelled":0,"amount_capturable":0,"amount_received":0,"amount_refunded":0,"approved":false,"approved_amount":0,"billing":{"address_line1":"23/2 115 Kirkton Avenue","address_line2":null,"city":"Glasgow","country":"GB","postal_code":"G13 3EN","state":null},"capture_method":"immediately","consumer":{"id":"217971944358674432","email":"consumer2@pay.com","first_name":"John","last_name":"Doe","phone":"447123456789","reference":"217971944358674432"},"created_at":"2022-08-25T11:42:41.726Z","currency":"USD","metadata":{},"payment_method":{"card":{"address_line1_check":"UNAVAILABLE","address_postal_code_check":"UNAVAILABLE","bin":"400000","brand":"UNKNOWN","card_category":"UNKNOWN","card_type":"UNKNOWN","cvc_check":"UNAVAILABLE","expiry_month":"11","expiry_year":"24","fingerprint":"eb2ff6c6f8e6f39f0f9297171f36255261b87d2472267955b55aab2ad7f5e333","issuer_country":"UNKNOWN","issuer_name":"Issuer","last_four_digits":"1091","name":"Test abcdfg"},"multiple":[],"type":"card","unique_identifier":"217271287368651776"},"processed_at":"2022-08-25T11:42:45.000Z","recurring_type":null,"reference":null,"result":{"auth_code":null,"retrieval_reference_number":"223722700821","scheme_id":null,"status_code":57,"status_message":"Transaction not allowed for cardholder"},"shipping":null,"source":"payment_method","statement_descriptor":null,"status":"DECLINED","three_ds":null,"transactions":[],"type":"REGULAR"}'
  end

  def successful_authorize_response
    '{"id":"217987790158168064","resource":"payment","amount":1,"amount_cancelled":0,"amount_capturable":1,"amount_received":0,"amount_refunded":0,"approved":true,"approved_amount":1,"billing":{"address_line1":"23/2 115 Kirkton Avenue","address_line2":null,"city":"Glasgow","country":"GB","postal_code":"G13 3EN","state":null},"capture_method":"manual","consumer":{"id":"217987789281558528","email":"consumer2@pay.com","first_name":"John","last_name":"Doe","phone":"447123456789","reference":"217987789281558528"},"created_at":"2022-08-25T12:45:39.208Z","currency":"USD","metadata":{},"payment_method":{"card":{"address_line1_check":"UNAVAILABLE","address_postal_code_check":"UNAVAILABLE","bin":"401881","brand":"Visa","card_category":"CONSUMER","card_type":"CREDIT","cvc_check":"PASS","expiry_month":"11","expiry_year":"24","fingerprint":"","issuer_country":"MT","issuer_name":"Bank of Valletta p.l.c","last_four_digits":"0015","name":"Test abcdfg"},"multiple":[],"type":"card","unique_identifier":"144045414033658880"},"processed_at":"2022-08-25T12:45:43.000Z","recurring_type":null,"reference":null,"result":{"auth_code":"473657","retrieval_reference_number":"223722701218","scheme_id":"202223725000936","status_code":0,"status_message":"Approved or completed successfully"},"shipping":null,"source":"payment_method","statement_descriptor":null,"status":"AUTHORIZED","three_ds":null,"transactions":[],"type":"REGULAR"}'
  end

  def failed_authorize_response
    '{"id":"217987974313281536","resource":"payment","amount":1,"amount_cancelled":0,"amount_capturable":0,"amount_received":0,"amount_refunded":0,"approved":false,"approved_amount":0,"billing":{"address_line1":"23/2 115 Kirkton Avenue","address_line2":null,"city":"Glasgow","country":"GB","postal_code":"G13 3EN","state":null},"capture_method":"manual","consumer":{"id":"217987973738661888","email":"consumer2@pay.com","first_name":"John","last_name":"Doe","phone":"447123456789","reference":"217987973738661888"},"created_at":"2022-08-25T12:46:23.107Z","currency":"USD","metadata":{},"payment_method":{"card":{"address_line1_check":"UNAVAILABLE","address_postal_code_check":"UNAVAILABLE","bin":"400000","brand":"UNKNOWN","card_category":"UNKNOWN","card_type":"UNKNOWN","cvc_check":"UNAVAILABLE","expiry_month":"11","expiry_year":"24","fingerprint":"eb2ff6c6f8e6f39f0f9297171f36255261b87d2472267955b55aab2ad7f5e333","issuer_country":"UNKNOWN","issuer_name":"Issuer","last_four_digits":"1091","name":"Test abcdfg"},"multiple":[],"type":"card","unique_identifier":"217271287368651776"},"processed_at":"2022-08-25T12:46:26.000Z","recurring_type":null,"reference":null,"result":{"auth_code":null,"retrieval_reference_number":"223722701219","scheme_id":null,"status_code":57,"status_message":"Transaction not allowed for cardholder"},"shipping":null,"source":"payment_method","statement_descriptor":null,"status":"DECLINED","three_ds":null,"transactions":[],"type":"REGULAR"}'
  end

  def successful_capture_response
    '{"id":"217988166756338688","resource":"transaction","amount":1,"approved":true,"created_at":"2022-08-25T12:47:08.992Z","currency":"USD","metadata":{},"payment_id":"217988146237803520","reference":null,"result":{"auth_code":"334022","retrieval_reference_number":"223722701221","scheme_id":null,"status_code":0,"status_message":"Approved or completed successfully"},"type":"CAPTURE"}'
  end

  def successful_refund_response
    '{"id":"217988561427762176","resource":"transaction","amount":1,"approved":true,"created_at":"2022-08-25T12:48:43.157Z","currency":"USD","metadata":{},"payment_id":"217988537172099072","reference":null,"result":{"auth_code":"021642","retrieval_reference_number":"223722701227","scheme_id":null,"status_code":0,"status_message":"Approved or completed successfully"},"type":"REFUND"}'
  end

  def successful_void_response
    '{"id":"217988741212407808","resource":"transaction","amount":1,"approved":true,"created_at":"2022-08-25T12:49:25.949Z","currency":"USD","metadata":{},"payment_id":"217988718277953536","reference":null,"result":{"auth_code":"791246","retrieval_reference_number":"223722701229","scheme_id":null,"status_code":0,"status_message":"Approved or completed successfully"},"type":"CANCELLATION"}'
  end
end
