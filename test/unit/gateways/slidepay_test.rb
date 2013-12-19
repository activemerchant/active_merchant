require 'test_helper'

class SlidepayTest < Test::Unit::TestCase
  def setup
    @gateway = SlidepayGateway.new(
      :api_key => "API_KEY",
      :endpoint => "ENDPOINT"
    )

    @credit_card = credit_card
    @amount = 1.01

    @options = {
      :billing_address => address
    }
  end

  # instantiation
  def test_missing_endpoint
    assert_raise SlidePayEndpointMissingError do
      gateway = SlidepayGateway.new(:api_key => "API_KEY")
    end
  end

  # purchase
  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert response.is_a? Response
    assert_success response

    assert response.success?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  # credit
  def test_successful_credit
    @gateway.expects(:ssl_request).returns(successful_credit_response)

    purchase_response = slidepay_response_object(successful_purchase_response)
    payment_id = purchase_response.params["payment_id"]

    assert response = @gateway.credit(payment_id)
    assert_success response
    assert response.success?
  end

  def test_unsuccessful_credit
    @gateway.expects(:ssl_request).returns(failed_credit_response)

    purchase_response = slidepay_response_object(successful_purchase_response)
    payment_id = purchase_response.params["payment_id"]

    assert response = @gateway.credit(payment_id)
    assert_failure response
  end

  private

  def slidepay_response_object(response_string)
    return SlidePayResponse.new(response_string)
  end

  # Place raw successful response from gateway here
  def successful_credit_response
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

  # Place raw failed response from gateway here
  def failed_credit_response
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
