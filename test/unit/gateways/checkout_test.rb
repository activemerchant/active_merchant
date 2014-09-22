require 'test_helper'

class CheckoutTest < Test::Unit::TestCase

  include CommStub

  def setup
    # Gateway credentials
    @gateway = ActiveMerchant::Billing::CheckoutGateway.new(
      :merchant_id    => 'SBMTEST',    # Merchant Code
      :password => 'Password1!'          # Processing Password
    )

    # Create a new credit card object
    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number     => '4543474002249996',
      :month      => '06',
      :year       => '2017',
      :name  => 'Checkout Testing', # Card holder name
      :verification_value  => '956'
    )

    # Create a new credit card object
    @declined_card  = ActiveMerchant::Billing::CreditCard.new(
      :number     => '4543474002249996',
      :month      => '06',
      :year       => '2018',
      :name  => 'Checkout Testing', # Card holder name
      :verification_value  => '958'
    )

    # Additional information
    @options = {

        :currency       => 'EUR',
        :order_id       => 'Test - 1001',
        :email        => 'bill_email@email.com',

        # Billing Details
        :billing_address => {
          :address1     => 'bill_address',
          :city       => 'bill_city',
          :state      => 'bill_state',
          :zip        => '02346',
          :country    => 'US',
          :phone      => '2308946513541'
        },

        # Shipping Details
        :shipping_address   => {
          :address1     => 'ship_address',
          :address2     => 'ship_address2',
          :city       => 'ship_city',
          :state      => 'ship_state',
          :zip        => '02346',
          :country    => 'US',
          :phone      => '2308946513542'
        },

        # Other fields
        :ip         => '127.0.0.1',
        :customer       => '123456498'
    }

    # Amount in cents
    @amount = 100

  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'Successful', response.params["result"]
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'Successful', response.params["result"]
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert capture = @gateway.capture(@amount, '33024417', @options)
    assert_success capture

    assert_equal 'Successful', capture.params["result"]
    assert capture.test?
  end

  def test_unsuccessful_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Not Successful', response.params["result"]
    assert response.test?
  end

  def test_unsuccessful_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    assert response = @gateway.capture(@amount, '99999999999999999' , @options)
    assert_failure response
    assert_equal 'EGP00173', response.params["error_code_tag"]
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Not Successful', response.params["result"]
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
