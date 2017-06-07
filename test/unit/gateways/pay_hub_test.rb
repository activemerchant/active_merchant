require 'test_helper'

class PayHubTest < Test::Unit::TestCase
  def setup
    @gateway = PayHubGateway.new(fixtures(:pay_hub))
    @credit_card = credit_card('5466410004374507', verification_value: "998")
    @amount = 200
    @options = {
      first_name: 'Garry',
      last_name: 'Barry',
      email: 'payhubtest@mailinator.com',
      :address => {
        :address1 => '123a ahappy St.',
        :city => 'Happya City',
        :state => 'CA',
        :zip => '94901'
      },
      :record_format => "CREDIT_CARD",
      :schedule => {
        :schedule_type => 'S',
        :specific_dates_schedule => {
        :specific_dates => [
          (Date.today + 1.month).to_s,
          (Date.today + 2.month).to_s
          ]
        }
      }
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(fake_response("post", "/sale/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", successful_purchase_response))
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal "SUCCESS", response.message
  end

  def test_successful_purchase_without_options
    @gateway.expects(:ssl_post).returns(fake_response("post", "/sale/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", successful_purchase_response))
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert response.test?
    assert_equal "SUCCESS", response.message
  end
  
  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(fake_response("post", "/sale/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", response_for_error_codes('4018')))
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "INVALID_CUSTOMER_DATA_FIELD", response.params["reason"]
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(fake_response("post", "/refund/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", successful_refund_response))
    response = @gateway.refund("15580", @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_post).returns(fake_response("post", "/refund/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", response_for_error_codes("4074")))
    assert response = @gateway.refund("15580", @options)
    assert_failure response
    assert_equal "UNABLE_TO_REFUND_CODE", response.params["reason"]
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(fake_response("post", "/void/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", successful_void_response))
    assert response = @gateway.void("15580", @options)
    assert_success response
    assert response.test?
    assert_equal "SUCCESS", response.message
  end

  def test_unsuccessful_void
    @gateway.expects(:ssl_post).returns(fake_response("post", "/void/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", response_for_error_codes("4073")))
    assert response = @gateway.void("15580", @options)
    assert_failure response
    assert_equal "UNABLE_TO_VOID_CODE", response.params["reason"]
  end

  def test_successful_recurring
    @gateway.expects(:ssl_post).returns(fake_response("post", "/recurring-bill/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", successful_recurring_response))
    response = @gateway.recurring(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_recurring
    @gateway.expects(:ssl_post).returns(fake_response("post", "/recurring-bill/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", response_for_error_codes("4514")))
    @options[:schedule][:specific_dates_schedule][:specific_dates] = [(Date.today - 1.month).to_s]
    response = @gateway.recurring(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "INCONSISTENT_SCHEDULE_FIELDS", response.params["reason"]
  end

  def test_invalid_raw_response
    @gateway.expects(:ssl_post).returns(fake_response("post", "/sale/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", invalid_json_response))
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{^Invalid response received from the Payhub API}, response.message
  end

  def test_invalid_number
    @gateway.expects(:ssl_post).returns(fake_response("post", "/sale/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", response_for_error_codes('4018')))
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "INVALID_CUSTOMER_DATA_FIELD", response.params["reason"]
  end

  def test_invalid_expiry_date
    @gateway.expects(:ssl_post).returns(fake_response("post", "/sale/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", response_for_error_codes('4506')))
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "INVALID_END_DATE", response.params["reason"]
  end

  def test_invalid_cvv
    @gateway.expects(:ssl_post).returns(fake_response("post", "/sale/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", response_for_error_codes('4019')))
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "INVALID_CVV_CODE", response.params["reason"]
  end

  def test_expired_card
    @gateway.expects(:ssl_post).returns(fake_response("post", "/sale/15580"))
    @gateway.expects(:ssl_get).returns(fake_response("get", response_for_error_codes('4025')))
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "INVALID_CARD_EXPIRY_DATE", response.params["reason"]
  end
  
  private

  def response_for_error_codes(error_code)
    <<-RESPONSE
    {
      "errors": [{
        "status": "BAD_REQUEST",
        "code": "#{error_code}",
        "location": "card_number",
        "reason": "#{PayHubGateway::STANDARD_ERROR_CODE_MAPPING[error_code]}",
        "severity": "Error"
      }]
    }
    RESPONSE
  end

  def successful_purchase_response
    <<-RESPONSE
    {
      "saleResponse" : {
        "saleId" : "15580",
        "approvalCode" : "VTLMC1",
        "processedDateTime" : null,
        "avsResultCode" : "N",
        "verificationResultCode" : "M",
        "batchId" : "847",
        "responseCode" : "00",
        "responseText" : "NO  MATCH",
        "cisNote" : "",
        "riskStatusResponseText" : "",
        "riskStatusRespondeCode" : "",
        "saleDateTime" : "2015-09-07 00:50:28",
        "customerReference" : {
          "customerId" : 359,
          "customerEmail" : "payhubtest@mailinator.com",
          "customerPhones" : [ ]
        }
      }
    }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {
      "lastVoidResponse": {
        "saleTransactionId": "15580",
        "voidTransactionId": "15581",
        "token": "9999000000001853"
      }
    }
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    {
      "lastRefundResponse": {
        "saleTransactionId": "15886",
        "refundTransactionId": "15946",
        "token": "9999000000001853"
      }    
    }
    RESPONSE
  end

  def successful_recurring_response
    <<-RESPONSE
    {
      "lastRecurringBillResponse" : {
        "recurringBillId" : "15580"
      }
    }
    RESPONSE
  end
  
  def invalid_json_response
    <<-RESPONSE
    "foo" =>  "bar"
    RESPONSE
  end
  
  def fake_response(method, body)
    if method == "post"
      net_http_resp = Net::HTTPCreated.new('post', 201, "Created")
      body = "https://sandbox-api.payhub.com/api/v2" + body
      net_http_resp.add_field 'location', body
    elsif method == "get"
      net_http_resp = Net::HTTPOK.new('get', 200, "OK")
      net_http_resp.body = body
      net_http_resp.reading_body(MySocketStub.new(body), true){}
      net_http_resp.body = body
    end
    net_http_resp
  end
end

class MySocketStub
  def initialize(body)
    @body = body
  end

  def closed?
    false
  end

  def read_all(from)
    @body
  end
end
