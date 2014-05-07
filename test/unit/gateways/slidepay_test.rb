require 'test_helper'

class SlidepayTest < Test::Unit::TestCase
  def setup
    @gateway = SlidepayGateway.new

    @credit_card = credit_card
    @amount = 1.01

    @options = {
      billing_address: address
    }
  end

  def test_missing_endpoint
    assert_raise ArgumentError do
      SlidepayGateway.new(api_key: "API_KEY", test: false)
    end
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)
    response = @gateway.refund(nil, "auth")
    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)
    response = @gateway.refund(nil, "auth")
    assert_failure response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)
    response = @gateway.capture(nil, "auth")
    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)
    response = @gateway.capture(nil, "auth")
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)
    response = @gateway.void("auth")
    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)
    response = @gateway.void("auth")
    assert_failure response
  end

  private

  def successful_refund_response
    <<-RESPONSE
    {
      "custom" : null,
      "method" : "POST",
      "operation" : "POST payment refund",
      "id" : 11626,
      "milliseconds" : "190.44",
      "obj" : null,
      "success" : true,
      "timezone" : "",
      "endpoint" : "https://dev.getcube.com:65532",
      "data" : {
        "cc_name_on_card" : null,
        "cc_redacted_number" : null,
        "cc_type" : null,
        "amount" : 10,
        "order_master_id" : 4948,
        "latitude" : null,
        "stored_payment_guid" : null,
        "method" : null,
        "transaction_state" : "Authorized",
        "transaction_token" : "DummyTransaction",
        "cc_expiry_year" : null,
        "location_id" : 14,
        "payment_token" : null,
        "status_message" : "Transaction Approved",
        "processor" : "ipcommerce-cube-vantiv",
        "company_id" : 18,
        "capture_state" : "DummyTransaction",
        "processor_time_ms" : 2.93,
        "longitude" : null,
        "fee_amount" : 0,
        "payment_id" : 0,
        "under_review" : 0,
        "approval_code" : "000000",
        "cc_expiry_month" : null,
        "batch_id" : null,
        "notes" : null,
        "cc_present" : 0,
        "method_other" : null,
        "is_approved" : true,
        "status_code" : "00"
      },
      "data_md5" : "B3269938BE3827EEC4BA3977B5BF0D3B"
    }
    RESPONSE
  end

  def successful_purchase_response
    <<-RESPONSE
    {
      "custom" : null,
      "method" : "POST",
      "operation" : "POST payment simple",
      "id" : 4639,
      "milliseconds" : "1515.60",
      "obj" : "order_master",
      "success" : true,
      "timezone" : "",
      "endpoint" : "https://dev.getcube.com:65532",
      "data" : {
        "cc_name_on_card" : null,
        "cc_redacted_number" : "************1111",
        "cc_type" : "Visa",
        "amount" : 1.01,
        "order_master_id" : 4639,
        "latitude" : "37.5671",
        "stored_payment_guid" : "ddc29c84-ed0a-4b09-ae70-0a6e09e48930",
        "method" : "CreditCard",
        "transaction_state" : "Authorized",
        "transaction_token" : "DummyTransaction",
        "cc_expiry_year" : "14",
        "location_id" : 14,
        "payment_token" : null,
        "status_message" : "Transaction Approved",
        "processor" : "ipcommerce-cube-vantiv",
        "company_id" : 18,
        "capture_state" : "DummyTransaction",
        "processor_time_ms" : 0,
        "longitude" : "-122.3710",
        "fee_amount" : 0,
        "payment_id" : 11380,
        "under_review" : 0,
        "approval_code" : "000000",
        "cc_expiry_month" : "10",
        "batch_id" : null,
        "notes" : "Goods or Services",
        "cc_present" : 0,
        "method_other" : null,
        "is_approved" : true,
        "status_code" : "00"
      },
      "data_md5" : "3D70B732D896249874EE284B6F666618"
    }
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
    {
      "custom" : null,
      "method" : "POST",
      "operation" : "POST authorization simple",
      "id" : 4970,
      "milliseconds" : "1165.04",
      "obj" : "order_master",
      "success" : true,
      "timezone" : "",
      "endpoint" : "https://dev.getcube.com:65532",
      "data" : {
        "cc_name_on_card" : null,
        "cc_redacted_number" : "************1111",
        "cc_type" : "Visa",
        "amount" : 1.32,
        "order_master_id" : 4970,
        "latitude" : "37.5671",
        "stored_payment_guid" : "0f307cd1-8828-496b-8dc2-396ba5fd717c",
        "method" : "CreditCard",
        "transaction_state" : "Authorized",
        "transaction_token" : "DummyTransaction",
        "cc_expiry_year" : "15",
        "location_id" : 14,
        "payment_token" : null,
        "status_message" : "Transaction Approved",
        "processor" : "ipcommerce-cube-vantiv",
        "company_id" : 18,
        "capture_state" : "DummyTransaction",
        "processor_time_ms" : 0,
        "longitude" : "-122.3710",
        "fee_amount" : 0,
        "payment_id" : 11642,
        "under_review" : 0,
        "approval_code" : "000000",
        "cc_expiry_month" : "11",
        "batch_id" : null,
        "notes" : "Goods or Services",
        "cc_present" : 0,
        "method_other" : null,
        "is_approved" : true,
        "status_code" : "00"
      },
      "data_md5" : "880616AA6DD8067F665F3427385813B2"
    }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    {
      "custom" : null,
      "method" : "POST",
      "operation" : "POST capture auto",
      "id" : 11642,
      "milliseconds" : "96.67",
      "obj" : null,
      "success" : true,
      "timezone" : "",
      "endpoint" : "https://dev.getcube.com:65532",
      "data" : null,
      "data_md5" : null
    }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {
      "custom" : null,
      "method" : "POST",
      "operation" : "POST authorization void",
      "id" : 11674,
      "milliseconds" : "3277.13",
      "obj" : null,
      "success" : true,
      "timezone" : "",
      "endpoint" : "https://dev.getcube.com:65532",
      "data" : null,
      "data_md5" : null
    }
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
    {
      "custom" : null,
      "method" : "POST",
      "operation" : "POST authorization void",
      "id" : 11674,
      "milliseconds" : "202.16",
      "obj" : null,
      "success" : false,
      "timezone" : "",
      "endpoint" : "https://dev.getcube.com:65532",
      "data" : {
        "error_code" : "82",
        "error_text" : "Unable to process your request.  Payment capture state is not ReadyForCapture for payment_id 11674.",
        "error_file" : "l_post_void.cs"
      },
      "data_md5" : "76BB7A839F944A81D876B221B8247F1D"
    }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
    {
      "custom" : null,
      "method" : "POST",
      "operation" : "POST capture auto",
      "id" : 11642,
      "milliseconds" : "84.96",
      "obj" : null,
      "success" : false,
      "timezone" : "",
      "endpoint" : "https://dev.getcube.com:65532",
      "data" : null,
      "data_md5" : null
    }
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
    {
      "custom" : null,
      "method" : "POST",
      "operation" : "POST authorization simple",
      "id" : 0,
      "milliseconds" : "4472.83",
      "obj" : null,
      "success" : false,
      "timezone" : "",
      "endpoint" : "https://dev.getcube.com:65532",
      "data" : {
        "cc_name_on_card" : null,
        "cc_redacted_number" : "************1111",
        "cc_type" : "Visa",
        "amount" : 1.32,
        "order_master_id" : 4971,
        "latitude" : "37.5671",
        "stored_payment_guid" : "",
        "method" : "CreditCard",
        "transaction_state" : "Declined",
        "transaction_token" : "E656D8ACC5A54E9AAF93C0673EADF196",
        "cc_expiry_year" : "15",
        "location_id" : 14,
        "payment_token" : null,
        "status_message" : "Invalid Account Number",
        "processor" : "ipcommerce-cube-vantiv",
        "company_id" : 18,
        "capture_state" : "CannotCapture",
        "processor_time_ms" : 2968.86,
        "longitude" : "-122.3710",
        "fee_amount" : 0.05,
        "payment_id" : 11643,
        "under_review" : 0,
        "approval_code" : null,
        "cc_expiry_month" : "11",
        "batch_id" : null,
        "notes" : "Goods or Services",
        "cc_present" : 0,
        "method_other" : null,
        "is_approved" : false,
        "status_code" : "14"
      },
      "data_md5" : "B9C1DD1100962D0C7B17A3A641AAB7A1"
    }
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
    {
      "custom" : null,
      "method" : "POST",
      "operation" : "POST payment refund",
      "id" : 11626,
      "milliseconds" : "188.48",
      "obj" : null,
      "success" : false,
      "timezone" : "",
      "endpoint" : "https://dev.getcube.com:65532",
      "data" : {
        "error_code" : "76",
        "error_text" : "Refund amount 10.00 exceeds the order amount paid 0.00.",
        "error_file" : "i_refund.cs"
      },
      "data_md5" : "C2C6ABADCA2AEA28611F0C3E63DF6DEB"
    }
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
    {
      "custom" : null,
      "method" : "POST",
      "operation" : "POST payment simple",
      "id" : 0,
      "milliseconds" : "4296.79",
      "obj" : null,
      "success" : false,
      "timezone" : "",
      "endpoint" : "https://dev.getcube.com:65532",
      "data" : {
        "cc_name_on_card" : null,
        "cc_redacted_number" : "************1111",
        "cc_type" : "Visa",
        "amount" : 1.01,
        "order_master_id" : 4641,
        "latitude" : "37.5671",
        "stored_payment_guid" : "",
        "method" : "CreditCard",
        "transaction_state" : "Declined",
        "transaction_token" : "6F3000A1E44C478D89F74A08045EDFDF",
        "cc_expiry_year" : "14",
        "location_id" : 14,
        "payment_token" : null,
        "status_message" : "Invalid Account Number",
        "processor" : "ipcommerce-cube-vantiv",
        "company_id" : 18,
        "capture_state" : "CannotCapture",
        "processor_time_ms" : 2937.44,
        "longitude" : "-122.3710",
        "fee_amount" : 0.04,
        "payment_id" : 11382,
        "under_review" : 0,
        "approval_code" : null,
        "cc_expiry_month" : "10",
        "batch_id" : null,
        "notes" : "Goods or Services",
        "cc_present" : 0,
        "method_other" : null,
        "is_approved" : false,
        "status_code" : "14"
      },
      "data_md5" : null
    }
    RESPONSE
  end
end
