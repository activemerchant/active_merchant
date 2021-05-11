require "test_helper"

class SquareNewTest < Test::Unit::TestCase
  def setup
    @gateway = SquareNewGateway.new(access_token: "token")

    @amount = 200
    @refund_amount = 100

    @card_nonce = "cnon:card-nonce-ok"
    @declined_card_nonce = "cnon:card-nonce-declined"

    @options = {
      email: "customer@example.com",
      billing_address: address
    }
  end

  def test_successful_purchase
    @gateway.expects(:sdk_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @card_nonce, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal "DzDT7uzlKeWvWdjnFw9JvGqfCu5YY", response.authorization
    assert_equal "COMPLETED", response.params["payment"]["status"]
    assert response.test?
  end

  def test_successful_purchase_with_descriptor
    @gateway.expects(:sdk_request).returns(successful_purchase_response_with_descriptor)

    assert response = @gateway.purchase(@amount, @card_nonce, @options.merge(descriptor: "trial end"))
    assert_instance_of Response, response
    assert_success response

    assert_match /trial end$/, response.params["payment"]["statement_description_identifier"]
  end

  def test_unsuccessful_purchase
    @gateway.expects(:sdk_request).returns(unsuccessful_purchase_response)

    assert response = @gateway.purchase(@amount, @card_nonce, @options)
    assert_instance_of Response, response
    assert_failure response

    assert_equal nil, response.authorization
    assert_equal "FAILED", response.params["payment"]["status"]
    assert response.test?
  end

  def test_successful_purchase_then_refund
    @gateway.expects(:sdk_request).returns(successful_refund_response)

    assert response = @gateway.refund(@refund_amount, "DzDT7uzlKeWvWdjnFw9JvGqfCu5YY", @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal "16Kzd7LeQ5VzxPxSBcVUhGuWMRcZY_fg8fsD4nzAsFCnHQ1JIqIYCGb0iWTqLG9Lifyo6DGYb", response.authorization
    assert_equal "PENDING", response.params["refund"]["status"]
    assert_equal @refund_amount, response.params["refund"]["amount_money"]["amount"]
    assert response.test?
  end

  def test_successful_store
    @gateway.expects(:sdk_request).twice.returns(successful_new_customer_response, successful_new_card_response)

    @options[:idempotency_key] = SecureRandom.hex(10)

    assert response = @gateway.store(@card_nonce, @options)

    assert_instance_of MultiResponse, response
    assert_success response
    assert_equal 2, response.responses.size

    customer_response = response.responses[0]
    assert_not_nil customer_response.params["customer"]["id"]

    card_response = response.responses[1]
    assert_not_nil card_response.params["card"]["id"]

    assert response.test?
  end

  def test_successful_store_then_update
    @gateway.expects(:sdk_request).returns(successful_update_response)

    @options[:billing_address][:name] = "Tom Smith"
    assert response = @gateway.update_customer("ZQ3CCPG9SRTB9C7V2NG27JWME4", @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal "ZQ3CCPG9SRTB9C7V2NG27JWME4", response.authorization
    assert_equal "Tom", response.params["customer"]["given_name"]
    assert_equal "Smith", response.params["customer"]["family_name"]
    assert response.test?
  end

  private

  def successful_purchase_response
    { "payment" =>
      { "id" => "DzDT7uzlKeWvWdjnFw9JvGqfCu5YY",
        "amount_money" => { "amount" => 200, "currency" => "USD" },
        "status" => "COMPLETED",
        "source_type" => "CARD",
        "card_details" =>
        { "status" => "CAPTURED",
          "card" =>
          { "card_brand" => "VISA",
            "last_4" => "5858",
            "exp_month" => 3,
            "exp_year" => 2023,
            "fingerprint" => "sq-1-OGa7YtmxnU-KUTqGUhFupot9pF3BbIoXX3A4rCJUf6dyRbPWZSpPdn8cvD5hogdl6A",
            "card_type" => "DEBIT",
            "prepaid_type" => "NOT_PREPAID",
            "bin" => "453275" },
          "entry_method" => "KEYED",
          "cvv_status" => "CVV_ACCEPTED",
          "avs_status" => "AVS_ACCEPTED",
          "statement_description" => "SQ *DEFAULT TEST ACCOUNT" },
        "location_id" => "2VTFVYA3M00KE",
        "order_id" => "SWLKCTIwrcJyAHytsTqazMbb7UdZY",
        "risk_evaluation" => { "risk_level" => "NORMAL" },
        "total_money" => { "amount" => 200, "currency" => "USD" },
        "approved_money" => { "amount" => 200, "currency" => "USD" },
        "receipt_number" => "DzDT",
        "receipt_url" => "https://squareupsandbox.com/receipt/preview/DzDT7uzlKeWvWdjnFw9JvGqfCu5YY",
        "delay_action" => "CANCEL",
        "delayed_until" => "2021-04-06T10:24:29.166Z",
        "version_token" => "WUv6LTInrxHPtceqM6iNH6etE2f65iEPjrQLfusda0M6o" } }
  end

  def successful_purchase_response_with_descriptor
    successful_purchase_response.merge(
      { "payment" => { "statement_description_identifier" => "trial end" } }
    )
  end

  def unsuccessful_purchase_response
    { "errors" => [{ "code" => "GENERIC_DECLINE",
                     "detail" => "Authorization error: 'GENERIC_DECLINE'",
                     "category" => "PAYMENT_METHOD_ERROR" }],
      "payment" =>
  { "id" => "L1QyP8sCp1H4jHEVvWpkCeSCIePZY",
    "amount_money" => { "amount" => 200, "currency" => "USD" },
    "status" => "FAILED",
    "delay_duration" => "PT168H",
    "source_type" => "CARD",
    "card_details" =>
    { "status" => "FAILED",
      "card" =>
      { "card_brand" => "VISA",
        "last_4" => "0002",
        "exp_month" => 3,
        "exp_year" => 2023,
        "fingerprint" => "sq-1-Sa2z1_wkyw1M3qaaavLvCKT-KXK_YoHKQ07X9bv3UH1afJF54hcThDZ8mKzKzosPvw",
        "bin" => "400000" },
      "entry_method" => "KEYED",
      "errors" => [{ "code" => "GENERIC_DECLINE", "detail" => "Authorization error: 'GENERIC_DECLINE'",
                     "category" => "PAYMENT_METHOD_ERROR" }],
      "card_payment_timeline" => { "authorized_at" => "2021-03-30T11:42:42.251Z" } },
    "location_id" => "2VTFVYA3M00KE",
    "order_id" => "GOszsmmcghp6dW9nlPptJfwc6wTZY",
    "total_money" => { "amount" => 200, "currency" => "USD" },
    "approved_money" => { "amount" => 0, "currency" => "USD" },
    "delay_action" => "CANCEL",
    "delayed_until" => "2021-04-06T11:42:42.144Z",
    "version_token" => "69lWQwBJ1RVCBXQl9VWk3f6rg1wWG7rs8iF1W95kL3F6o" } }
  end

  def successful_refund_response
    { "refund" =>
  { "id" => "16Kzd7LeQ5VzxPxSBcVUhGuWMRcZY_fg8fsD4nzAsFCnHQ1JIqIYCGb0iWTqLG9Lifyo6DGYb",
    "status" => "PENDING",
    "amount_money" => { "amount" => 100, "currency" => "USD" },
    "payment_id" => "16Kzd7LeQ5VzxPxSBcVUhGuWMRcZY",
    "order_id" => "KEsozrbefZYo0xJfgcC5naBUetPZY",
    "location_id" => "2VTFVYA3M00KE" } }
  end

  def successful_new_customer_response
    { "customer" =>
  { "id" => "ZQ3CCPG9SRTB9C7V2NG27JWME4",
    "given_name" => "Jim",
    "family_name" => "Smith",
    "email_address" => "customer@example.com",
    "address" =>
    { "address_line_1" => "456 My Street",
      "address_line_2" => "Apt 1",
      "locality" => "Ottawa",
      "administrative_district_level_1" => "ON",
      "administrative_district_level_2" => "CA",
      "postal_code" => "K1C2N6",
      "country" => "CA" },
    "phone_number" => "(555)555-5555",
    "preferences" => { "email_unsubscribed" => false },
    "creation_source" => "THIRD_PARTY" } }
  end

  def successful_new_card_response
    { "card" => { "id" => "ccof:eVRPNW4q4AOpbkWO3GB", "card_brand" => "VISA", "last_4" => "5858", "exp_month" => 3,
                  "exp_year" => 2023 } }
  end

  def successful_update_response
    { "customer" =>
  { "id" => "ZQ3CCPG9SRTB9C7V2NG27JWME4",
    "cards" =>
    [{ "id" => "ccof:kszxOTUH6yLjx88T3GB",
       "card_brand" => "VISA",
       "last_4" => "5858",
       "exp_month" => 3,
       "exp_year" => 2023,
       "billing_address" => { "postal_code" => "94103" } }],
    "given_name" => "Tom",
    "family_name" => "Smith",
    "email_address" => "customer@example.com",
    "address" =>
    { "address_line_1" => "456 My Street",
      "address_line_2" => "Apt 1",
      "locality" => "Ottawa",
      "administrative_district_level_1" => "ON",
      "administrative_district_level_2" => "CA",
      "postal_code" => "K1C2N6",
      "country" => "CA" },
    "phone_number" => "(555)555-5555",
    "preferences" => { "email_unsubscribed" => false },
    "groups" => [{ "id" => "22A4SJQS0QDCV.CARDS_ON_FILE", "name" => "Cards on File" },
                 { "id" => "22A4SJQS0QDCV.REACHABLE", "name" => "Reachable" }],
    "creation_source" => "THIRD_PARTY",
    "segment_ids" => ["22A4SJQS0QDCV.CARDS_ON_FILE", "22A4SJQS0QDCV.REACHABLE"] } }
  end
end
