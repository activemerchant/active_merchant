require 'test_helper'

class ProPayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = ProPayGateway.new(cert_str: 'certStr')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '16', response.authorization
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '58', response.error_code
    assert_equal 'Credit card declined - Insufficient funds', response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '24', response.authorization
    assert_equal 'Success', response.message
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '58', response.error_code
    assert_equal 'Credit card declined - Insufficient funds', response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, "auth", @options)
    assert_success response

    assert_equal '24', response.authorization
    assert_equal 'Success', response.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, "invalid-auth", @options)
    assert_failure response
    assert_equal '51', response.error_code
    assert_equal 'Invalid transNum and/or Unable to act perform actions on transNum due to funding', response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'auth', @options)
    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, 'invalid-auth', @options)
    assert_failure response
    assert_equal 'Invalid transNum and/or Unable to act perform actions on transNum due to funding', response.message
  end

  def test_successful_void
    response = stub_comms do
      @gateway.void('auth', @options)
    end.check_request do |endpoint, data, headers|
      assert_match(%r(<transType>07</transType>), data)
    end.respond_with(successful_void_response)

    assert_success response
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void('invalid-auth', @options)
    end.check_request do |endpoint, data, headers|
      assert_match(%r(<transType>07</transType>), data)
    end.respond_with(failed_void_response)

    assert_failure response
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, failed_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response

    assert_equal '103', response.authorization
    assert_equal 'Success', response.message
  end

  def test_failed_credit
    @gateway.expects(:ssl_post).returns(failed_credit_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid ccNum', response.message
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal "58", response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-RESPONSE
opening connection to xmltest.propay.com:443...
opened
starting SSL for xmltest.propay.com:443...
SSL established
<- "POST /API/PropayAPI.aspx HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: xmltest.propay.com\r\nContent-Length: 547\r\n\r\n"
<- "<?xml version=\"1.0\"?>\n<XMLRequest>\n  <certStr>5ab9cddef2e4911b77e0c4ffb70f03</certStr>\n  <class>partner</class>\n  <XMLTrans>\n    <amount>100</amount>\n    <currencyCode>USD</currencyCode>\n    <ccNum>4747474747474747</ccNum>\n    <expDate>0918</expDate>\n    <CVV2>999</CVV2>\n    <cardholderName>Longbob Longsen</cardholderName>\n    <addr>456 My Street</addr>\n    <aptNum>Apt 1</aptNum>\n    <city>Ottawa</city>\n    <state>ON</state>\n    <zip>K1C2N6</zip>\n    <accountNum>32287391</accountNum>\n    <transType>04</transType>\n  </XMLTrans>\n</XMLRequest>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: max-age=0,no-cache,no-store,must-revalidate\r\n"
-> "Pragma: no-cache\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Expires: Thu, 01 Jan 1970 00:00:00 GMT\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Server: Microsoft-IIS/7.5\r\n"
-> "Set-Cookie: ASP.NET_SessionId=hn1orxwu31yeoym5fkdhac4o; path=/; secure; HttpOnly\r\n"
-> "Set-Cookie: sessionValidation=1a1d69b6-6e53-408b-b054-602593da00e7; path=/; secure; HttpOnly\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "Date: Tue, 25 Apr 2017 19:44:03 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 343\r\n"
-> "\r\n"
reading 343 bytes...
-> ""
read 343 bytes
Conn close
    RESPONSE
  end

  def post_scrubbed
    <<-POST_SCRUBBED
opening connection to xmltest.propay.com:443...
opened
starting SSL for xmltest.propay.com:443...
SSL established
<- "POST /API/PropayAPI.aspx HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: xmltest.propay.com\r\nContent-Length: 547\r\n\r\n"
<- "<?xml version=\"1.0\"?>\n<XMLRequest>\n  <certStr>[FILTERED]</certStr>\n  <class>partner</class>\n  <XMLTrans>\n    <amount>100</amount>\n    <currencyCode>USD</currencyCode>\n    <ccNum>[FILTERED]</ccNum>\n    <expDate>0918</expDate>\n    <CVV2>[FILTERED]</CVV2>\n    <cardholderName>Longbob Longsen</cardholderName>\n    <addr>456 My Street</addr>\n    <aptNum>Apt 1</aptNum>\n    <city>Ottawa</city>\n    <state>ON</state>\n    <zip>K1C2N6</zip>\n    <accountNum>32287391</accountNum>\n    <transType>04</transType>\n  </XMLTrans>\n</XMLRequest>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: max-age=0,no-cache,no-store,must-revalidate\r\n"
-> "Pragma: no-cache\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Expires: Thu, 01 Jan 1970 00:00:00 GMT\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Server: Microsoft-IIS/7.5\r\n"
-> "Set-Cookie: ASP.NET_SessionId=hn1orxwu31yeoym5fkdhac4o; path=/; secure; HttpOnly\r\n"
-> "Set-Cookie: sessionValidation=1a1d69b6-6e53-408b-b054-602593da00e7; path=/; secure; HttpOnly\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "Date: Tue, 25 Apr 2017 19:44:03 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 343\r\n"
-> "\r\n"
reading 343 bytes...
-> ""
read 343 bytes
Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    %(
      <?xml version="1.0"?><XMLResponse><XMLTrans><transType>04</transType><status>00</status><accountNum>32287391</accountNum><transNum>16</transNum><authCode>A11111</authCode><AVS>T</AVS><CVV2Resp>M</CVV2Resp><responseCode>0</responseCode><NetAmt>67</NetAmt><GrossAmt>100</GrossAmt><GrossAmtLessNetAmt>33</GrossAmtLessNetAmt><PerTransFee>30</PerTransFee><Rate>3.25</Rate></XMLTrans></XMLResponse>
    )
  end

  def failed_purchase_response
    %(
      <?xml version="1.0"?><XMLResponse><XMLTrans><transType>04</transType><status>58</status><accountNum>32287391</accountNum><transNum>22</transNum><authCode>A11111</authCode><AVS>T</AVS><responseCode>51</responseCode></XMLTrans></XMLResponse>
    )
  end

  def successful_authorize_response
    %(
      <?xml version="1.0"?><XMLResponse><XMLTrans><transType>05</transType><status>00</status><accountNum>32287391</accountNum><transNum>24</transNum><authCode>A11111</authCode><AVS>T</AVS><CVV2Resp>M</CVV2Resp><responseCode>0</responseCode><NetAmt>0</NetAmt><GrossAmt>100</GrossAmt><GrossAmtLessNetAmt>100</GrossAmtLessNetAmt><PerTransFee>0</PerTransFee><Rate>0.00</Rate></XMLTrans></XMLResponse>
    )
  end

  def failed_authorize_response
    %(
      <?xml version="1.0"?><XMLResponse><XMLTrans><transType>05</transType><status>58</status><accountNum>32287391</accountNum><transNum>26</transNum><authCode>A11111</authCode><AVS>T</AVS><responseCode>51</responseCode></XMLTrans></XMLResponse>
    )
  end

  def successful_capture_response
    %(
      <?xml version="1.0"?><XMLResponse><XMLTrans><transType>06</transType><status>00</status><accountNum>32287391</accountNum><transNum>24</transNum><NetAmt>67</NetAmt><GrossAmt>100</GrossAmt><GrossAmtLessNetAmt>33</GrossAmtLessNetAmt><PerTransFee>30</PerTransFee><Rate>3.25</Rate></XMLTrans></XMLResponse>
    )
  end

  def failed_capture_response
    %(
      <?xml version="1.0"?><XMLResponse><XMLTrans><transType>06</transType><status>51</status><accountNum>32287391</accountNum></XMLTrans></XMLResponse>
    )
  end

  def successful_refund_response
    %(
      <?xml version="1.0"?><XMLResponse><XMLTrans><transType>07</transType><status>00</status><accountNum>32287391</accountNum><transNum>5</transNum></XMLTrans></XMLResponse>
    )
  end

  def failed_refund_response
    %(
      <?xml version="1.0"?><XMLResponse><XMLTrans><transType>07</transType><status>51</status><accountNum>32287391</accountNum></XMLTrans></XMLResponse>
    )
  end

  def successful_void_response
    %(
      <?xml version="1.0"?><XMLResponse><XMLTrans><transType>07</transType><status>00</status><accountNum>32287391</accountNum><transNum>44</transNum></XMLTrans></XMLResponse>
    )
  end

  def failed_void_response
    %(
      <?xml version="1.0"?><XMLResponse><XMLTrans><transType>07</transType><status>51</status><accountNum>32287391</accountNum></XMLTrans></XMLResponse>
    )
  end

  def successful_credit_response
    %(
      <?xml version="1.0"?><XMLResponse><XMLTrans><transType>35</transType><status>00</status><accountNum>32287391</accountNum><transNum>103</transNum></XMLTrans></XMLResponse>
    )
  end

  def failed_credit_response
    %(
      <?xml version="1.0"?><XMLResponse><XMLTrans><transType>35</transType><status>48</status><accountNum>32287391</accountNum></XMLTrans></XMLResponse>
    )
  end
end
