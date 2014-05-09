require 'test_helper'

class AlfabankTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = AlfabankGateway.new(:account => 'account', :secret => 'secret')

    @amount = 12
    @description = 'activemerchant test'
    @return_url = 'http://activemerchant.org'
  end

  def test_successful_make_order
    @gateway.expects(:ssl_request).returns(successful_make_order)

    assert response = @gateway.make_order(:amount => 100, :order_number => 87654321, :return_url => 'finish.html')
    assert_instance_of Response, response
    assert_success response

    assert_not_nil response.params['form_url']
  end

  def test_successful_order_status_extended
    @gateway.expects(:ssl_request).returns(successful_order_status_extended)

    assert response = @gateway.get_order_status(:order_id => '285b2973-4d02-4980-a54e-57c4d0d2xxx9')
    assert_instance_of Response, response
    assert_success response

    assert_equal 100, response.params['amount']
    assert_equal '810', response.params['currency']
    assert_equal '1212x31334z15', response.params['order_number']
  end

  private

  def successful_make_order
    <<-RESPONSE
{
  "orderId": "61351fbd-ac25-484f-b930-4d0ce4101ab7",
  "formUrl": "https:\/\/test.paymentgate.ru\/testpayment\/merchants\/test\/payment_ru.html?mdOrder=61351fbd-ac25-484f-b930-4d0ce4101ab7"
}
    RESPONSE
  end

  def successful_order_status_extended
    <<-RESPONSE
{
  "attributes": [

  ],
  "date": 1342007119386,
  "currency": "810",
  "amount": 100,
  "actionCode": 0,
  "orderNumber": "1212x31334z15",
  "orderDescription": "test",
  "orderStatus": 2,
  "ip": "217.12.97.50",
  "actionCodeDescription": "\u041f\u043b\u0430\u0442\u0435\u0436 \u0443\u0441\u043f\u0435\u0448\u043d\u043e \u043e\u0431\u0440\u0430\u0431\u043e\u0442\u0430\u043d",
  "merchantOrderParams": [

  ],
  "cardAuthInfo": {
    "expiration": "201512",
    "pan": "411111**1111",
    "approvalCode": "123456",
    "cardholderName": "dsd qdqd",
    "secureAuthInfo": {
      "eci": 5,
      "threeDSInfo": {
        "cavv": "AAABCpEAUBNCAHEgBQAAAAAAAAA=",
        "xid": "MDAwMDAwMDEzNDIwMDcxMTk3Njc="
      }
    }
  }
}
    RESPONSE
  end
end