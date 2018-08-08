require 'test_helper'

class PaymentwallTest < Test::Unit::TestCase
  def setup
    @gateway = PaymentwallGateway.new(public_key: 'login', secret_key: 'password')
    @credit_card = credit_card
    @declined_card = credit_card('4242 4242 4242 4242', verification_value: '111')
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
      ip: '172.217.3.78',
      browser_domain: 'example.com',
      email: 'you@gmail.com',
      plan: 'Example'
    }
  end

  def test_successful_purchase
    @gateway.expects(:api_request).returns(successful_card_add_response)
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    
    assert_success response
    assert_equal 'CHARGED', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:api_request).returns(successful_card_add_response)
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    response = @gateway.purchase(@amount, @declined_card, @options)
    
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_cvc], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:api_request).returns(successful_card_add_response)
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    
    assert_success response
    assert_equal 'AUTHORIZED', response.message
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:api_request).returns(successful_card_add_response)
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @declined_card, @options)

    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_capture 
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    response = @gateway.capture(@amount, 'AUTHCODE', @options)
    
    assert_success response
    assert_equal 'CHARGED', response.message
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    response = @gateway.capture(@amount, 'AUTHCODE', @options)

    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to api.paymentwall.com:443...
      opened
      starting SSL for api.paymentwall.com:443...
      SSL established
      <- "POST /api/brick/token HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nX-Apikey: t_83b42c0a718906a0c0b765150eb628\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: api.paymentwall.com\r\nContent-Length: 141\r\n\r\n"
      <- "card%5Bcvv%5D=123&card%5Bexp_month%5D=9&card%5Bexp_year%5D=2019&card%5Bnumber%5D=4242424242424242&public_key=t_b87c1ad071be28925a577194fbf858"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Wed, 08 Aug 2018 04:42:57 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 186\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Set-Cookie: PHPSESSID=obfi48lkd5kt7povcf0uhfdg70; path=/\r\n"
      -> "Expires: Thu, 19 Nov 1981 08:52:00 GMT\r\n"
      -> "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
      -> "Pragma: no-cache\r\n"
      -> "\r\n"
      reading 186 bytes...
      -> "{\"type\":\"token\",\"token\":\"ot_af6e51cdbda989dee6525382a182a237\",\"test\":1,\"active\":1,\"expires_in\":300,\"card\":{\"type\":\"Visa\",\"last4\":\"4242\",\"bin\":\"424242\",\"exp_month\":\"9\",\"exp_year\":\"2019\"}}"
      read 186 bytes
      Conn close
      opening connection to api.paymentwall.com:443...
      opened
      starting SSL for api.paymentwall.com:443...
      SSL established
      <- "POST /api/brick/charge HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nX-Apikey: t_83b42c0a718906a0c0b765150eb628\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: api.paymentwall.com\r\nContent-Length: 606\r\n\r\n"
      <- "amount=1.00&billing_address%5Baddress1%5D=456+My+Street&billing_address%5Baddress2%5D=Apt+1&billing_address%5Bcity%5D=Ottawa&billing_address%5Bcompany%5D=Widgets+Inc&billing_address%5Bcountry%5D=CA&billing_address%5Bfax%5D=%28555%29555-6666&billing_address%5Bname%5D=Jim+Smith&billing_address%5Bphone%5D=%28555%29555-5555&billing_address%5Bstate%5D=ON&billing_address%5Bzip%5D=K1C2N6&browser_domain=example.com&currency=USD&customer%5Bfirstname%5D=Longbob&customer%5Blastname%5D=Longsen&description=Store+Purchase&email=you%40gmail.com&ip=172.217.3.78&plan=Example&token=ot_af6e51cdbda989dee6525382a182a237"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Wed, 08 Aug 2018 04:42:58 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 406\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: PHPSESSID=bpnj77bonh3gmj8nge2um41f70; path=/\r\n"
      -> "Expires: Thu, 19 Nov 1981 08:52:00 GMT\r\n"
      -> "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
      -> "Pragma: no-cache\r\n"
      -> "\r\n"
      reading 406 bytes...
      -> "{\"object\":\"charge\",\"id\":\"13551533703378_test\",\"created\":1533703378,\"amount\":\"1.00\",\"currency\":\"USD\",\"refunded\":false,\"captured\":true,\"risk\":\"approved\",\"card\":{\"last4\":\"4242\",\"type\":\"VISA\",\"exp_month\":\"9\",\"exp_year\":\"2019\",\"country\":\"US\",\"name\":\"TEST PAYER\",\"token\":\"t_b0dbd9ad05765ea73afe92a57b03c1\"},\"secure\":false,\"support_link\":\"http:\\/\\/example.com\",\"test\":1,\"amount_paid\":\"1.00\",\"currency_paid\":\"USD\"}"
      read 406 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to api.paymentwall.com:443...
      opened
      starting SSL for api.paymentwall.com:443...
      SSL established
      <- "POST /api/brick/token HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nX-Apikey: [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: api.paymentwall.com\r\nContent-Length: 141\r\n\r\n"
      <- "card%5Bcvv%5D=[FILTERED]&card%5Bexp_month%5D=[FILTERED]&card%5Bexp_year%5D=[FILTERED]&card%5Bnumber%5D=[FILTERED]&public_key=[FILTERED]"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Wed, 08 Aug 2018 04:42:57 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 186\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Set-Cookie: PHPSESSID=obfi48lkd5kt7povcf0uhfdg70; path=/\r\n"
      -> "Expires: Thu, 19 Nov 1981 08:52:00 GMT\r\n"
      -> "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
      -> "Pragma: no-cache\r\n"
      -> "\r\n"
      reading 186 bytes...
      -> "{\"type\":\"token\",\"token\":\"ot_af6e51cdbda989dee6525382a182a237\",\"test\":1,\"active\":1,\"expires_in\":300,\"card\":{\"type\":\"Visa\",\"last4\":\"4242\",\"bin\":\"424242\",\"exp_month\":\"9\",\"exp_year\":\"2019\"}}"
      read 186 bytes
      Conn close
      opening connection to api.paymentwall.com:443...
      opened
      starting SSL for api.paymentwall.com:443...
      SSL established
      <- "POST /api/brick/charge HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nX-Apikey: [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: api.paymentwall.com\r\nContent-Length: 606\r\n\r\n"
      <- "amount=1.00&billing_address%5Baddress1%5D=456+My+Street&billing_address%5Baddress2%5D=Apt+1&billing_address%5Bcity%5D=Ottawa&billing_address%5Bcompany%5D=Widgets+Inc&billing_address%5Bcountry%5D=CA&billing_address%5Bfax%5D=%28555%29555-6666&billing_address%5Bname%5D=Jim+Smith&billing_address%5Bphone%5D=%28555%29555-5555&billing_address%5Bstate%5D=ON&billing_address%5Bzip%5D=K1C2N6&browser_domain=example.com&currency=USD&customer%5Bfirstname%5D=Longbob&customer%5Blastname%5D=Longsen&description=Store+Purchase&email=you%40gmail.com&ip=172.217.3.78&plan=Example&token=[FILTERED]"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Wed, 08 Aug 2018 04:42:58 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 406\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: PHPSESSID=bpnj77bonh3gmj8nge2um41f70; path=/\r\n"
      -> "Expires: Thu, 19 Nov 1981 08:52:00 GMT\r\n"
      -> "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
      -> "Pragma: no-cache\r\n"
      -> "\r\n"
      reading 406 bytes...
      -> "{\"object\":\"charge\",\"id\":\"13551533703378_test\",\"created\":1533703378,\"amount\":\"1.00\",\"currency\":\"USD\",\"refunded\":false,\"captured\":true,\"risk\":\"approved\",\"card\":{\"last4\":\"4242\",\"type\":\"VISA\",\"exp_month\":\"9\",\"exp_year\":\"2019\",\"country\":\"US\",\"name\":\"TEST PAYER\",\"token\":\"t_b0dbd9ad05765ea73afe92a57b03c1\"},\"secure\":false,\"support_link\":\"http:\/\/example.com\",\"test\":1,\"amount_paid\":\"1.00\",\"currency_paid\":\"USD\"}"
      read 406 bytes
      Conn close
    )
  end

  def successful_card_add_response
    %(
      {\"type\":\"token\",\"token\":\"ot_fab7b3451562fa22fe62fb7efe11dc9f\",\"test\":1,\"active\":1,\"expires_in\":300,\"card\":{\"type\":\"Visa\",\"last4\":\"4242\",\"bin\":\"424242\",\"exp_month\":\"01\",\"exp_year\":\"2021\"}}
    )
  end

  def successful_purchase_response
    %(
      {\"object\":\"charge\",\"id\":\"40301533741501_test\",\"created\":1533741501,\"amount\":\"9.99\",\"currency\":\"USD\",\"refunded\":false,\"captured\":true,\"risk\":\"approved\",\"card\":{\"last4\":\"4242\",\"type\":\"VISA\",\"exp_month\":\"01\",\"exp_year\":\"2017\",\"country\":\"US\",\"name\":\"TEST PAYER\",\"token\":\"t_e65ddca6c3bfc4aaa31662c89e2b56\"},\"secure\":false,\"support_link\":\"http:\/\/example.com\",\"test\":1,\"amount_paid\":\"9.99\",\"currency_paid\":\"USD\"}
    )
  end

  def failed_purchase_response
    %(
      {\"type\":\"Error\",\"object\":\"Error\",\"error\":\"Please ensure the CVV\/CVC number is correct before retrying the transaction.\",\"code\":3014}
    )
  end

  def successful_authorize_response
    %(
      {\"object\":\"charge\",\"id\":\"97141533750229_test\",\"created\":1533750229,\"amount\":\"9.99\",\"currency\":\"USD\",\"refunded\":false,\"captured\":false,\"risk\":\"approved\",\"card\":{\"last4\":\"4242\",\"type\":\"VISA\",\"exp_month\":\"01\",\"exp_year\":\"2021\",\"country\":\"US\",\"name\":\"TEST PAYER\",\"token\":\"t_e65ddca6c3bfc4aaa31662c89e2b56\"},\"secure\":false,\"support_link\":\"http:\/\/example.com\",\"test\":1,\"amount_paid\":\"9.99\",\"currency_paid\":\"USD\"}
    )
  end

  def failed_authorize_response
    %(
      {\"type\":\"Error\",\"object\":\"Error\",\"error\":\"One-time token is invalid.\",\"code\":3112}
    )
  end

  def successful_capture_response
    %(
      {\"object\":\"charge\",\"id\":\"13351533751044_test\",\"created\":1533751045,\"amount\":\"9.99\",\"currency\":\"USD\",\"refunded\":false,\"captured\":true,\"risk\":\"approved\",\"card\":{\"last4\":\"4242\",\"type\":\"VISA\",\"exp_month\":\"01\",\"exp_year\":\"2021\",\"country\":\"US\",\"name\":\"TEST PAYER\",\"token\":\"t_e65ddca6c3bfc4aaa31662c89e2b56\"},\"secure\":false,\"support_link\":\"http:\/\/example.com\",\"test\":1,\"amount_paid\":\"9.99\",\"currency_paid\":\"USD\"}
    )
  end

  def failed_capture_response
    %(
      {\"type\":\"Error\",\"object\":\"Error\",\"error\":\"The transaction was declined. Please contact your bank to check your available balance\",\"code\":3011}
    )
  end

end
