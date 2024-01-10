require 'test_helper'

class MokaTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = MokaGateway.new(dealer_code: '123', username: 'username', password: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'Test-9732c2ce-08d9-4ff6-a89f-bd3fa345811c', response.authorization
    assert response.test?
  end

  def test_failed_purchase_with_top_level_error
    @gateway.expects(:ssl_post).returns(failed_response_with_top_level_error)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'PaymentDealer.DoDirectPayment.InvalidRequest', response.error_code
    assert_equal 'PaymentDealer.DoDirectPayment.InvalidRequest', response.message
  end

  def test_failed_purchase_with_nested_error
    @gateway.expects(:ssl_post).returns(failed_response_with_nested_error)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response

    assert_equal 'General error', response.error_code
    assert_equal 'Genel Hata(Geçersiz kart numarası)', response.message
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 1, JSON.parse(data)['PaymentDealerRequest']['IsPreAuth']
    end.respond_with(successful_response)
    assert_success response

    assert_equal 'Test-9732c2ce-08d9-4ff6-a89f-bd3fa345811c', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_response_with_top_level_error)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_response)

    response = @gateway.capture(@amount, 'Test-9732c2ce-08d9-4ff6-a89f-bd3fa345811c', @options)
    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, 'wrong-authorization', @options)
    assert_failure response
    assert_equal 'PaymentDealer.DoCapture.PaymentNotFound', response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(0, 'Test-9732c2ce-08d9-4ff6-a89f-bd3fa345811c')
    assert_success response
  end

  def test_successful_partial_refund
    stub_comms do
      @gateway.refund(50, 'Test-9732c2ce-08d9-4ff6-a89f-bd3fa345811c')
    end.check_request do |_endpoint, data, _headers|
      assert_equal '0.50', JSON.parse(data)['PaymentDealerRequest']['Amount']
    end.respond_with(successful_refund_response)
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(0, '')
    assert_failure response
    assert_equal 'PaymentDealer.DoCreateRefundRequest.OtherTrxCodeOrVirtualPosOrderIdMustGiven', response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_response)

    response = @gateway.void('Test-9732c2ce-08d9-4ff6-a89f-bd3fa345811c')
    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('')
    assert_failure response
    assert_equal 'PaymentDealer.DoVoid.InvalidRequest', response.error_code
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_response)
    assert_success response
    assert_equal 'Test-9732c2ce-08d9-4ff6-a89f-bd3fa345811c', response.authorization
    assert_equal 'Success', response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(failed_response_with_top_level_error)
    assert_failure response
    assert_equal 'PaymentDealer.DoDirectPayment.InvalidRequest', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_buyer_information_is_passed
    options = @options.merge({
      billing_address: address,
      email: 'safiye.ali@example.com'
    })

    stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      buyer_info = JSON.parse(data)['PaymentDealerRequest']['BuyerInformation']
      assert_equal buyer_info['BuyerFullName'], [@credit_card.first_name, @credit_card.last_name].join(' ')
      assert_equal buyer_info['BuyerEmail'], 'safiye.ali@example.com'
      assert_equal buyer_info['BuyerAddress'], options[:billing_address][:address1]
      assert_equal buyer_info['BuyerGsmNumber'], options[:billing_address][:phone]
    end.respond_with(successful_response)
  end

  def test_basket_product_is_passed
    options = @options.merge({
      basket_product: [
        {
          product_id: 333,
          product_code: '0173',
          unit_price: 19900,
          quantity: 1
        },
        {
          product_id: 281,
          product_code: '38',
          unit_price: 5000,
          quantity: 1
        }
      ]
    })

    stub_comms do
      @gateway.authorize(24900, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      basket = JSON.parse(data)['PaymentDealerRequest']['BasketProduct']
      basket.each_with_index do |product, i|
        assert_equal product['ProductId'], options[:basket_product][i][:product_id]
        assert_equal product['ProductCode'], options[:basket_product][i][:product_code]
        assert_equal product['UnitPrice'], sprintf('%<item>.2f', item: options[:basket_product][i][:unit_price] / 100)
        assert_equal product['Quantity'], options[:basket_product][i][:quantity]
      end
    end.respond_with(successful_response)
  end

  def test_additional_auth_purchase_fields_are_passed
    options = @options.merge({
      description: 'custom purchase',
      installment_number: 12,
      sub_merchant_name: 'testco',
      is_pool_payment: 1
    })
    stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      response = JSON.parse(data)
      assert_equal response['PaymentDealerRequest']['Description'], 'custom purchase'
      assert_equal response['PaymentDealerRequest']['InstallmentNumber'], 12
      assert_equal response['SubMerchantName'], 'testco'
      assert_equal response['IsPoolPayment'], 1
    end.respond_with(successful_response)
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to service.testmoka.com:443...
      opened
      starting SSL for service.testmoka.com:443...
      SSL established
      <- "POST /PaymentDealer/DoDirectPayment HTTP/1.1\r\nContent-Type: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: service.testmoka.com\r\nContent-Length: 443\r\n\r\n"
      <- "{\"PaymentDealerRequest\":{\"Amount\":\"1.00\",\"Currency\":\"TL\",\"CardHolderFullName\":\"Longbob Longsen\",\"CardNumber\":\"5269111122223332\",\"ExpMonth\":10,\"ExpYear\":2024,\"CvcNumber\":\"123\",\"IsPreAuth\":0,\"BuyerInformation\":{\"BuyerFullName\":\"Longbob Longsen\"}},\"PaymentDealerAuthentication\":{\"DealerCode\":\"1731\",\"Username\":\"TestMoka2\",\"Password\":\"HYSYHDS8DU8HU\",\"CheckKey\":\"1c1cccfe19b782415c207f1d66f97889cf11ed6d1e1ad6f585e5fe70b6f5da90\"},\"IsPoolPayment\":0}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Expires: -1\r\n"
      -> "Server: Microsoft-IIS/10.0\r\n"
      -> "X-AspNet-Version: 4.0.30319\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Headers: *\r\n"
      -> "Date: Mon, 16 Aug 2021 20:33:17 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Content-Length: 188\r\n"
      -> "\r\n"
      reading 188 bytes...
      -> "{\"Data\":{\"IsSuccessful\":true,\"ResultCode\":\"\",\"ResultMessage\":\"\",\"VirtualPosOrderId\":\"Test-e8345c66-b614-4490-83ce-7be510f22312\"},\"ResultCode\":\"Success\",\"ResultMessage\":\"\",\"Exception\":null}"
      read 188 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to service.testmoka.com:443...
      opened
      starting SSL for service.testmoka.com:443...
      SSL established
      <- "POST /PaymentDealer/DoDirectPayment HTTP/1.1\r\nContent-Type: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: service.testmoka.com\r\nContent-Length: 443\r\n\r\n"
      <- "{\"PaymentDealerRequest\":{\"Amount\":\"1.00\",\"Currency\":\"TL\",\"CardHolderFullName\":\"Longbob Longsen\",\"CardNumber\":\"[FILTERED]\",\"ExpMonth\":10,\"ExpYear\":2024,\"CvcNumber\":\"[FILTERED]\",\"IsPreAuth\":0,\"BuyerInformation\":{\"BuyerFullName\":\"Longbob Longsen\"}},\"PaymentDealerAuthentication\":{\"DealerCode\":\"[FILTERED]\",\"Username\":\"[FILTERED]\",\"Password\":\"[FILTERED]\",\"CheckKey\":\"[FILTERED]\"},\"IsPoolPayment\":0}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Expires: -1\r\n"
      -> "Server: Microsoft-IIS/10.0\r\n"
      -> "X-AspNet-Version: 4.0.30319\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Headers: *\r\n"
      -> "Date: Mon, 16 Aug 2021 20:33:17 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Content-Length: 188\r\n"
      -> "\r\n"
      reading 188 bytes...
      -> "{\"Data\":{\"IsSuccessful\":true,\"ResultCode\":\"\",\"ResultMessage\":\"\",\"VirtualPosOrderId\":\"Test-e8345c66-b614-4490-83ce-7be510f22312\"},\"ResultCode\":\"Success\",\"ResultMessage\":\"\",\"Exception\":null}"
      read 188 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_response
    <<-RESPONSE
      {
        "Data": {
          "IsSuccessful": true,
          "ResultCode": "",
          "ResultMessage": "",
          "VirtualPosOrderId": "Test-9732c2ce-08d9-4ff6-a89f-bd3fa345811c"
        },
        "ResultCode": "Success",
        "ResultMessage": "",
        "Exception": null
      }
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
      {
        "Data": {
          "IsSuccessful": true,
          "ResultCode": "",
          "ResultMessage": "",
          "RefundRequestId": 2320
        },
        "ResultCode": "Success",
        "ResultMessage": "",
        "Exception": null
      }
    RESPONSE
  end

  def failed_response_with_top_level_error
    <<-RESPONSE
      {
        "Data": null,
        "ResultCode": "PaymentDealer.DoDirectPayment.InvalidRequest",
        "ResultMessage": "",
        "Exception": null
      }
    RESPONSE
  end

  def failed_response_with_nested_error
    <<-RESPONSE
    {
      "Data": {
        "IsSuccessful": false,
        "ResultCode": "000",
        "ResultMessage": "Genel Hata(Geçersiz kart numarası)",
        "VirtualPosOrderId": ""
      },
      "ResultCode": "Success",
      "ResultMessage": "",
      "Exception": null
    }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
      {
        "Data": null,
        "ResultCode": "PaymentDealer.DoCapture.PaymentNotFound",
        "ResultMessage": "",
        "Exception": null
      }
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
      {
        "Data": null,
        "ResultCode": "PaymentDealer.DoCreateRefundRequest.OtherTrxCodeOrVirtualPosOrderIdMustGiven",
        "ResultMessage": "",
        "Exception": null
      }
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
      {
        "Data": null,
        "ResultCode": "PaymentDealer.DoVoid.InvalidRequest",
        "ResultMessage": "",
        "Exception": null
      }
    RESPONSE
  end
end
