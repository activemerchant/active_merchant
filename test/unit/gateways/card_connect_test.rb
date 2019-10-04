require 'test_helper'

class CardConnectTest < Test::Unit::TestCase
  include CommStub
  def setup
    @gateway = CardConnectGateway.new(username: 'username', password: 'password', merchant_id: 'merchand_id')
    @credit_card = credit_card('4788250000121443')
    @declined_card = credit_card('4387751111111053')
    @amount = 100
    @check = check(routing_number: '053000196')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_incorrect_domain
    assert_raise(ArgumentError) {
      CardConnectGateway.new(username: 'username', password: 'password', merchant_id: 'merchand_id', domain: 'www.google.com')
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '363652261392', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_echeck
    @gateway.expects(:ssl_request).returns(successful_echeck_purchase_response)

    response = @gateway.purchase(@amount, @check, @options)
    assert_success response

    assert_equal '010136262668', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_failed_purchase_with_echeck
    @gateway.expects(:ssl_request).returns(failed_echeck_purchase_response)

    response = @gateway.purchase(@amount, check(routing_number: '23433'), @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '363168161558', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway.capture(@amount, '363168161558', @options)
    assert_success response

    assert_equal '363168161558', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, '23221', @options)
    assert_failure response

    assert_equal '23221', response.authorization
    assert response.test?

    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    response = @gateway.refund(@amount, '36366126178', @options)
    assert_success response

    assert_equal '363661261786', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    response = @gateway.refund(@amount, '23221', @options)
    assert_failure response

    assert_equal '23221', response.authorization
    assert response.test?

    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)

    response = @gateway.void('363750268295')
    assert_success response

    assert_equal '363664261982', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void('23221')
    assert_failure response

    assert response.test?

    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal '363272166977', response.authorization
    assert response.test?
  end

  def test_successful_verify_with_failed_void
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_request).returns(failed_verify_response)

    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 'Insufficient funds', response.message
  end

  def test_successful_store
    @gateway.expects(:ssl_request).returns(successful_store_response)
    response = @gateway.store(@credit_card, @options)

    assert_success response
    assert_equal 'Profile Saved', response.message
    assert_equal '1|16700875781344019340', response.authorization
  end

  def test_failed_store
    @gateway.expects(:ssl_request).returns(failed_store_response)
    response = @gateway.store(@credit_card, @options)

    assert_failure response
  end

  def test_successful_unstore
    stub_comms(@gateway, :ssl_request) do
      @gateway.unstore('1|16700875781344019340')
    end.check_request do |verb, url, data, headers|
      assert_equal :delete, verb
      assert_match %r{16700875781344019340/1}, url
    end.respond_with(successful_unstore_response)
  end

  def test_failed_unstore
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_frontendid_is_added_to_post_data_parameters
    @gateway.class.application_id = 'my_app'
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_, _, body|
      assert_equal 'my_app', JSON.parse(body)['frontendid']
    end.respond_with(successful_purchase_response)
  ensure
    @gateway.class.application_id = nil
  end

  private

  def pre_scrubbed
    %q(
      opening connection to fts.cardconnect.com:6443...
      opened
      starting SSL for fts.cardconnect.com:6443...
      SSL established
      <- "PUT /cardconnect/rest/auth HTTP/1.1\r\nAuthorization: Basic dGVzdGluZzp0ZXN0aW5nMTIz\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: fts.cardconnect.com:6443\r\nContent-Length: 298\r\n\r\n"
      <- "{\"orderid\":null,\"ecomind\":\"E\",\"amount\":\"1.00\",\"name\":\"Longbob Longsen\",\"account\":\"4000100011112224\",\"expiry\":\"0918\",\"cvv2\":\"123\",\"currency\":\"USD\",\"address\":\"456 My Street\",\"city\":\"Ottawa\",\"region\":\"ON\",\"country\":\"CA\",\"postal\":\"K1C2N6\",\"phone\":\"(555)555-5555\",\"capture\":\"Y\",\"merchid\":\"496160873888\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "X-FRAME-OPTIONS: DENY\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 281\r\n"
      -> "Date: Fri, 29 Dec 2017 23:51:22 GMT\r\n"
      -> "Server: CardConnect\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: BIGipServerphu-smb-vip_8080=!3EyEfCvmvK/UDgCOaMq7McVUJtfXHaj0/1BWyxbacLNntp1E0Upt2onAMTKRSSu6r6mZaKuZm7N9ais=; path=/; Httponly; Secure\r\n"
      -> "\r\n"
      reading 281 bytes...
      -> "{\"amount\":\"1.00\",\"resptext\":\"Approval\",\"commcard\":\" C \",\"cvvresp\":\"M\",\"batchid\":\"1900941444\",\"avsresp\":\" \",\"respcode\":\"00\",\"merchid\":\"496160873888\",\"token\":\"9405701444882224\",\"authcode\":\"PPS568\",\"respproc\":\"FNOR\",\"retref\":\"363743267882\",\"respstat\":\"A\",\"account\":\"9405701444882224\"}"
      read 281 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to fts.cardconnect.com:6443...
      opened
      starting SSL for fts.cardconnect.com:6443...
      SSL established
      <- "PUT /cardconnect/rest/auth HTTP/1.1\r\nAuthorization: Basic [FILTERED]\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: fts.cardconnect.com:6443\r\nContent-Length: 298\r\n\r\n"
      <- "{\"orderid\":null,\"ecomind\":\"E\",\"amount\":\"1.00\",\"name\":\"Longbob Longsen\",\"account\":\"[FILTERED]\",\"expiry\":\"0918\",\"cvv2\":\"[FILTERED]\",\"currency\":\"USD\",\"address\":\"456 My Street\",\"city\":\"Ottawa\",\"region\":\"ON\",\"country\":\"CA\",\"postal\":\"K1C2N6\",\"phone\":\"(555)555-5555\",\"capture\":\"Y\",\"merchid\":\"[FILTERED]\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "X-FRAME-OPTIONS: DENY\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 281\r\n"
      -> "Date: Fri, 29 Dec 2017 23:51:22 GMT\r\n"
      -> "Server: CardConnect\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: BIGipServerphu-smb-vip_8080=!3EyEfCvmvK/UDgCOaMq7McVUJtfXHaj0/1BWyxbacLNntp1E0Upt2onAMTKRSSu6r6mZaKuZm7N9ais=; path=/; Httponly; Secure\r\n"
      -> "\r\n"
      reading 281 bytes...
      -> "{\"amount\":\"1.00\",\"resptext\":\"Approval\",\"commcard\":\" C \",\"cvvresp\":\"M\",\"batchid\":\"1900941444\",\"avsresp\":\" \",\"respcode\":\"00\",\"merchid\":\"[FILTERED]\",\"token\":\"[FILTERED]\",\"authcode\":\"PPS568\",\"respproc\":\"FNOR\",\"retref\":\"363743267882\",\"respstat\":\"A\",\"account\":\"[FILTERED]\"}"
      read 281 bytes
      Conn close
    )
  end

  def successful_purchase_response
    '{"amount":"1.00","resptext":"Approval","commcard":" C ","cvvresp":"M","batchid":"1900941444","avsresp":" ","respcode":"00","merchid":"496160873888","token":"9405701444882224","authcode":"PPS500","respproc":"FNOR","retref":"363652261392","respstat":"A","account":"9405701444882224"}'
  end

  def successful_echeck_purchase_response
    '{"amount":"1.00","resptext":"Success","cvvresp":"U","batchid":"1900940633","avsresp":"U","respcode":"00","merchid":"542041","token":"9051769384108535","authcode":"GF7PBR","respproc":"PSTR","retref":"010136262668","respstat":"A","account":"9051769384108535"}'
  end

  def failed_echeck_purchase_response
    '{"respproc":"PPS","amount":"0.00","resptext":"Invalid card","cardproc":"PSTR","retref":"010108164081","respstat":"C","respcode":"11","account":"9235405400368535","merchid":"542041","token":"9235405400368535"}'
  end

  def failed_purchase_response
    '{"respproc":"FNOR","amount":"0.00","resptext":"Insufficient funds","cardproc":"FNOR","commcard":" C ","retref":"005533134378","respstat":"C","respcode":"NU","account":"9435885049491053","merchid":"496160873888","token":"9435885049491053"}'
  end

  def successful_authorize_response
    '{"amount":"1.00","resptext":"Approval","commcard":" C ","cvvresp":"M","avsresp":" ","respcode":"00","merchid":"496160873888","token":"9405701444882224","authcode":"PPS454","respproc":"FNOR","retref":"363168161558","respstat":"A","account":"9405701444882224"}'
  end

  def failed_authorize_response
    '{"respproc":"FNOR","amount":"0.00","resptext":"Insufficient funds","cardproc":"FNOR","commcard":" C ","retref":"005737235263","respstat":"C","respcode":"NU","account":"9435885049491053","merchid":"496160873888","token":"9435885049491053"}'
  end

  def successful_capture_response
    '{"respproc":"FNOR","amount":"1.00","resptext":"Approval","setlstat":"Queued for Capture","commcard":" C ","retref":"363168161558","respstat":"A","respcode":"00","batchid":"1900941444","account":"9405701444882224","merchid":"496160873888","token":"9405701444882224"}'
  end

  def failed_capture_response
    '{"respproc":"PPS","resptext":"Txn not found","retref":"23221","respstat":"C","respcode":"29","batchid":"-1","account":""}'
  end

  def successful_refund_response
    '{"respproc":"PPS","amount":"1.00","resptext":"Approval","retref":"363661261786","respstat":"A","respcode":"00","merchid":"496160873888"}'
  end

  def failed_refund_response
    '{"respproc":"PPS","resptext":"Txn not found","retref":"23221","respcode":"29","respstat":"C"}'
  end

  def successful_void_response
    '{"authcode":"REVERS","respproc":"FNOR","amount":"0.00","resptext":"Approval","currency":"USD","retref":"363664261982","respstat":"A","respcode":"00","merchid":"496160873888"}'
  end

  def failed_void_response
    '{"respproc":"PPS","resptext":"Txn not found","retref":"23221","respcode":"29","respstat":"C"}'
  end

  def successful_verify_response
    '{"amount":"0.00","resptext":"Approval","commcard":" C ","cvvresp":"M","avsresp":" ","respcode":"00","merchid":"496160873888","token":"9405701444882224","authcode":"PPS585","respproc":"FNOR","retref":"363272166977","respstat":"A","account":"9405701444882224"}'
  end

  def failed_verify_response
    '{"respproc":"FNOR","amount":"0.00","resptext":"Insufficient funds","cardproc":"FNOR","commcard":" C ","retref":"005101240599","respstat":"C","respcode":"NU","account":"9435885049491053","merchid":"496160873888","token":"9435885049491053"}'
  end

  def successful_store_response
    '{"country":"CA","gsacard":"N","address":"456 My Street Apt 1","resptext":"Profile Saved","city":"Ottawa","acctid":"1","respcode":"09","defaultacct":"Y","accttype":"VISA","token":"9477709629051443","respproc":"PPS","phone":"(555)555-555","profileid":"16700875781344019340","name":"Longbob Longsen","auoptout":"N","postal":"K1C2N6","expiry":"0919","region":"ON","respstat":"A"}'
  end

  def successful_unstore_response
    '{"respproc":"PPS","resptext":"Profile Deleted","respstat":"A","respcode":"08"}'
  end

  def failed_store_response
    # Best-guess based on documentation
    '{"country":"CA","gsacard":"N","address":"456 My Street Apt 1","resptext":"Profile Saved","city":"Ottawa","acctid":"1","respcode":"09","defaultacct":"Y","accttype":"VISA","token":"9477709629051443","respproc":"PPS","phone":"(555)555-555","profileid":"16700875781344019340","name":"Longbob Longsen","auoptout":"N","postal":"K1C2N6","expiry":"0919","region":"ON","respstat":"C"}'
  end

  def failed_unstore_response
    '{"respproc":"PPS","resptext":"Profile not found","respstat":"C","respcode":"96"}'
  end
end
