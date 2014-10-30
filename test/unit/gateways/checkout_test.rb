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

    assert capture = @gateway.capture(100, '33024417', @options)
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

    assert response = @gateway.capture(100, '99999999999999999' , @options)
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
end
