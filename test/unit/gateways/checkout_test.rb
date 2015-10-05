require 'test_helper'

class CheckoutTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = ActiveMerchant::Billing::CheckoutGateway.new(
      :merchant_id    => 'SBMTEST',    # Merchant Code
      :password => 'Password1!'          # Processing Password
    )
    @options = {
      order_id: generate_unique_id
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(100, credit_card, @options)
    assert_success response

    assert_equal 'Successful', response.message
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.authorize(100, credit_card, @options)
    assert_success response

    assert_equal 'Successful', response.message
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert capture = @gateway.capture(100, '36919371|9c38d0506da258e216fa072197faaf37|1|CAD|100', @options)
    assert_success capture

    assert_equal 'Successful', capture.message
    assert capture.test?
  end

  def test_unsuccessful_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    assert response = @gateway.authorize(100, credit_card, @options)
    assert_failure response
    assert_equal 'Not Successful', response.message
    assert response.test?
  end

  def test_unsuccessful_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    assert response = @gateway.capture(100, '||||' , @options)
    assert_failure response
    assert_equal 'EGP00173', response.params["error_code_tag"]
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(100, credit_card, @options)
    assert_failure response
    assert_equal 'Not Successful', response.message
    assert response.test?
  end

  def test_passes_correct_currency
    stub_comms do
      @gateway.purchase(100, credit_card, @options.merge(
        currency: "EUR"
      ))
    end.check_request do |endpoint, data, headers|
      assert_match(/<bill_currencycode>EUR<\/bill_currencycode>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passes_descriptors
    stub_comms do
      @gateway.purchase(100, credit_card, @options.merge(
        descriptor_name: "ZahName",
        descriptor_city: "Oakland"
      ))
    end.check_request do |endpoint, data, headers|
      assert_match(/<descriptor_name>ZahName<\/descriptor_name>/, data)
      assert_match(/<descriptor_city>Oakland<\/descriptor_city>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_successful_void
    @options['orderid'] = '9c38d0506da258e216fa072197faaf37'
    void = stub_comms(@gateway, :ssl_request) do
      @gateway.void('36919371|9c38d0506da258e216fa072197faaf37|1|CAD|100', @options)
    end.check_request do |method, endpoint, data, headers|
      # Should only be one pair of track id tags.
      assert_equal 2, data.scan(/trackid/).count
    end.respond_with(successful_void_response)

    assert void
    assert_success void

    assert_equal 'Successful', void.message
    assert void.test?
  end

  def test_unsuccessful_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert void = @gateway.void('36919371|9c38d0506da258e216fa072197faaf37|1|CAD|100', @options)
    assert_failure void
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert refund = @gateway.refund(100, '36919371|9c38d0506da258e216fa072197faaf37|1|CAD|100', @options)
    assert_success refund

    assert_equal 'Successful', refund.message
    assert refund.test?
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert refund = @gateway.refund(100, '36919371|9c38d0506da258e216fa072197faaf37|1|CAD|100', @options)
    assert_failure refund
  end

  def test_successful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(credit_card, @options)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
    assert_equal "33024417", response.params['tranid']
  end

  def test_successful_verify_with_failed_void
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal "Successful", response.message
  end

  def test_unsuccessful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(credit_card, @options)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal "Not Successful", response.message
  end

  private

  def failed_purchase_response
    <<-RESPONSE
    <?xml version="1.0" encoding="UTF-8"?><response type="valid" service="token"><result>Not Successful</result><responsecode>5</responsecode><recommendedaction>Cardholder must call his bank before re-attempting this transaction or try another card</recommendedaction><issuerinfo><name>STATE BANK OF MAURITIUS, LTD.</name><cardbrand>VISA</cardbrand><country>MAURITIUS</country></issuerinfo><CVV2response>X</CVV2response><AVSresponse>0</AVSresponse><tranid>33025003</tranid><authcode>000000</authcode><trackid>Test Shopify - 1003</trackid><merchantid>SBMTEST</merchantid></response>
    RESPONSE
  end

  def successful_purchase_response
    <<-RESPONSE
    <?xml version="1.0" encoding="UTF-8"?><response type="valid" service="token"><result>Successful</result><responsecode>0</responsecode><CVV2response>X</CVV2response><AVSresponse>S</AVSresponse><tranid>33024417</tranid><authcode>429259</authcode><trackid>Test Shopify - 1003</trackid><merchantid>SBMTEST</merchantid><customer_token>ec0db513-1727-4554-a74f-67297a1db499</customer_token></response>
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
    <?xml version="1.0" encoding="UTF-8"?><response type="valid" service="token"><result>Not Successful</result><responsecode>5</responsecode><recommendedaction>Cardholder must call his bank before re-attempting this transaction or try another card</recommendedaction><issuerinfo><name>STATE BANK OF MAURITIUS, LTD.</name><cardbrand>VISA</cardbrand><country>MAURITIUS</country></issuerinfo><CVV2response>X</CVV2response><AVSresponse>0</AVSresponse><tranid>33025003</tranid><authcode>000000</authcode><trackid>Test Shopify - 1003</trackid><merchantid>SBMTEST</merchantid></response>
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
    <?xml version="1.0" encoding="UTF-8"?><response type="valid" service="token"><result>Successful</result><responsecode>0</responsecode><CVV2response>X</CVV2response><AVSresponse>S</AVSresponse><tranid>33024417</tranid><authcode>429259</authcode><trackid>Test Shopify - 1003</trackid><merchantid>SBMTEST</merchantid><customer_token>ec0db513-1727-4554-a74f-67297a1db499</customer_token></response>
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
    <?xml version="1.0" encoding="UTF-8"?><response type="error"><error_code_tag>EGP00173</error_code_tag><error_text>EGP00173-Currency Code mismatch</error_text></response>
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    <?xml version="1.0" encoding="UTF-8"?><response type="valid" service="token"><result>Successful</result><responsecode>0</responsecode><CVV2response>X</CVV2response><AVSresponse>S</AVSresponse><tranid>33024417</tranid><authcode>429259</authcode><trackid>Test Shopify - 1003</trackid><merchantid>SBMTEST</merchantid><customer_token>ec0db513-1727-4554-a74f-67297a1db499</customer_token></response>
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    <?xml version=\"1.0\" encoding=\"UTF-8\"?><response type=\"valid\"><result>Successful</result><responsecode>0</responsecode><tranid>36919479</tranid><authcode>447338</authcode><trackid>dd7bd9e2c8d79eb16c88a29fdfe846fe</trackid><merchantid>SBMTEST</merchantid></response>
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
    <?xml version=\"1.0\" encoding=\"UTF-8\"?><response type=\"error\"><error_code_tag>EGP00165</error_code_tag><error_text>EGP00165-Invalid Track ID data</error_text></response>
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    <?xml version=\"1.0\" encoding=\"UTF-8\"?><response type=\"valid\"><result>Successful</result><responsecode>0</responsecode><tranid>36919603</tranid><authcode>454744</authcode><trackid>91654e4413a1a1c0a7f4f84880984872</trackid><merchantid>SBMTEST</merchantid></response>
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
    <?xml version=\"1.0\" encoding=\"UTF-8\"?><response type=\"error\"><error_code_tag>EGP00165</error_code_tag><error_text>EGP00165-Invalid Track ID data</error_text></response>
    RESPONSE
  end
end
