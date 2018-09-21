require 'test_helper'

class Cashnet < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CashnetGateway.new(
      merchant: 'X',
      operator: 'X',
      password: 'test123',
      merchant_gateway_name: 'X'
    )
    @amount = 100
    @credit_card = credit_card
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1234', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Invalid expiration date, no expiration date provided', response.message
    assert_equal '', response.authorization
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.refund(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1234', response.authorization
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Refund amounts should be expressed as positive amounts', response.message
    assert_equal '', response.authorization
  end

  def test_supported_countries
    assert_equal ['US'], CashnetGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :diners_club, :jcb],  CashnetGateway.supported_cardtypes
  end

  def test_add_invoice
    result = {}
    @gateway.send(:add_invoice, result, order_id: '#1001')
    assert_equal '#1001', result[:order_number]
  end

  def test_add_creditcard
    result = {}
    @gateway.send(:add_creditcard, result, @credit_card)
    assert_equal @credit_card.number, result[:cardno]
    assert_equal @credit_card.verification_value, result[:cid]
    assert_equal expected_expiration_date, result[:expdate]
    assert_equal 'Longbob Longsen', result[:card_name_g]
  end

  def test_add_address
    result = {}

    @gateway.send(:add_address, result, billing_address: {address1: '123 Test St.', address2: '5F', city: 'Testville', zip: '12345', state: 'AK'} )

    assert_equal ['addr_g', 'city_g', 'state_g', 'zip_g'], result.stringify_keys.keys.sort
    assert_equal '123 Test St.,5F', result[:addr_g]
    assert_equal 'Testville', result[:city_g]
    assert_equal 'AK', result[:state_g]
    assert_equal '12345', result[:zip_g]
  end

  def test_add_customer_data
    result = {}
    @gateway.send(:add_customer_data, result, email: 'test@test.com')
    assert_equal 'test@test.com', result[:email_g]
  end

  def test_action_meets_minimum_requirements
    params = {
      amount: '1.01',
    }

    @gateway.send(:add_creditcard, params, @credit_card)
    @gateway.send(:add_invoice, params, {})

    assert data = @gateway.send(:post_data, 'SALE', params)
    minimum_requirements.each do |key|
      assert_not_nil(data =~ /#{key}=/)
    end
  end

  def test_successful_purchase_with_fname_and_lname
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, {})
    end.check_request do |method, endpoint, data, headers|
      assert_match(/fname=Longbob/, data)
      assert_match(/lname=Longsen/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_invalid_response
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(invalid_response)

    assert_failure response
    assert_match %r{Unparsable response received}, response.message
  end

  def test_passes_custcode_from_credentials
    gateway = CashnetGateway.new(merchant: 'X', operator: 'X', password: 'test123', merchant_gateway_name: 'X', custcode: 'TheCustCode')
    stub_comms(gateway, :ssl_request) do
      gateway.purchase(@amount, @credit_card, {})
    end.check_request do |method, endpoint, data, headers|
      assert_match(/custcode=TheCustCode/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_allows_custcode_override
    gateway = CashnetGateway.new(merchant: 'X', operator: 'X', password: 'test123', merchant_gateway_name: 'X', custcode: 'TheCustCode')
    stub_comms(gateway, :ssl_request) do
      gateway.purchase(@amount, @credit_card, custcode: 'OveriddenCustCode')
    end.check_request do |method, endpoint, data, headers|
      assert_match(/custcode=OveriddenCustCode/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def expected_expiration_date
    '%02d%02d' % [@credit_card.month, @credit_card.year.to_s[2..4]]
  end

  def minimum_requirements
    %w(command merchant operator station password amount custcode itemcode)
  end

  def successful_refund_response
    '<cngateway>result=0&respmessage=Success&tx=1234</cngateway>'
  end

  def failed_refund_response
    '<cngateway>result=305&respmessage=Failed</cngateway>'
  end

  def successful_purchase_response
    '<cngateway>result=0&respmessage=Success&tx=1234</cngateway>'
  end

  def failed_purchase_response
    '<cngateway>result=7&respmessage=Failed</cngateway>'
  end

  def invalid_response
    'A String without a cngateway tag'
  end

  def pre_scrubbed
    <<-TRANSCRIPT
opening connection to train.cashnet.com:443...
opened
starting SSL for train.cashnet.com:443...
SSL established
<- "POST /givecorpsgateway HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: train.cashnet.com\r\nContent-Length: 364\r\n\r\n"
<- "command=SALE&merchant=GiveCorpGW&operator=givecorp&password=14givecorps&station=WEB&custcode=ActiveMerchant%2F1.76.0&cardno=5454545454545454&cid=123&expdate=1215&card_name_g=Longbob+Longsen&fname=Longbob&lname=Longsen&order_number=c440ec8493f215d21c8a993ceae30129&itemcode=FEE&addr_g=456+My+Street%2CApt+1&city_g=Ottawa&state_g=ON&zip_g=K1C2N6&email_g=&amount=1.00"
-> "HTTP/1.1 302 Found\r\n"
-> "Date: Wed, 03 Jan 2018 17:03:35 GMT\r\n"
-> "Content-Type: text/html; charset=utf-8\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "Connection: close\r\n"
-> "Set-Cookie: AWSALB=5ISjTg8Mez7jS1kEnzY4j5NkQ5bdlwDDNmfzTyEMBmILpb0Tn3k58pUQTGHBj3NUpciP0uqQs7FaAb42YZvt35ndLERGJA0dPQ03iCfrqbneQ+Wm5BhDzMGo5GUT; Expires=Wed, 10 Jan 2018 17:03:35 GMT; Path=/\r\n"
-> "Set-Cookie: AWSALB=bVhwwfJ2D6cI5zB3eapqNStEzF5yX1pXhaJGUBUCa+DZhEgn/TZGxznxIOYB9qKqzkPF4lq/zxWg/tuMBTiY4JGLRjayyhizvHnj2smrnNvr2DLQN7ZjLSh51BzM; Expires=Wed, 10 Jan 2018 17:03:35 GMT; Path=/\r\n"
-> "Cache-Control: private\r\n"
-> "Location: https://train.cashnet.com/cashneti/Gateway/htmlgw.aspx?client=EMARKETVENDOR_DEMO&command=SALE&merchant=GiveCorpGW&operator=givecorp&password=14givecorps&station=WEB&custcode=ActiveMerchant%2f1.76.0&cardno=5454545454545454&cid=123&expdate=1215&card_name_g=Longbob+Longsen&fname=Longbob&lname=Longsen&order_number=c440ec8493f215d21c8a993ceae30129&itemcode=FEE&addr_g=456+My+Street%2cApt+1&city_g=Ottawa&state_g=ON&zip_g=K1C2N6&email_g=&amount=1.00\r\n"
-> "Set-Cookie: ASP.NET_SessionId=; path=/; HttpOnly\r\n"
-> "P3P: CP=\"NOI DSP COR NID NOR\"\r\n"
-> "Set-Cookie: BNI_persistence=0000000000000000000000004d79da0a00005000; Path=/\r\n"
-> "Strict-Transport-Security: max-age=31536000\r\n"
-> "\r\n"
-> "282\r\n"
reading 642 bytes...
-> "<html><head><title>Object moved</title></head><body>\r\n<h2>Object moved to <a href=\"https://train.cashnet.com/cashneti/Gateway/htmlgw.aspx?client=EMARKETVENDOR_DEMO&amp;command=SALE&amp;merchant=GiveCorpGW&amp;operator=givecorp&amp;password=14givecorps&amp;station=WEB&amp;custcode=ActiveMerchant%2f1.76.0&amp;cardno=5454545454545454&amp;cid=123&amp;expdate=1215&amp;card_name_g=Longbob+Longsen&amp;fname=Longbob&amp;lname=Longsen&amp;order_number=c440ec8493f215d21c8a993ceae30129&amp;itemcode=FEE&amp;addr_g=456+My+Street%2cApt+1&amp;city_g=Ottawa&amp;state_g=ON&amp;zip_g=K1C2N6&amp;email_g=&amp;amount=1.00\">here</a>.</h2>\r\n</body></html>\r\n"
read 642 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
opening connection to train.cashnet.com:443...
opened
starting SSL for train.cashnet.com:443...
SSL established
<- "GET /cashneti/Gateway/htmlgw.aspx?client=EMARKETVENDOR_DEMO&command=SALE&merchant=GiveCorpGW&operator=givecorp&password=14givecorps&station=WEB&custcode=ActiveMerchant%2f1.76.0&cardno=5454545454545454&cid=123&expdate=1215&card_name_g=Longbob+Longsen&fname=Longbob&lname=Longsen&order_number=c440ec8493f215d21c8a993ceae30129&itemcode=FEE&addr_g=456+My+Street%2cApt+1&city_g=Ottawa&state_g=ON&zip_g=K1C2N6&email_g=&amount=1.00 HTTP/1.1\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: train.cashnet.com\r\n\r\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Wed, 03 Jan 2018 17:03:35 GMT\r\n"
-> "Content-Type: text/html; charset=utf-8\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "Connection: close\r\n"
-> "Set-Cookie: AWSALB=lFPwFYRnXJHRNmE6NCRAIfHtQadwx4bYJoT5xeAL5AuAXPcm1vYWx5F/s5FBr3GcungifktpWlwIgAmWS29K7YRXTCjk4xmcAnhXS86fpVUVQt4ECwPH2xdv8tf2; Expires=Wed, 10 Jan 2018 17:03:35 GMT; Path=/\r\n"
-> "Set-Cookie: AWSALB=mEfysFNBclo1/9+tTuI/XtHrmVkD89Fh6tAJ3Gl0u2EuLCYTW5VwEq+fVqYG1fEkN02dbhKSkIdM22QvyT6cRccDaUBsYAnOKjg2JlVShJlf+li5tfbrsUDk14jG; Expires=Wed, 10 Jan 2018 17:03:35 GMT; Path=/\r\n"
-> "Cache-Control: private\r\n"
-> "Set-Cookie: ASP.NET_SessionId=3ocslggtk4cdz54unbdnm25o; path=/; HttpOnly\r\n"
-> "P3P: CP=\"NOI DSP COR NID NOR\"\r\n"
-> "Set-Cookie: BNI_persistence=0000000000000000000000004d79da0a00005000; Path=/\r\n"
-> "Strict-Transport-Security: max-age=31536000\r\n"
-> "\r\n"
-> "3a\r\n"
reading 58 bytes...
-> "<cngateway>result=0&tx=77972&busdate=7/25/2017</cngateway>"
read 58 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
TRANSCRIPT
  end

  def post_scrubbed
    <<-SCRUBBED
opening connection to train.cashnet.com:443...
opened
starting SSL for train.cashnet.com:443...
SSL established
<- "POST /givecorpsgateway HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: train.cashnet.com\r\nContent-Length: 364\r\n\r\n"
<- "command=SALE&merchant=GiveCorpGW&operator=givecorp&password=[FILTERED]&station=WEB&custcode=ActiveMerchant%2F1.76.0&cardno=[FILTERED]&cid=[FILTERED]&expdate=1215&card_name_g=Longbob+Longsen&fname=Longbob&lname=Longsen&order_number=c440ec8493f215d21c8a993ceae30129&itemcode=FEE&addr_g=456+My+Street%2CApt+1&city_g=Ottawa&state_g=ON&zip_g=K1C2N6&email_g=&amount=1.00"
-> "HTTP/1.1 302 Found\r\n"
-> "Date: Wed, 03 Jan 2018 17:03:35 GMT\r\n"
-> "Content-Type: text/html; charset=utf-8\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "Connection: close\r\n"
-> "Set-Cookie: AWSALB=5ISjTg8Mez7jS1kEnzY4j5NkQ5bdlwDDNmfzTyEMBmILpb0Tn3k58pUQTGHBj3NUpciP0uqQs7FaAb42YZvt35ndLERGJA0dPQ03iCfrqbneQ+Wm5BhDzMGo5GUT; Expires=Wed, 10 Jan 2018 17:03:35 GMT; Path=/\r\n"
-> "Set-Cookie: AWSALB=bVhwwfJ2D6cI5zB3eapqNStEzF5yX1pXhaJGUBUCa+DZhEgn/TZGxznxIOYB9qKqzkPF4lq/zxWg/tuMBTiY4JGLRjayyhizvHnj2smrnNvr2DLQN7ZjLSh51BzM; Expires=Wed, 10 Jan 2018 17:03:35 GMT; Path=/\r\n"
-> "Cache-Control: private\r\n"
-> "Location: https://train.cashnet.com/cashneti/Gateway/htmlgw.aspx?client=EMARKETVENDOR_DEMO&command=SALE&merchant=GiveCorpGW&operator=givecorp&password=[FILTERED]&station=WEB&custcode=ActiveMerchant%2f1.76.0&cardno=[FILTERED]&cid=[FILTERED]&expdate=1215&card_name_g=Longbob+Longsen&fname=Longbob&lname=Longsen&order_number=c440ec8493f215d21c8a993ceae30129&itemcode=FEE&addr_g=456+My+Street%2cApt+1&city_g=Ottawa&state_g=ON&zip_g=K1C2N6&email_g=&amount=1.00\r\n"
-> "Set-Cookie: ASP.NET_SessionId=; path=/; HttpOnly\r\n"
-> "P3P: CP=\"NOI DSP COR NID NOR\"\r\n"
-> "Set-Cookie: BNI_persistence=0000000000000000000000004d79da0a00005000; Path=/\r\n"
-> "Strict-Transport-Security: max-age=31536000\r\n"
-> "\r\n"
-> "282\r\n"
reading 642 bytes...
-> "<html><head><title>Object moved</title></head><body>\r\n<h2>Object moved to <a href=\"https://train.cashnet.com/cashneti/Gateway/htmlgw.aspx?client=EMARKETVENDOR_DEMO&amp;command=SALE&amp;merchant=GiveCorpGW&amp;operator=givecorp&amp;password=[FILTERED]&amp;station=WEB&amp;custcode=ActiveMerchant%2f1.76.0&amp;cardno=[FILTERED]&amp;cid=[FILTERED]&amp;expdate=1215&amp;card_name_g=Longbob+Longsen&amp;fname=Longbob&amp;lname=Longsen&amp;order_number=c440ec8493f215d21c8a993ceae30129&amp;itemcode=FEE&amp;addr_g=456+My+Street%2cApt+1&amp;city_g=Ottawa&amp;state_g=ON&amp;zip_g=K1C2N6&amp;email_g=&amp;amount=1.00\">here</a>.</h2>\r\n</body></html>\r\n"
read 642 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
opening connection to train.cashnet.com:443...
opened
starting SSL for train.cashnet.com:443...
SSL established
<- "GET /cashneti/Gateway/htmlgw.aspx?client=EMARKETVENDOR_DEMO&command=SALE&merchant=GiveCorpGW&operator=givecorp&password=[FILTERED]&station=WEB&custcode=ActiveMerchant%2f1.76.0&cardno=[FILTERED]&cid=[FILTERED]&expdate=1215&card_name_g=Longbob+Longsen&fname=Longbob&lname=Longsen&order_number=c440ec8493f215d21c8a993ceae30129&itemcode=FEE&addr_g=456+My+Street%2cApt+1&city_g=Ottawa&state_g=ON&zip_g=K1C2N6&email_g=&amount=1.00 HTTP/1.1\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: train.cashnet.com\r\n\r\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Wed, 03 Jan 2018 17:03:35 GMT\r\n"
-> "Content-Type: text/html; charset=utf-8\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "Connection: close\r\n"
-> "Set-Cookie: AWSALB=lFPwFYRnXJHRNmE6NCRAIfHtQadwx4bYJoT5xeAL5AuAXPcm1vYWx5F/s5FBr3GcungifktpWlwIgAmWS29K7YRXTCjk4xmcAnhXS86fpVUVQt4ECwPH2xdv8tf2; Expires=Wed, 10 Jan 2018 17:03:35 GMT; Path=/\r\n"
-> "Set-Cookie: AWSALB=mEfysFNBclo1/9+tTuI/XtHrmVkD89Fh6tAJ3Gl0u2EuLCYTW5VwEq+fVqYG1fEkN02dbhKSkIdM22QvyT6cRccDaUBsYAnOKjg2JlVShJlf+li5tfbrsUDk14jG; Expires=Wed, 10 Jan 2018 17:03:35 GMT; Path=/\r\n"
-> "Cache-Control: private\r\n"
-> "Set-Cookie: ASP.NET_SessionId=3ocslggtk4cdz54unbdnm25o; path=/; HttpOnly\r\n"
-> "P3P: CP=\"NOI DSP COR NID NOR\"\r\n"
-> "Set-Cookie: BNI_persistence=0000000000000000000000004d79da0a00005000; Path=/\r\n"
-> "Strict-Transport-Security: max-age=31536000\r\n"
-> "\r\n"
-> "3a\r\n"
reading 58 bytes...
-> "<cngateway>result=0&tx=77972&busdate=7/25/2017</cngateway>"
read 58 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
SCRUBBED
  end
end
