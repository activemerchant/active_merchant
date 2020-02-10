require 'test_helper'

class StripePaymentIntentsTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = StripePaymentIntentsGateway.new(:login => 'login')

    @credit_card = credit_card()
    @threeds_2_card = credit_card('4000000000003220')
    @visa_token = 'pm_card_visa'
    @amount = 2020
    @update_amount = 2050

    @options = {
      currency: 'GBP',
      confirmation_method: 'manual',
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

  def test_successful_create_and_void_intent
    @gateway.expects(:ssl_request).twice.returns(successful_create_intent_response, successful_void_response)
    assert create = @gateway.create_intent(@amount, @visa_token, @options.merge(capture_method: 'manual', confirm: true))

    assert cancel = @gateway.void(create.params['id'])
    assert_equal @amount, cancel.params.dig('charges', 'data')[0].dig('amount_refunded')
    assert_equal 'canceled', cancel.params['status']
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
end
