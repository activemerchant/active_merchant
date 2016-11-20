require 'test_helper'

class EzicTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = EzicGateway.new(account_id: 'TheID')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '120741089764', response.authorization
    assert response.test?
    assert_equal "Street address and 9-digit postal code match.", response.avs_result["message"]
    assert_equal "CVV matches", response.cvv_result["message"]
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "TEST DECLINED", response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '120762306743', response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "TEST DECLINED", response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, "123312")
    assert_success response
    assert_equal '120762306743', response.authorization
  end

  def test_failed_capture
    @gateway.expects(:raw_ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, "2131212")
    assert_failure response
    assert_equal "20105: Settlement amount cannot exceed authorized amount", response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, "32432423", @options)
    assert_success response
    assert_equal '120421340652', response.authorization
  end

  def test_failed_refund
    @gateway.expects(:raw_ssl_request).returns(failed_refund_response)

    response = @gateway.refund(@amount, "5511231")
    assert_failure response
    assert_equal "20183: Amount of refunds exceed original sale", response.message
  end

  def test_failed_void
    @gateway.expects(:raw_ssl_request).returns(failed_void_response)

    response = @gateway.void("5511231")
    assert_failure response
    assert_equal "Processor/Network Error", response.message
  end

  def test_successful_verify
    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_raw_response, failed_void_response)
    assert_success response
    assert_equal '120762306743', response.authorization
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response, failed_void_response)
    assert_failure response
    assert_equal "TEST DECLINED", response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      <- "account_id=120536457270&amount=1.00&description=Store+Purchase&pay_type=C&card_number=4000100011112224&card_cvv2=123&card_expire=0916&bill_name2=Smith&bill_name1=Jim&bill_street=1234+My+Street&bill_city=Ottawa&bill_state=ON&bill_zip=K1C2N6&bill_country=CA&cust_phone=%28555%29555-5555&tran_type=S"
      -> "avs_code=X&cvv2_code=M&status_code=1&processor=TEST&auth_code=999999&settle_amount=1.00&settle_currency=USD&trans_id=120477042083&auth_msg=TEST+APPROVED&auth_date=2015-04-22+15:20:05"
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      <- "account_id=120536457270&amount=1.00&description=Store+Purchase&pay_type=C&card_number=[FILTERED]&card_cvv2=[FILTERED]&card_expire=0916&bill_name2=Smith&bill_name1=Jim&bill_street=1234+My+Street&bill_city=Ottawa&bill_state=ON&bill_zip=K1C2N6&bill_country=CA&cust_phone=%28555%29555-5555&tran_type=S"
      -> "avs_code=X&cvv2_code=M&status_code=1&processor=TEST&auth_code=999999&settle_amount=1.00&settle_currency=USD&trans_id=120477042083&auth_msg=TEST+APPROVED&auth_date=2015-04-22+15:20:05"
    POST_SCRUBBED
  end

  def successful_purchase_response
    "avs_code=X&cvv2_code=M&status_code=1&processor=TEST&auth_code=999999&settle_amount=1.00&settle_currency=USD&trans_id=120741089764&auth_msg=TEST+APPROVED&auth_date=2015-04-23+15:27:28"
  end

  def failed_purchase_response
    "avs_code=Y&cvv2_code=M&status_code=0&processor=TEST&settle_currency=USD&settle_amount=190.88&trans_id=120740287652&auth_msg=TEST+DECLINED&auth_date=2015-04-23+15:31:30"
  end

  def successful_authorize_response
    "avs_code=X&cvv2_code=M&status_code=T&processor=TEST&auth_code=999999&settle_amount=1.00&settle_currency=USD&trans_id=120762306743&auth_msg=TEST+APPROVED&ticket_code=XXXXXXXXXXXXXXX&auth_date=2015-04-23+17:24:37"
  end

  def failed_authorize_response
    "avs_code=Y&cvv2_code=M&status_code=0&processor=TEST&auth_code=999999&settle_currency=USD&settle_amount=190.88&trans_id=120761061862&auth_msg=TEST+DECLINED&ticket_code=XXXXXXXXXXXXXXX&auth_date=2015-04-23+17:25:35"
  end

  def successful_capture_response
    "avs_code=X&cvv2_code=M&status_code=1&auth_code=999999&trans_id=120762306743&auth_msg=TEST+CAPTURED&ticket_code=XXXXXXXXXXXXXXX&auth_date=2015-04-23+17:24:37"
  end

  def failed_capture_response
    MockResponse.failed("", 611, "20105: Settlement amount cannot exceed authorized amount")
  end

  def successful_refund_response
    "status_code=1&processor=TEST&auth_code=RRRRRR&settle_amount=-1.00&settle_currency=USD&trans_id=120421340652&auth_msg=TEST+RETURNED&auth_date=2015-04-23+18:26:02"
  end

  def failed_refund_response
    MockResponse.failed("", 611, "20183: Amount of refunds exceed original sale")
  end

  def failed_void_response
    MockResponse.failed("", 611, "Processor/Network Error")
  end

  def successful_authorize_raw_response
    MockResponse.succeeded(successful_authorize_response)
  end

end
