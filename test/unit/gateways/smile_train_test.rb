require 'test_helper'

class SmileTrainTest < Test::Unit::TestCase
  def setup
    @gateway = SmileTrainGateway.new(email: 'login', token: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      first_name: 'Longjane',
      last_name: 'Longsen',
      email: "jane@example.com",
      description: 'Store Purchase',
      email_subscription: true,
      mail_subscription: true,
      mobile_subscription: true,
      phone_subscription: true,
      gift_aid_choice: true,
      gender: 'Female',
      dob: '1960-01-01',
      submitted_by: 'John Doe',
      mailcode: 'A123456YYYZZZ'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'Donation has been processed.', response.message
    assert_equal '6m5ksv36', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Donation has been failed.', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to p2picrstagingwebos7.icreondemoserver.com:443...
      opened
      starting SSL for p2picrstagingwebos7.icreondemoserver.com:443...
      SSL established
      <- "POST /api/v2/donate HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: c21pbGUudHJhaW5AaWNyZW9uLmNvbTpIMTQwN01BVENIVk9VQ0g=\r\nX-St-Auth: test\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: p2picrstagingwebos7.icreondemoserver.com\r\nContent-Length: 590\r\n\r\n"
      <- "{\"amount\":\"5.00\",\"currency\":1,\"frequency\":1,\"cardNumber\":\"4111111111111111\",\"cardMonthExp\":9,\"cardYearExp\":2019,\"cvv\":\"123\",\"billingTitle\":\"Longbob Longsen\",\"streetAddress\":\"456 My Street\",\"streetAddress2\":\"Apt 1\",\"country\":\"CA\",\"zipCode\":\"K1C2N6\",\"state\":\"ON\",\"city\":\"Ottawa\",\"phoneNumber\":\"(555)555-5555\",\"selectPhoneType\":4,\"firstName\":\"Longbob\",\"lastName\":\"Longsen\",\"email\":\"joe@example.com\",\"gender\":null,\"dateOfBirth\":null,\"emailSubscription\":null,\"mailSubscription\":null,\"mobileSubscription\":null,\"phoneSubscription\":null,\"giftAidChoice\":null,\"domainName\":1,\"submittedBy\":\"John Doe\"}"
      -> "HTTP/1.0 200 OK\r\n"
      -> "Date: Thu, 15 Feb 2018 23:51:44 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Vary: Authorization\r\n"
      -> "X-Powered-By: PHP/5.6.33\r\n"
      -> "Cache-Control: max-age=1, private, must-revalidate\r\n"
      -> "Expires: Sat, 17 Feb 2018 23:51:44 GMT\r\n"
      -> "Content-Length: 211\r\n"
      -> "Connection: close\r\n"
      -> "Content-Type: application/json\r\n"
      -> "\r\n"
      reading 211 bytes...
      -> ""
      -> "{\"ResponseStatus\":true,\"ResponseCode\":200,\"ResponseMessage\":\"Donation has been processed.\",\"ResponseData\":{\"braintreeMessage\":null,\"transactionId\":\"6m5ksv36\",\"subscriptionId\":null,\"transactionStatus\":\"Success\"}}"
      read 211 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to p2picrstagingwebos7.icreondemoserver.com:443...
      opened
      starting SSL for p2picrstagingwebos7.icreondemoserver.com:443...
      SSL established
      <- "POST /api/v2/donate HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: [FILTERED]=\r\nX-St-Auth: test\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: p2picrstagingwebos7.icreondemoserver.com\r\nContent-Length: 590\r\n\r\n"
      <- "{\"amount\":\"5.00\",\"currency\":1,\"frequency\":1,\"cardNumber\":\"[FILTERED]\",\"cardMonthExp\":9,\"cardYearExp\":2019,\"cvv\":\"[FILTERED]\",\"billingTitle\":\"Longbob Longsen\",\"streetAddress\":\"456 My Street\",\"streetAddress2\":\"Apt 1\",\"country\":\"CA\",\"zipCode\":\"K1C2N6\",\"state\":\"ON\",\"city\":\"Ottawa\",\"phoneNumber\":\"(555)555-5555\",\"selectPhoneType\":4,\"firstName\":\"Longbob\",\"lastName\":\"Longsen\",\"email\":\"joe@example.com\",\"gender\":null,\"dateOfBirth\":null,\"emailSubscription\":null,\"mailSubscription\":null,\"mobileSubscription\":null,\"phoneSubscription\":null,\"giftAidChoice\":null,\"domainName\":1,\"submittedBy\":\"John Doe\"}"
      -> "HTTP/1.0 200 OK\r\n"
      -> "Date: Thu, 15 Feb 2018 23:51:44 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Vary: Authorization\r\n"
      -> "X-Powered-By: PHP/5.6.33\r\n"
      -> "Cache-Control: max-age=1, private, must-revalidate\r\n"
      -> "Expires: Sat, 17 Feb 2018 23:51:44 GMT\r\n"
      -> "Content-Length: 211\r\n"
      -> "Connection: close\r\n"
      -> "Content-Type: application/json\r\n"
      -> "\r\n"
      reading 211 bytes...
      -> ""
      -> "{\"ResponseStatus\":true,\"ResponseCode\":200,\"ResponseMessage\":\"Donation has been processed.\",\"ResponseData\":{\"braintreeMessage\":null,\"transactionId\":\"6m5ksv36\",\"subscriptionId\":null,\"transactionStatus\":\"Success\"}}"
      read 211 bytes
      Conn close
    )
  end

  def successful_purchase_response
    %(
    {"ResponseStatus":true,"ResponseCode":200,"ResponseMessage":"Donation has been processed.","ResponseData":{"braintreeMessage":null,"transactionId":"6m5ksv36","subscriptionId":null,"transactionStatus":"Success"}}
    )
  end

  def failed_purchase_response
    %(
    {"ResponseStatus":true,"ResponseCode":200,"ResponseMessage":"Donation has been failed.","ResponseData":{"braintreeMessage":"Do Not Honor","transactionId":"7f833za3","subscriptionId":null,"transactionStatus":"Fail"}}
    )
  end
end
