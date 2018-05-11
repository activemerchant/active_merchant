require 'test_helper'

class CamsTest < Test::Unit::TestCase
  def setup
    @gateway = CamsGateway.new(
      username: 'testintegrationc',
      password: 'password9'
    )

    @credit_card = credit_card('4111111111111111', :month => 5, :year => 10)
    @bad_credit_card = credit_card('4242424245555555', :month => 5, :year => 10)
    @amount = 100

    @options = {
      order_id: Time.now.to_s,
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '2654605773#54321', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @bad_credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @bad_credit_card, @options)
    assert_success response
  end

  def test_successful_capture
    authorization = "12345678#54321"
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert capture = @gateway.capture(@amount, authorization)
    assert_success capture
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(nil, '')
    assert_failure response
  end

  def test_successful_refund
    authorization = "12345678#54321"
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert refund = @gateway.refund(nil, authorization)
    assert_success refund
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_void
    authorization = "12345678#54321"
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert void = @gateway.void(authorization)
    assert_success void
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('')
    assert_failure response
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)

    assert verify = @gateway.verify(@credit_card, @options)
    assert_success verify
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)

    assert verify = @gateway.verify(@bad_credit_card, @options)
    assert_failure verify
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
opening connection to secure.centralams.com:443...
opened
starting SSL for secure.centralams.com:443...
SSL established
<- "POST /gw/api/transact.php HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: secure.centralams.com\r\nContent-Length: 249\r\n\r\n"
<- "amount=1.03&currency=USD&ccnumber=4111111111111111&ccexp=0916&firstname=Longbob&lastname=Longsen&address1=1234 My Street&address2=Apt 1&city=Ottawa&state=ON&zip=K1C2N6&country=US&phone=(555)555-5555&type=&password=password9&username=testintegrationc"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 21 Apr 2015 23:27:05 GMT\r\n"
-> "Server: Apache\r\n"
-> "Content-Length: 132\r\n"
-> "Connection: close\r\n"
-> "Content-Type: text/html; charset=UTF-8\r\n"
-> "\r\n"
reading 132 bytes...
-> "response=1&responsetext=SUCCESS&authcode=123456&transactionid=2654605773&avsresponse=N&cvvresponse=&orderid=&type=&response_code=100"
read 132 bytes
Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
opening connection to secure.centralams.com:443...
opened
starting SSL for secure.centralams.com:443...
SSL established
<- "POST /gw/api/transact.php HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: secure.centralams.com\r\nContent-Length: 249\r\n\r\n"
<- "amount=1.03&currency=USD&ccnumber=[FILTERED]&ccexp=0916&firstname=Longbob&lastname=Longsen&address1=1234 My Street&address2=Apt 1&city=Ottawa&state=ON&zip=K1C2N6&country=US&phone=(555)555-5555&type=&password=[FILTERED]&username=testintegrationc"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 21 Apr 2015 23:27:05 GMT\r\n"
-> "Server: Apache\r\n"
-> "Content-Length: 132\r\n"
-> "Connection: close\r\n"
-> "Content-Type: text/html; charset=UTF-8\r\n"
-> "\r\n"
reading 132 bytes...
-> "response=1&responsetext=SUCCESS&authcode=123456&transactionid=2654605773&avsresponse=N&cvvresponse=&orderid=&type=&response_code=100"
read 132 bytes
Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    %(response=1&responsetext=SUCCESS&authcode=54321&transactionid=2654605773&avsresponse=N&cvvresponse=&orderid=&type=&response_code=100)
  end

  def failed_purchase_response
    %(response=3&responsetext=Invalid Credit Card Number REFID:3154273850&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=&response_code=300)
  end

  def successful_authorize_response
    %(response=1&responsetext=SUCCESS&authcode=123456&transactionid=2655819372&avsresponse=N&cvvresponse=N&orderid=&type=auth&response_code=100)
  end

  def failed_authorize_response
    %(response=3&responsetext=Invalid Credit Card Number REFID:3154292176&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=auth&response_code=300)
  end

  def successful_capture_response
    %(response=1&responsetext=SUCCESS&authcode=123456&transactionid=2655840929&avsresponse=&cvvresponse=&orderid=&type=capture&response_code=100)
  end

  def failed_capture_response
    %(response=3&responsetext=Invalid Transaction ID / Object ID specified:  REFID:3154293596&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=capture&response_code=300)
  end

  def successful_refund_response
    %(response=1&responsetext=SUCCESS&authcode=&transactionid=2655841010&avsresponse=&cvvresponse=&orderid=&type=refund&response_code=100)
  end

  def failed_refund_response
    %(response=3&responsetext=Invalid Transaction ID / Object ID specified:  REFID:3154293755&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=refund&response_code=300)
  end

  def successful_void_response
    %(response=1&responsetext=Transaction Void Successful&authcode=123456&transactionid=2655848058&avsresponse=&cvvresponse=&orderid=&type=void&response_code=100)
  end

  def failed_void_response
    %(response=3&responsetext=Invalid Transaction ID / Object ID specified:  REFID:3154293864&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=void&response_code=300)
  end

  def successful_verify_response
    %(response=1&responsetext=&authcode=&transactionid=2656803675&avsresponse=&cvvresponse=&orderid=&type=verify&response_code=100)
  end

  def failed_verify_response
    %(response=3&responsetext=Invalid Credit Card Number REFID:3154354764&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=verify&response_code=300)
  end
end
