require 'test_helper'

class StripePaymentIntentsTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = StripePaymentIntentsGateway.new(login: 'login')

    @credit_card = credit_card()
    @threeds_2_card = credit_card('4000000000003220')
    @visa_token = 'pm_card_visa'
    @amount = 2020
    @update_amount = 2050

    @options = {
      currency: 'GBP',
      confirmation_method: 'manual'
    }
  end

  def test_successful_create_and_confirm_intent
    @gateway.expects(:ssl_request).times(3).returns(successful_create_3ds2_payment_method, successful_create_3ds2_intent_response, successful_confirm_3ds2_intent_response)

    assert create = @gateway.create_intent(@amount, @threeds_2_card, @options.merge(return_url: 'https://www.example.com', capture_method: 'manual'))
    assert_instance_of Response, create
    assert_success create

    assert_equal 'pi_1F1wpFAWOtgoysog8nTulYGk', create.authorization
    assert_equal 'requires_confirmation', create.params['status']
    assert create.test?

    assert confirm = @gateway.confirm_intent(create.params['id'], nil, return_url: 'https://example.com/return-to-me')
    assert_equal 'redirect_to_url', confirm.params.dig('next_action', 'type')
  end

  def test_successful_create_and_capture_intent
    options = @options.merge(capture_method: 'manual', confirm: true)
    @gateway.expects(:ssl_request).twice.returns(successful_create_intent_response, successful_capture_response)
    assert create = @gateway.create_intent(@amount, @visa_token, options)
    assert_success create
    assert_equal 'requires_capture', create.params['status']

    assert capture = @gateway.capture(@amount, create.params['id'], options)
    assert_success capture
    assert_equal 'succeeded', capture.params['status']
    assert_equal 'Payment complete.', capture.params.dig('charges', 'data')[0].dig('outcome', 'seller_message')
  end

  def test_successful_create_and_update_intent
    @gateway.expects(:ssl_request).twice.returns(successful_create_intent_response, successful_update_intent_response)
    assert create = @gateway.create_intent(@amount, @visa_token, @options.merge(capture_method: 'manual'))

    assert update = @gateway.update_intent(@update_amount, create.params['id'], nil, @options.merge(capture_method: 'manual'))
    assert_equal @update_amount, update.params['amount']
    assert_equal 'requires_confirmation', update.params['status']
  end

  def test_contains_statement_descriptor_suffix
    options = @options.merge(capture_method: 'manual', statement_descriptor_suffix: 'suffix')

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/statement_descriptor_suffix=suffix/, data)
    end.respond_with(successful_create_intent_response)
  end

  def test_successful_create_and_void_intent
    @gateway.expects(:ssl_request).twice.returns(successful_create_intent_response, successful_void_response)
    assert create = @gateway.create_intent(@amount, @visa_token, @options.merge(capture_method: 'manual', confirm: true))

    assert cancel = @gateway.void(create.params['id'])
    assert_equal @amount, cancel.params.dig('charges', 'data')[0].dig('amount_refunded')
    assert_equal 'canceled', cancel.params['status']
  end

  def test_create_intent_with_optional_idempotency_key_header
    idempotency_key = 'test123'
    options = @options.merge(idempotency_key: idempotency_key)

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, _data, headers|
      assert_equal idempotency_key, headers['Idempotency-Key']
    end.respond_with(successful_create_intent_response)
  end

  def test_request_three_d_secure
    request_three_d_secure = 'any'
    options = @options.merge(request_three_d_secure: request_three_d_secure)

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/\[request_three_d_secure\]=any/, data)
    end.respond_with(successful_request_three_d_secure_response)

    request_three_d_secure = 'automatic'
    options = @options.merge(request_three_d_secure: request_three_d_secure)

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/\[request_three_d_secure\]=automatic/, data)
    end.respond_with(successful_request_three_d_secure_response)

    request_three_d_secure = true
    options = @options.merge(request_three_d_secure: request_three_d_secure)

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      refute_match(/\[request_three_d_secure\]/, data)
    end.respond_with(successful_request_three_d_secure_response)
  end

  def test_external_three_d_secure_auth_data
    options = @options.merge(
      three_d_secure: {
        eci: '05',
        cavv: '4BQwsg4yuKt0S1LI1nDZTcO9vUM=',
        xid: 'd+NEBKSpEMauwleRhdrDY06qj4A='
      }
    )

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/payment_method_options\[card\]\[three_d_secure\]/, data)
      assert_match(/three_d_secure\]\[version\]=1.0.2/, data)
      assert_match(/three_d_secure\]\[electronic_commerce_indicator\]=05/, data)
      assert_match(/three_d_secure\]\[cryptogram\]=4BQwsg4yuKt0S1LI1nDZTcO9vUM%3D/, data)
      assert_match(/three_d_secure\]\[transaction_id\]=d%2BNEBKSpEMauwleRhdrDY06qj4A%3D/, data)
    end.respond_with(successful_request_three_d_secure_response)

    options = @options.merge(
      three_d_secure: {
        version: '2.1.0',
        eci: '02',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        ds_transaction_id: 'f879ea1c-aa2c-4441-806d-e30406466d79'
      }
    )

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/payment_method_options\[card\]\[three_d_secure\]/, data)
      assert_match(/three_d_secure\]\[version\]=2.1.0/, data)
      assert_match(/three_d_secure\]\[electronic_commerce_indicator\]=02/, data)
      assert_match(/three_d_secure\]\[cryptogram\]=jJ81HADVRtXfCBATEp01CJUAAAA%3D/, data)
      assert_match(/three_d_secure\]\[transaction_id\]=f879ea1c-aa2c-4441-806d-e30406466d79/, data)
    end.respond_with(successful_request_three_d_secure_response)
  end

  def test_failed_capture_after_creation
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    assert create = @gateway.create_intent(@amount, 'pm_card_chargeDeclined', @options.merge(confirm: true))
    assert_equal 'requires_payment_method', create.params.dig('error', 'payment_intent', 'status')
    assert_equal false, create.params.dig('error', 'payment_intent', 'charges', 'data')[0].dig('captured')
  end

  def test_failed_void_after_capture
    @gateway.expects(:ssl_request).twice.returns(successful_capture_response, failed_cancel_response)
    assert create = @gateway.create_intent(@amount, @visa_token, @options.merge(confirm: true))
    assert_equal 'succeeded', create.params['status']
    intent_id = create.params['id']

    assert cancel = @gateway.void(intent_id, cancellation_reason: 'requested_by_customer')
    assert_equal 'You cannot cancel this PaymentIntent because ' \
      'it has a status of succeeded. Only a PaymentIntent with ' \
      'one of the following statuses may be canceled: ' \
      'requires_payment_method, requires_capture, requires_confirmation, requires_action.', cancel.message
  end

  def test_connected_account
    destination = 'account_27701'
    amount = 8000
    on_behalf_of = 'account_27704'
    transfer_group = 'TG1000'
    application_fee_amount = 100

    options = @options.merge(
      transfer_destination: destination,
      transfer_amount: amount,
      on_behalf_of: on_behalf_of,
      transfer_group: transfer_group,
      application_fee: application_fee_amount
    )

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/transfer_data\[destination\]=#{destination}/, data)
      assert_match(/transfer_data\[amount\]=#{amount}/, data)
      assert_match(/on_behalf_of=#{on_behalf_of}/, data)
      assert_match(/transfer_group=#{transfer_group}/, data)
      assert_match(/application_fee_amount=#{application_fee_amount}/, data)
    end.respond_with(successful_create_intent_response)
  end

  def test_on_behalf_of
    on_behalf_of = 'account_27704'

    options = @options.merge(
      on_behalf_of: on_behalf_of
    )

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_no_match(/transfer_data\[destination\]/, data)
      assert_no_match(/transfer_data\[amount\]/, data)
      assert_match(/on_behalf_of=#{on_behalf_of}/, data)
      assert_no_match(/transfer_group/, data)
      assert_no_match(/application_fee_amount/, data)
    end.respond_with(successful_create_intent_response)
  end

  def test_failed_payment_methods_post
    @gateway.expects(:ssl_request).returns(failed_payment_method_response)

    assert create = @gateway.create_intent(@amount, 'pm_failed', @options)
    assert_equal 'validation_error', create.params.dig('error', 'code')
    assert_equal 'You must verify a phone number on your Stripe account before you can send raw credit card numbers to the Stripe API. You can avoid this requirement by using Stripe.js, the Stripe mobile bindings, or Stripe Checkout. For more information, see https://dashboard.stripe.com/phone-verification.', create.params.dig('error', 'message')
    assert_equal 'invalid_request_error', create.params.dig('error', 'type')
  end

  def test_failed_refund_due_to_service_unavailability
    @gateway.expects(:ssl_request).returns(failed_service_response)

    assert refund = @gateway.refund(@amount, 'pi_123')
    assert_failure refund
    assert_match(/Error while communicating with one of our backends/, refund.params.dig('error', 'message'))
  end

  def test_failed_refund_due_to_pending_3ds_auth
    @gateway.expects(:ssl_request).returns(successful_confirm_3ds2_intent_response)

    assert refund = @gateway.refund(@amount, 'pi_123')
    assert_failure refund
    assert_equal 'requires_action', refund.params['status']
    assert_match(/payment_intent has a status of requires_action/, refund.message)
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).returns(successful_verify_response)
    assert verify = @gateway.verify(@visa_token)
    assert_success verify
    assert_equal 'succeeded', verify.params['status']
  end

  private

  def successful_create_intent_response
    <<-RESPONSE
      {"id":"pi_1F1xauAWOtgoysogIfHO8jGi","object":"payment_intent","amount":2020,"amount_capturable":2020,"amount_received":0,"application":null,"application_fee_amount":null,"canceled_at":null,"cancellation_reason":null,"capture_method":"manual","charges":{"object":"list","data":[{"id":"ch_1F1xavAWOtgoysogxrtSiCu4","object":"charge","amount":2020,"amount_refunded":0,"application":null,"application_fee":null,"application_fee_amount":null,"balance_transaction":null,"billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"captured":false,"created":1564501833,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"destination":null,"dispute":null,"failure_code":null,"failure_message":null,"fraud_details":{},"invoice":null,"livemode":false,"metadata":{},"on_behalf_of":null,"order":null,"outcome":{"network_status":"approved_by_network","reason":null,"risk_level":"normal","risk_score":58,"seller_message":"Payment complete.","type":"authorized"},"paid":true,"payment_intent":"pi_1F1xauAWOtgoysogIfHO8jGi","payment_method":"pm_1F1xauAWOtgoysog00COoKIU","payment_method_details":{"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"hfaVNMiXc0dYSiC5","funding":"credit","last4":"4242","three_d_secure":null,"wallet":null},"type":"card"},"receipt_email":null,"receipt_number":null,"receipt_url":"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_1F1xavAWOtgoysogxrtSiCu4/rcpt_FX1eGdFRi8ssOY8Fqk4X6nEjNeGV5PG","refunded":false,"refunds":{"object":"list","data":[],"has_more":false,"total_count":0,"url":"/v1/charges/ch_1F1xavAWOtgoysogxrtSiCu4/refunds"},"review":null,"shipping":null,"source":null,"source_transfer":null,"statement_descriptor":null,"status":"succeeded","transfer_data":null,"transfer_group":null}],"has_more":false,"total_count":1,"url":"/v1/charges?payment_intent=pi_1F1xauAWOtgoysogIfHO8jGi"},"client_secret":"pi_1F1xauAWOtgoysogIfHO8jGi_secret_ZrXvfydFv0BelaMQJgHxjts5b","confirmation_method":"manual","created":1564501832,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"invoice":null,"last_payment_error":null,"livemode":false,"metadata":{},"next_action":null,"on_behalf_of":null,"payment_method":"pm_1F1xauAWOtgoysog00COoKIU","payment_method_options":{"card":{"request_three_d_secure":"automatic"}},"payment_method_types":["card"],"receipt_email":null,"review":null,"setup_future_usage":null,"shipping":null,"source":null,"statement_descriptor":null,"status":"requires_capture","transfer_data":null,"transfer_group":null}
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
      {"id":"pi_1F1xauAWOtgoysogIfHO8jGi","object":"payment_intent","amount":2020,"amount_capturable":0,"amount_received":2020,"application":null,"application_fee_amount":null,"canceled_at":null,"cancellation_reason":null,"capture_method":"manual","charges":{"object":"list","data":[{"id":"ch_1F1xavAWOtgoysogxrtSiCu4","object":"charge","amount":2020,"amount_refunded":0,"application":null,"application_fee":null,"application_fee_amount":null,"balance_transaction":"txn_1F1xawAWOtgoysog27xGBjM6","billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"captured":true,"created":1564501833,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"destination":null,"dispute":null,"failure_code":null,"failure_message":null,"fraud_details":{},"invoice":null,"livemode":false,"metadata":{},"on_behalf_of":null,"order":null,"outcome":{"network_status":"approved_by_network","reason":null,"risk_level":"normal","risk_score":58,"seller_message":"Payment complete.","type":"authorized"},"paid":true,"payment_intent":"pi_1F1xauAWOtgoysogIfHO8jGi","payment_method":"pm_1F1xauAWOtgoysog00COoKIU","payment_method_details":{"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"hfaVNMiXc0dYSiC5","funding":"credit","last4":"4242","three_d_secure":null,"wallet":null},"type":"card"},"receipt_email":null,"receipt_number":null,"receipt_url":"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_1F1xavAWOtgoysogxrtSiCu4/rcpt_FX1eGdFRi8ssOY8Fqk4X6nEjNeGV5PG","refunded":false,"refunds":{"object":"list","data":[],"has_more":false,"total_count":0,"url":"/v1/charges/ch_1F1xavAWOtgoysogxrtSiCu4/refunds"},"review":null,"shipping":null,"source":null,"source_transfer":null,"statement_descriptor":null,"status":"succeeded","transfer_data":null,"transfer_group":null}],"has_more":false,"total_count":1,"url":"/v1/charges?payment_intent=pi_1F1xauAWOtgoysogIfHO8jGi"},"client_secret":"pi_1F1xauAWOtgoysogIfHO8jGi_secret_ZrXvfydFv0BelaMQJgHxjts5b","confirmation_method":"manual","created":1564501832,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"invoice":null,"last_payment_error":null,"livemode":false,"metadata":{},"next_action":null,"on_behalf_of":null,"payment_method":"pm_1F1xauAWOtgoysog00COoKIU","payment_method_options":{"card":{"request_three_d_secure":"automatic"}},"payment_method_types":["card"],"receipt_email":null,"review":null,"setup_future_usage":null,"shipping":null,"source":null,"statement_descriptor":null,"status":"succeeded","transfer_data":null,"transfer_group":null}
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
      {"id":"pi_1F1yBVAWOtgoysogearamRvl","object":"payment_intent","amount":2020,"amount_capturable":0,"amount_received":0,"application":null,"application_fee_amount":null,"canceled_at":1564504103,"cancellation_reason":"requested_by_customer","capture_method":"manual","charges":{"object":"list","data":[{"id":"ch_1F1yBWAWOtgoysog1MQfDpJH","object":"charge","amount":2020,"amount_refunded":2020,"application":null,"application_fee":null,"application_fee_amount":null,"balance_transaction":null,"billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"captured":false,"created":1564504102,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"destination":null,"dispute":null,"failure_code":null,"failure_message":null,"fraud_details":{},"invoice":null,"livemode":false,"metadata":{},"on_behalf_of":null,"order":null,"outcome":{"network_status":"approved_by_network","reason":null,"risk_level":"normal","risk_score":46,"seller_message":"Payment complete.","type":"authorized"},"paid":true,"payment_intent":"pi_1F1yBVAWOtgoysogearamRvl","payment_method":"pm_1F1yBVAWOtgoysogddy4E3hL","payment_method_details":{"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"hfaVNMiXc0dYSiC5","funding":"credit","last4":"4242","three_d_secure":null,"wallet":null},"type":"card"},"receipt_email":null,"receipt_number":null,"receipt_url":"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_1F1yBWAWOtgoysog1MQfDpJH/rcpt_FX2Go3YHBqAYQPJuKGMeab3nyCU0Kks","refunded":true,"refunds":{"object":"list","data":[{"id":"re_1F1yBXAWOtgoysog0PU371Yz","object":"refund","amount":2020,"balance_transaction":null,"charge":"ch_1F1yBWAWOtgoysog1MQfDpJH","created":1564504103,"currency":"gbp","metadata":{},"reason":"requested_by_customer","receipt_number":null,"source_transfer_reversal":null,"status":"succeeded","transfer_reversal":null}],"has_more":false,"total_count":1,"url":"/v1/charges/ch_1F1yBWAWOtgoysog1MQfDpJH/refunds"},"review":null,"shipping":null,"source":null,"source_transfer":null,"statement_descriptor":null,"status":"succeeded","transfer_data":null,"transfer_group":null}],"has_more":false,"total_count":1,"url":"/v1/charges?payment_intent=pi_1F1yBVAWOtgoysogearamRvl"},"client_secret":"pi_1F1yBVAWOtgoysogearamRvl_secret_oCnlR2t0GPclqACgHt2rst4gM","confirmation_method":"manual","created":1564504101,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"invoice":null,"last_payment_error":null,"livemode":false,"metadata":{},"next_action":null,"on_behalf_of":null,"payment_method":"pm_1F1yBVAWOtgoysogddy4E3hL","payment_method_options":{"card":{"request_three_d_secure":"automatic"}},"payment_method_types":["card"],"receipt_email":null,"review":null,"setup_future_usage":null,"shipping":null,"source":null,"statement_descriptor":null,"status":"canceled","transfer_data":null,"transfer_group":null}
    RESPONSE
  end

  def successful_update_intent_response
    <<-RESPONSE
      {"id":"pi_1F1yBbAWOtgoysog52J88BuO","object":"payment_intent","amount":2050,"amount_capturable":0,"amount_received":0,"application":null,"application_fee_amount":null,"canceled_at":null,"cancellation_reason":null,"capture_method":"manual","charges":{"object":"list","data":[],"has_more":false,"total_count":0,"url":"/v1/charges?payment_intent=pi_1F1yBbAWOtgoysog52J88BuO"},"client_secret":"pi_1F1yBbAWOtgoysog52J88BuO_secret_olw5rmbtm7cd72S9JfbKjTJJv","confirmation_method":"manual","created":1564504107,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"invoice":null,"last_payment_error":null,"livemode":false,"metadata":{},"next_action":null,"on_behalf_of":null,"payment_method":"pm_1F1yBbAWOtgoysoguJQsDdYj","payment_method_options":{"card":{"request_three_d_secure":"automatic"}},"payment_method_types":["card"],"receipt_email":null,"review":null,"setup_future_usage":null,"shipping":null,"source":null,"statement_descriptor":null,"status":"requires_confirmation","transfer_data":null,"transfer_group":null}
    RESPONSE
  end

  def successful_create_3ds2_payment_method
    <<-RESPONSE
      {
        "id": "pm_1F1xK0AWOtgoysogfPuRKN1d",
        "object": "payment_method",
        "billing_details": {
          "address": {"city": null,
            "country": null,
            "line1": null,
            "line2": null,
            "postal_code": null,
            "state": null},
          "email": null,
          "name": null,
          "phone": null},
        "card": {
          "brand": "visa",
          "checks": {"address_line1_check": null,
            "address_postal_code_check": null,
            "cvc_check": "unchecked"},
          "country": null,
          "exp_month": 10,
          "exp_year": 2020,
          "fingerprint": "l3J0NJaGgv0jAGLV",
          "funding": "credit",
          "generated_from": null,
          "last4": "3220",
          "three_d_secure_usage": {"supported": true},
          "wallet": null},
        "created": 1564500784,
        "customer": null,
        "livemode": false,
        "metadata": {},
        "type": "card"
      }
    RESPONSE
  end

  def successful_create_3ds2_intent_response
    <<-RESPONSE
      {
        "id": "pi_1F1wpFAWOtgoysog8nTulYGk",
        "object": "payment_intent",
        "amount": 2020,
        "amount_capturable": 0,
        "amount_received": 0,
        "application": null,
        "application_fee_amount": null,
        "canceled_at": null,
        "cancellation_reason": null,
        "capture_method": "manual",
        "charges": {
          "object": "list",
          "data": [],
          "has_more": false,
          "total_count": 0,
          "url": "/v1/charges?payment_intent=pi_1F1wpFAWOtgoysog8nTulYGk"
          },
        "client_secret": "pi_1F1wpFAWOtgoysog8nTulYGk_secret_75qf7rjBDsTTz279LfS1feXUj",
        "confirmation_method": "manual",
        "created": 1564498877,
        "currency": "gbp",
        "customer": "cus_7s22nNueP2Hjj6",
        "description": null,
        "invoice": null,
        "last_payment_error": null,
        "livemode": false,
        "metadata": {},
        "next_action": null,
        "on_behalf_of": null,
        "payment_method": "pm_1F1wpFAWOtgoysogJ8zQ8K07",
        "payment_method_options": {
          "card": {"request_three_d_secure": "automatic"}
          },
        "payment_method_types": ["card"],
        "receipt_email": null,
        "review": null,
        "setup_future_usage": null,
        "shipping": null,
        "source": null,
        "statement_descriptor": null,
        "status": "requires_confirmation",
        "transfer_data": null,
        "transfer_group": null
      }
    RESPONSE
  end

  def successful_confirm_3ds2_intent_response
    <<-RESPONSE
      {
        "id": "pi_1F1wpFAWOtgoysog8nTulYGk",
        "object": "payment_intent",
        "amount": 2020,
        "amount_capturable": 0,
        "amount_received": 0,
        "application": null,
        "application_fee_amount": null,
        "canceled_at": null,
        "cancellation_reason": null,
        "capture_method": "manual",
        "charges": {
          "object": "list",
          "data": [],
          "has_more": false,
          "total_count": 0,
          "url": "/v1/charges?payment_intent=pi_1F1wpFAWOtgoysog8nTulYGk"},
          "client_secret": "pi_1F1wpFAWOtgoysog8nTulYGk_secret_75qf7rjBDsTTz279LfS1feXUj",
          "confirmation_method": "manual",
          "created": 1564498877,
          "currency": "gbp",
          "customer": "cus_7s22nNueP2Hjj6",
          "description": null,
          "invoice": null,
          "last_payment_error": null,
          "livemode": false,
          "metadata": {},
          "next_action": {
            "redirect_to_url": {
              "return_url": "https://example.com/return-to-me",
              "url": "https://hooks.stripe.com/3d_secure_2_eap/begin_test/src_1F1wpGAWOtgoysog4f00umCp/src_client_secret_FX0qk3uQ04woFWgdJbN3pnHD"},
            "type": "redirect_to_url"},
          "on_behalf_of": null,
          "payment_method": "pm_1F1wpFAWOtgoysogJ8zQ8K07",
          "payment_method_options": {
            "card": {"request_three_d_secure": "automatic"}
            },
          "payment_method_types": ["card"],
          "receipt_email": null,
          "review": null,
          "setup_future_usage": null,
          "shipping": null,
          "source": null,
          "statement_descriptor": null,
          "status": "requires_action",
          "transfer_data": null,
          "transfer_group": null
        }
    RESPONSE
  end

  def successful_request_three_d_secure_response
    <<-RESPONSE
    {"id"=>"pi_1HZJGPAWOtgoysogrKURP11Q",
      "object"=>"payment_intent",
      "amount"=>2000,
      "amount_capturable"=>0,
      "amount_received"=>2000,
      "application"=>nil,
      "application_fee_amount"=>nil,
      "canceled_at"=>nil,
      "cancellation_reason"=>nil,
      "capture_method"=>"automatic",
      "charges"=>
       {"object"=>"list",
        "data"=>
         [{"id"=>"ch_1HZJGQAWOtgoysogEpbZTGIl",
           "object"=>"charge",
           "amount"=>2000,
           "amount_captured"=>2000,
           "amount_refunded"=>0,
           "application"=>nil,
           "application_fee"=>nil,
           "application_fee_amount"=>nil,
           "balance_transaction"=>"txn_1HZJGQAWOtgoysogEKwV2r5N",
           "billing_details"=>
            {"address"=>{"city"=>nil, "country"=>nil, "line1"=>nil, "line2"=>nil, "postal_code"=>nil, "state"=>nil}, "email"=>nil, "name"=>nil, "phone"=>nil},
           "calculated_statement_descriptor"=>"SPREEDLY",
           "captured"=>true,
           "created"=>1602002626,
           "currency"=>"gbp",
           "customer"=>nil,
           "description"=>nil,
           "destination"=>nil,
           "dispute"=>nil,
           "disputed"=>false,
           "failure_code"=>nil,
           "failure_message"=>nil,
           "fraud_details"=>{},
           "invoice"=>nil,
           "livemode"=>false,
           "metadata"=>{},
           "on_behalf_of"=>nil,
           "order"=>nil,
           "outcome"=>
            {"network_status"=>"approved_by_network",
             "reason"=>nil,
             "risk_level"=>"normal",
             "risk_score"=>16,
             "seller_message"=>"Payment complete.",
             "type"=>"authorized"},
           "paid"=>true,
           "payment_intent"=>"pi_1HZJGPAWOtgoysogrKURP11Q",
           "payment_method"=>"pm_1HZJGOAWOtgoysogvnMsnnG1",
           "payment_method_details"=>
            {"card"=>
              {"brand"=>"visa",
               "checks"=>{"address_line1_check"=>nil, "address_postal_code_check"=>nil, "cvc_check"=>"pass"},
               "country"=>"US",
               "ds_transaction_id"=>nil,
               "exp_month"=>10,
               "exp_year"=>2020,
               "fingerprint"=>"hfaVNMiXc0dYSiC5",
               "funding"=>"credit",
               "installments"=>nil,
               "last4"=>"4242",
               "moto"=>nil,
               "network"=>"visa",
               "network_transaction_id"=>"1041029786787710",
               "three_d_secure"=>
                {"authenticated"=>false,
                 "authentication_flow"=>nil,
                 "electronic_commerce_indicator"=>"06",
                 "result"=>"attempt_acknowledged",
                 "result_reason"=>nil,
                 "succeeded"=>true,
                 "transaction_id"=>"d1VlRVF6a1BVNXN1cjMzZVl0RU0=",
                 "version"=>"1.0.2"},
               "wallet"=>nil},
             "type"=>"card"},
           "receipt_email"=>nil,
           "receipt_number"=>nil,
           "receipt_url"=>"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_1HZJGQAWOtgoysogEpbZTGIl/rcpt_I9cVpN9xAeS39FhMqTS33Fj8gHsjjuX",
           "refunded"=>false,
           "refunds"=>{"object"=>"list", "data"=>[], "has_more"=>false, "total_count"=>0, "url"=>"/v1/charges/ch_1HZJGQAWOtgoysogEpbZTGIl/refunds"},
           "review"=>nil,
           "shipping"=>nil,
           "source"=>nil,
           "source_transfer"=>nil,
           "statement_descriptor"=>nil,
           "statement_descriptor_suffix"=>nil,
           "status"=>"succeeded",
           "transfer_data"=>nil,
           "transfer_group"=>nil}],
        "has_more"=>false,
        "total_count"=>1,
        "url"=>"/v1/charges?payment_intent=pi_1HZJGPAWOtgoysogrKURP11Q"},
      "client_secret"=>"pi_1HZJGPAWOtgoysogrKURP11Q_secret_dJNY00dYXC22Fc9nPscAmhFMt",
      "confirmation_method"=>"automatic",
      "created"=>1602002625,
      "currency"=>"gbp",
      "customer"=>nil,
      "description"=>nil,
      "invoice"=>nil,
      "last_payment_error"=>nil,
      "livemode"=>false,
      "metadata"=>{},
      "next_action"=>nil,
      "on_behalf_of"=>nil,
      "payment_method"=>"pm_1HZJGOAWOtgoysogvnMsnnG1",
      "payment_method_options"=>{"card"=>{"installments"=>nil, "network"=>nil, "request_three_d_secure"=>"any"}},
      "payment_method_types"=>["card"],
      "receipt_email"=>nil,
      "review"=>nil,
      "setup_future_usage"=>nil,
      "shipping"=>nil,
      "source"=>nil,
      "statement_descriptor"=>nil,
      "statement_descriptor_suffix"=>nil,
      "status"=>"succeeded",
      "transfer_data"=>nil,
      "transfer_group"=>nil
      }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
      {"error":{"charge":"ch_1F2MB6AWOtgoysogAIvNV32Z","code":"card_declined","decline_code":"generic_decline","doc_url":"https://stripe.com/docs/error-codes/card-declined","message":"Your card was declined.","payment_intent":{"id":"pi_1F2MB5AWOtgoysogCMt8BaxR","object":"payment_intent","amount":2020,"amount_capturable":0,"amount_received":0,"application":null,"application_fee_amount":null,"canceled_at":null,"cancellation_reason":null,"capture_method":"automatic","charges":{"object":"list","data":[{"id":"ch_1F2MB6AWOtgoysogAIvNV32Z","object":"charge","amount":2020,"amount_refunded":0,"application":null,"application_fee":null,"application_fee_amount":null,"balance_transaction":null,"billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"captured":false,"created":1564596332,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"destination":null,"dispute":null,"failure_code":"card_declined","failure_message":"Your card was declined.","fraud_details":{},"invoice":null,"livemode":false,"metadata":{},"on_behalf_of":null,"order":null,"outcome":{"network_status":"declined_by_network","reason":"generic_decline","risk_level":"normal","risk_score":41,"seller_message":"The bank did not return any further details with this decline.","type":"issuer_declined"},"paid":false,"payment_intent":"pi_1F2MB5AWOtgoysogCMt8BaxR","payment_method":"pm_1F2MB5AWOtgoysogq3yXZ98h","payment_method_details":{"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"1VUoWMvHnqtngyrD","funding":"credit","last4":"0002","three_d_secure":null,"wallet":null},"type":"card"},"receipt_email":null,"receipt_number":null,"receipt_url":"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_1F2MB6AWOtgoysogAIvNV32Z/rcpt_FXR3PjBGluHmHsnLmp0S2KQiHl3yg6W","refunded":false,"refunds":{"object":"list","data":[],"has_more":false,"total_count":0,"url":"/v1/charges/ch_1F2MB6AWOtgoysogAIvNV32Z/refunds"},"review":null,"shipping":null,"source":null,"source_transfer":null,"statement_descriptor":null,"status":"failed","transfer_data":null,"transfer_group":null}],"has_more":false,"total_count":1,"url":"/v1/charges?payment_intent=pi_1F2MB5AWOtgoysogCMt8BaxR"},"client_secret":"pi_1F2MB5AWOtgoysogCMt8BaxR_secret_fOHryjtjBE4gACiHTcREraXSQ","confirmation_method":"manual","created":1564596331,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"invoice":null,"last_payment_error":{"charge":"ch_1F2MB6AWOtgoysogAIvNV32Z","code":"card_declined","decline_code":"generic_decline","doc_url":"https://stripe.com/docs/error-codes/card-declined","message":"Your card was declined.","payment_method":{"id":"pm_1F2MB5AWOtgoysogq3yXZ98h","object":"payment_method","billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"1VUoWMvHnqtngyrD","funding":"credit","generated_from":null,"last4":"0002","three_d_secure_usage":{"supported":true},"wallet":null},"created":1564596331,"customer":null,"livemode":false,"metadata":{},"type":"card"},"type":"card_error"},"livemode":false,"metadata":{},"next_action":null,"on_behalf_of":null,"payment_method":null,"payment_method_options":{"card":{"request_three_d_secure":"automatic"}},"payment_method_types":["card"],"receipt_email":null,"review":null,"setup_future_usage":null,"shipping":null,"source":null,"statement_descriptor":null,"status":"requires_payment_method","transfer_data":null,"transfer_group":null},"payment_method":{"id":"pm_1F2MB5AWOtgoysogq3yXZ98h","object":"payment_method","billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"1VUoWMvHnqtngyrD","funding":"credit","generated_from":null,"last4":"0002","three_d_secure_usage":{"supported":true},"wallet":null},"created":1564596331,"customer":null,"livemode":false,"metadata":{},"type":"card"},"type":"card_error"}}
    RESPONSE
  end

  def failed_cancel_response
    <<-RESPONSE
      {"error":{"code":"payment_intent_unexpected_state","doc_url":"https://stripe.com/docs/error-codes/payment-intent-unexpected-state","message":"You cannot cancel this PaymentIntent because it has a status of succeeded. Only a PaymentIntent with one of the following statuses may be canceled: requires_payment_method, requires_capture, requires_confirmation, requires_action.","payment_intent":{"id":"pi_1F2McmAWOtgoysoglFLDRWab","object":"payment_intent","amount":2020,"amount_capturable":0,"amount_received":2020,"application":null,"application_fee_amount":null,"canceled_at":null,"cancellation_reason":null,"capture_method":"automatic","charges":{"object":"list","data":[{"id":"ch_1F2McmAWOtgoysogQgUS1YtH","object":"charge","amount":2020,"amount_refunded":0,"application":null,"application_fee":null,"application_fee_amount":null,"balance_transaction":"txn_1F2McmAWOtgoysog8uxBEJ30","billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"captured":true,"created":1564598048,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"destination":null,"dispute":null,"failure_code":null,"failure_message":null,"fraud_details":{},"invoice":null,"livemode":false,"metadata":{},"on_behalf_of":null,"order":null,"outcome":{"network_status":"approved_by_network","reason":null,"risk_level":"normal","risk_score":53,"seller_message":"Payment complete.","type":"authorized"},"paid":true,"payment_intent":"pi_1F2McmAWOtgoysoglFLDRWab","payment_method":"pm_1F2MclAWOtgoysogq80GBBMO","payment_method_details":{"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"hfaVNMiXc0dYSiC5","funding":"credit","last4":"4242","three_d_secure":null,"wallet":null},"type":"card"},"receipt_email":null,"receipt_number":null,"receipt_url":"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_1F2McmAWOtgoysogQgUS1YtH/rcpt_FXRVzyFnf7aCS1r13N3uym1u8AaboOJ","refunded":false,"refunds":{"object":"list","data":[],"has_more":false,"total_count":0,"url":"/v1/charges/ch_1F2McmAWOtgoysogQgUS1YtH/refunds"},"review":null,"shipping":null,"source":null,"source_transfer":null,"statement_descriptor":null,"status":"succeeded","transfer_data":null,"transfer_group":null}],"has_more":false,"total_count":1,"url":"/v1/charges?payment_intent=pi_1F2McmAWOtgoysoglFLDRWab"},"client_secret":"pi_1F2McmAWOtgoysoglFLDRWab_secret_z4faDF0Cv0JZJ6pxK3bdIodkD","confirmation_method":"manual","created":1564598048,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"invoice":null,"last_payment_error":null,"livemode":false,"metadata":{},"next_action":null,"on_behalf_of":null,"payment_method":"pm_1F2MclAWOtgoysogq80GBBMO","payment_method_options":{"card":{"request_three_d_secure":"automatic"}},"payment_method_types":["card"],"receipt_email":null,"review":null,"setup_future_usage":null,"shipping":null,"source":null,"statement_descriptor":null,"status":"succeeded","transfer_data":null,"transfer_group":null},"type":"invalid_request_error"}}
    RESPONSE
  end

  def failed_payment_method_response
    <<-RESPONSE
      {"error": {"code": "validation_error", "message": "You must verify a phone number on your Stripe account before you can send raw credit card numbers to the Stripe API. You can avoid this requirement by using Stripe.js, the Stripe mobile bindings, or Stripe Checkout. For more information, see https://dashboard.stripe.com/phone-verification.", "type": "invalid_request_error"}}
    RESPONSE
  end

  def failed_service_response
    <<-RESPONSE
      {"error": {"message": "Error while communicating with one of our backends.  Sorry about that!  We have been notified of the problem.  If you have any questions, we can help at https://support.stripe.com/.", "type": "api_error"  }}
    RESPONSE
  end

  def successful_verify_response
    <<-RESPONSE
      {
        "id": "seti_1Gsw0aAWOtgoysog0XjSBPVX",
        "object": "setup_intent",
        "application": null,
        "cancellation_reason": null,
        "client_secret": "seti_1Gsw0aAWOtgoysog0XjSBPVX_secret_HRpfHkvewAdYQJgee27ihJfm4E4zWmW",
        "created": 1591903456,
        "customer": "cus_GkjsDZC58SgUcY",
        "description": null,
        "last_setup_error": null,
        "livemode": false,
        "mandate": null,
        "metadata": {
        },
        "next_action": null,
        "on_behalf_of": null,
        "payment_method": "pm_1Gsw0aAWOtgoysog304wX4J9",
        "payment_method_options": {
          "card": {
            "request_three_d_secure": "automatic"
          }
        },
        "payment_method_types": [
          "card"
        ],
        "single_use_mandate": null,
        "status": "succeeded",
        "usage": "off_session"
      }
    RESPONSE
  end
end
