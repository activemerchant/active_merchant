require 'test_helper'

class CheckoutV2Test < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CheckoutV2Gateway.new(
      secret_key: '1111111111111'
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'pay_fj3xswqe3emuxckocjx6td73ni', response.authorization
    assert response.test?
  end

  def test_successful_purchase_includes_avs_result
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_equal 'S', response.avs_result['code']
    assert_equal 'U.S.-issuing bank does not support AVS.', response.avs_result['message']
    assert_equal 'X', response.avs_result['postal_match']
    assert_equal 'X', response.avs_result['street_match']
  end

  def test_successful_purchase_includes_cvv_result
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_equal 'Y', response.cvv_result['code']
  end

  def test_successful_authorize_includes_avs_result
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_equal 'S', response.avs_result['code']
    assert_equal 'U.S.-issuing bank does not support AVS.', response.avs_result['message']
    assert_equal 'X', response.avs_result['postal_match']
    assert_equal 'X', response.avs_result['street_match']
  end

  def test_successful_authorize_includes_cvv_result
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_equal 'Y', response.cvv_result['code']
  end

  def test_purchase_with_additional_fields
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, {descriptor_city: 'london', descriptor_name: 'sherlock'})
    end.check_request do |endpoint, data, headers|
      assert_match(/"billing_descriptor\":{\"name\":\"sherlock\",\"city\":\"london\"}/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'pay_fj3xswqe3emuxckocjx6td73ni', response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_successful_authorize_and_capture_with_additional_options
    response = stub_comms do
      options = {
        card_on_file: true,
        transaction_indicator: 2,
        previous_charge_id: 'pay_123'
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{"stored":"true"}, data)
      assert_match(%r{"payment_type":"Recurring"}, data)
      assert_match(%r{"previous_payment_id":"pay_123"}, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'pay_fj3xswqe3emuxckocjx6td73ni', response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_moto_transaction_is_properly_set
    response = stub_comms do
      options = {
        metadata: { manual_entry: true}
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{"payment_type":"MOTO"}, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_3ds_passed
    response = stub_comms do
      options = {
        execute_threed: true,
        callback_url: 'https://www.example.com'
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{"success_url"}, data)
      assert_match(%r{"failure_url"}, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_successful_verify_payment
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify_payment('testValue')
    end.respond_with(successful_verify_payment_response)

    assert_success response
  end

  def test_failed_verify_payment
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify_payment('testValue')
    end.respond_with(failed_verify_payment_response)

    assert_failure response
  end

  def test_successful_authorize_and_capture_with_3ds
    response = stub_comms do
      options = {
        execute_threed: true,
        three_d_secure: {
          version: '1.0.2',
          eci: '05',
          cryptogram: '1234',
          xid: '1234'
        }
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'pay_fj3xswqe3emuxckocjx6td73ni', response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_successful_authorize_and_capture_with_3ds2
    response = stub_comms do
      options = {
        execute_threed: true,
        three_d_secure: {
          version: '2.0.0',
          eci: '05',
          cryptogram: '1234',
          ds_transaction_id: '1234'
        }
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'pay_fj3xswqe3emuxckocjx6td73ni', response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal 'Invalid Card Number', response.message
    assert response.test?
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(100, '')
    end.respond_with(failed_capture_response)

    assert_failure response
  end

  def test_successful_void
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'pay_fj3xswqe3emuxckocjx6td73ni', response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void('5d53a33d960c46d00f5dc061947d998c')
    end.respond_with(failed_void_response)

    assert_failure response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'pay_fj3xswqe3emuxckocjx6td73ni', response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, '')
    end.respond_with(failed_refund_response)

    assert_failure response
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal 'Invalid Card Number', response.message
  end

  def test_transcript_scrubbing
    assert_equal post_scrubbed, @gateway.scrub(pre_scrubbed)
  end

  def test_invalid_json
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(invalid_json_response)

    assert_failure response
    assert_match %r{Unable to read error message}, response.message
  end

  def test_error_code_returned
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(error_code_response)

    assert_failure response
    assert_match(/request_invalid: card_expired/, response.error_code)
  end

  def test_supported_countries
    assert_equal ['AD', 'AE', 'AR', 'AT', 'AU', 'BE', 'BG', 'BH', 'BR', 'CH', 'CL', 'CN', 'CO', 'CY', 'CZ', 'DE', 'DK', 'EE', 'EG', 'ES', 'FI', 'FR', 'GB', 'GR', 'HK', 'HR', 'HU', 'IE', 'IS', 'IT', 'JO', 'JP', 'KW', 'LI', 'LT', 'LU', 'LV', 'MC', 'MT', 'MX', 'MY', 'NL', 'NO', 'NZ', 'OM', 'PE', 'PL', 'PT', 'QA', 'RO', 'SA', 'SE', 'SG', 'SI', 'SK', 'SM', 'TR', 'US'], @gateway.supported_countries
  end

  private

  def pre_scrubbed
    %q(
      <- "POST /payments HTTP/1.1\r\nContent-Type: application/json;charset=UTF-8\r\nAuthorization: sk_test_ab12301d-e432-4ea7-97d1-569809518aaf\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.checkout.com\r\nContent-Length: 346\r\n\r\n"
      <- "{\"capture\":false,\"amount\":\"200\",\"reference\":\"1\",\"currency\":\"USD\",\"source\":{\"type\":\"card\",\"name\":\"Longbob Longsen\",\"number\":\"4242424242424242\",\"cvv\":\"100\",\"expiry_year\":\"2025\"
    )
  end

  def post_scrubbed
    %q(
      <- "POST /payments HTTP/1.1\r\nContent-Type: application/json;charset=UTF-8\r\nAuthorization: [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.checkout.com\r\nContent-Length: 346\r\n\r\n"
      <- "{\"capture\":false,\"amount\":\"200\",\"reference\":\"1\",\"currency\":\"USD\",\"source\":{\"type\":\"card\",\"name\":\"Longbob Longsen\",\"number\":\"[FILTERED]\",\"cvv\":\"[FILTERED]\",\"expiry_year\":\"2025\"
    )
  end

  def successful_purchase_response
    %(
     {
       "id":"pay_fj3xswqe3emuxckocjx6td73ni",
       "amount":200,
       "currency":"USD",
       "reference":"1",
       "response_summary": "Approved",
       "response_code":"10000",
       "customer": {
        "id": "cus_zvnv7gsblfjuxppycd7bx4erue",
        "email": "longbob.longsen@example.com",
        "name": "Sarah Mitchell"
       },
       "source": {
         "cvv_check":"Y",
         "avs_check":"S"
       }
      }
    )
  end

  def failed_purchase_response
    %(
     {
       "id":"pay_awjzhfj776gulbp2nuslj4agbu",
       "amount":200,
       "currency":"USD",
       "reference":"1",
       "response_summary": "Invalid Card Number",
       "response_code":"20014",
       "customer": {
        "id": "cus_zvnv7gsblfjuxppycd7bx4erue",
        "email": "longbob.longsen@example.com",
        "name": "Sarah Mitchell"
       },
       "source": {
         "cvvCheck":"Y",
         "avsCheck":"S"
       }
      }
    )
  end

  def successful_authorize_response
    %(
    {
      "id": "pay_fj3xswqe3emuxckocjx6td73ni",
      "action_id": "act_fj3xswqe3emuxckocjx6td73ni",
      "amount": 200,
      "currency": "USD",
      "approved": true,
      "status": "Authorized",
      "auth_code": "858188",
      "eci": "05",
      "scheme_id": "638284745624527",
      "response_code": "10000",
      "response_summary": "Approved",
      "risk": {
        "flagged": false
      },
      "source": {
        "id": "src_nq6m5dqvxmsunhtzf7adymbq3i",
        "type": "card",
        "expiry_month": 8,
        "expiry_year": 2025,
        "name": "Sarah Mitchell",
        "scheme": "Visa",
        "last4": "4242",
        "fingerprint": "5CD3B9CB15338683110959D165562D23084E1FF564F420FE9A990DF0BCD093FC",
        "bin": "424242",
        "card_type": "Credit",
        "card_category": "Consumer",
        "issuer": "JPMORGAN CHASE BANK NA",
        "issuer_country": "US",
        "product_id": "A",
        "product_type": "Visa Traditional",
        "avs_check": "S",
        "cvv_check": "Y"
      },
      "customer": {
        "id": "cus_ssxcidkqvfde7lfn5n7xzmgv2a",
        "email": "longbob.longsen@example.com",
        "name": "Sarah Mitchell"
      },
      "processed_on": "2019-03-24T10:14:32Z",
      "reference": "ORD-5023-4E89",
      "_links": {
        "self": {
          "href": "https://api.sandbox.checkout.com/payments/pay_fj3xswqe3emuxckocjx6td73ni"
        },
        "actions": {
          "href": "https://api.sandbox.checkout.com/payments/pay_fj3xswqe3emuxckocjx6td73ni/actions"
        },
        "capture": {
          "href": "https://api.sandbox.checkout.com/payments/pay_fj3xswqe3emuxckocjx6td73ni/captures"
        },
        "void": {
          "href": "https://api.sandbox.checkout.com/payments/pay_fj3xswqe3emuxckocjx6td73ni/voids"
        }
      }
    }
  )
  end

  def failed_authorize_response
    %(
     {
       "id":"pay_awjzhfj776gulbp2nuslj4agbu",
       "amount":200,
       "currency":"USD",
       "reference":"1",
       "customer": {
        "id": "cus_zvnv7gsblfjuxppycd7bx4erue",
        "email": "longbob.longsen@example.com",
        "name": "Sarah Mitchell"
       },
       "response_summary": "Invalid Card Number",
       "response_code":"20014"
      }
    )
  end

  def successful_capture_response
    %(
    {
     "action_id": "act_2f56bhkau5dubequbv5aa6w4qi",
     "reference": "1"
    }
    )
  end

  def failed_capture_response
    %(
    )
  end

  def successful_refund_response
    %(
    {
     "action_id": "act_2f56bhkau5dubequbv5aa6w4qi",
     "reference": "1"
    }
    )
  end

  def failed_refund_response
    %(
    )
  end

  def successful_void_response
    %(
    {
     "action_id": "act_2f56bhkau5dubequbv5aa6w4qi",
     "reference": "1"
    }
    )
  end

  def failed_void_response
    %(
    )
  end

  def invalid_json_response
    %(
    {
      "id": "pay_123",
    )
  end

  def error_code_response
    %(
      {
        "request_id": "e5a3ce6f-a4e9-4445-9ec7-e5975e9a6213","error_type": "request_invalid","error_codes": ["card_expired"]
      }
    )
  end

  def successful_verify_payment_response
    %(
      {"id":"pay_tkvif5mf54eerhd3ysuawfcnt4","requested_on":"2019-08-14T18:13:54Z","source":{"id":"src_lot2ch4ygk3ehi4fugxmk7r2di","type":"card","expiry_month":12,"expiry_year":2020,"name":"Jane Doe","scheme":"Visa","last4":"0907","fingerprint":"E4048195442B0059D73FD47F6E1961A02CD085B0B34B7703CE4A93750DB5A0A1","bin":"457382","avs_check":"S","cvv_check":"Y"},"amount":100,"currency":"USD","payment_type":"Regular","reference":"Dvy8EMaEphrMWolKsLVHcUqPsyx","status":"Authorized","approved":true,"3ds":{"downgraded":false,"enrolled":"Y","authentication_response":"Y","cryptogram":"ce49b5c1-5d3c-4864-bd16-2a8c","xid":"95202312-f034-48b4-b9b2-54254a2b49fb","version":"2.1.0"},"risk":{"flagged":false},"customer":{"id":"cus_zt5pspdtkypuvifj7g6roy7p6y","name":"Jane Doe"},"billing_descriptor":{"name":"","city":"London"},"payment_ip":"127.0.0.1","metadata":{"Udf5":"ActiveMerchant"},"eci":"05","scheme_id":"638284745624527","actions":[{"id":"act_tkvif5mf54eerhd3ysuawfcnt4","type":"Authorization","response_code":"10000","response_summary":"Approved"}],"_links":{"self":{"href":"https://api.sandbox.checkout.com/payments/pay_tkvif5mf54eerhd3ysuawfcnt4"},"actions":{"href":"https://api.sandbox.checkout.com/payments/pay_tkvif5mf54eerhd3ysuawfcnt4/actions"},"capture":{"href":"https://api.sandbox.checkout.com/payments/pay_tkvif5mf54eerhd3ysuawfcnt4/captures"},"void":{"href":"https://api.sandbox.checkout.com/payments/pay_tkvif5mf54eerhd3ysuawfcnt4/voids"}}}
    )
  end

  def failed_verify_payment_response
    %(
      {"id":"pay_xrwmaqlar73uhjtyoghc7bspa4","requested_on":"2019-08-14T18:32:50Z","source":{"type":"card","expiry_month":12,"expiry_year":2020,"name":"Jane Doe","scheme":"Visa","last4":"7863","fingerprint":"DC20145B78E242C561A892B83CB64471729D7A5063E5A5B341035713B8FDEC92","bin":"453962"},"amount":100,"currency":"USD","payment_type":"Regular","reference":"EuyOZtgt8KI4tolEH8lqxCclWqz","status":"Declined","approved":false,"3ds":{"downgraded":false,"enrolled":"Y","version":"2.1.0"},"risk":{"flagged":false},"customer":{"id":"cus_bb4b7eu35sde7o33fq2xchv7oq","name":"Jane Doe"},"payment_ip":"127.0.0.1","metadata":{"Udf5":"ActiveMerchant"},"_links":{"self":{"href":"https://api.sandbox.checkout.com/payments/pay_xrwmaqlar73uhjtyoghc7bspa4"},"actions":{"href":"https://api.sandbox.checkout.com/payments/pay_xrwmaqlar73uhjtyoghc7bspa4/actions"}}}
    )
  end
end
