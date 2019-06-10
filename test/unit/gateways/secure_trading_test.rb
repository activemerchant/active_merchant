require 'test_helper'

class SecureTradingTest < Test::Unit::TestCase
  def setup
    @gateway = SecureTradingGateway.new(
      user_id: 'user@test.com',
      api_key: 'api_key',
      site_id: 'site_id')

    @credit_card = credit_card
    @declined_card = credit_card('4000000000000002')
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

    assert_equal '2-9-4019695', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '5-9-4895083', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '5-9-4895083', response.authorization
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to webservices.securetrading.net:443...
      opened
      starting SSL for webservices.securetrading.net:443...
      SSL established
      <- "POST /xml/ HTTP/1.1\r\nContent-Type: application/xml\r\nAuthorization: Basic ZXZlcmdpdmluZ0Bjb21taXR0ZWRnaXZpbmcudWsubmV0OktNKiVraiM3\r\nContent-Length: 989\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: webservices.securetrading.net\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<requestblock version=\"3.67\">\n  <alias>evergiving@committedgiving.uk.net</alias>\n  <request type=\"ACCOUNTCHECK\">\n    <operation>\n      <sitereference>test_phrasisrnib35296</sitereference>\n      <authmethod>FINAL</authmethod>\n      <accounttypedescription>ECOM</accounttypedescription>\n    </operation>\n    <merchant>\n      <orderreference>8be9c12d-8dd5-4539-b6ae-6d8b3212de65</orderreference>\n    </merchant>\n    <billing>\n      <amount currencycode=\"GBP\">0</amount>\n      <email/>\n      <town>Ottawa</town>\n      <postcode>K1C2N6</postcode>\n      <premise>456</premise>\n      <street>456 My Street</street>\n      <country>CA</country>\n      <name>\n        <prefix/>\n        <first>Robo</first>\n        <middle/>\n        <last/>\n      </name>\n      <payment type=\"VISA\">\n        <expirydate>09/2020</expirydate>\n        <securitycode>123</securitycode>\n        <pan>4000100011112224</pan>\n      </payment>\n    </billing>\n  </request>\n</requestblock>\n"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 10 Jun 2019 14:23:51 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Strict-Transport-Security: max-age=63072000; includeSubdomains;\r\n"
      -> "X-Frame-Options: DENY\r\n"
      -> "X-XSS-Protection: 1\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Referrer-Policy: strict-origin-when-cross-origin\r\n"
      -> "Content-Security-Policy: default-src 'self' 'unsafe-inline'; block-all-mixed-content\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: text/xml\r\n"
      -> "\r\n"
      -> "281\r\n"
      reading 641 bytes...
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to webservices.securetrading.net:443...
      opened
      starting SSL for webservices.securetrading.net:443...
      SSL established
      <- "POST /xml/ HTTP/1.1\r\nContent-Type: application/xml\r\nAuthorization: Basic [FILTERED]\r\nContent-Length: 989\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: webservices.securetrading.net\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<requestblock version=\"3.67\">\n  <alias>[FILTERED]</alias>\n  <request type=\"ACCOUNTCHECK\">\n    <operation>\n      <sitereference>test_phrasisrnib35296</sitereference>\n      <authmethod>FINAL</authmethod>\n      <accounttypedescription>ECOM</accounttypedescription>\n    </operation>\n    <merchant>\n      <orderreference>8be9c12d-8dd5-4539-b6ae-6d8b3212de65</orderreference>\n    </merchant>\n    <billing>\n      <amount currencycode=\"GBP\">0</amount>\n      <email/>\n      <town>Ottawa</town>\n      <postcode>K1C2N6</postcode>\n      <premise>456</premise>\n      <street>456 My Street</street>\n      <country>CA</country>\n      <name>\n        <prefix/>\n        <first>Robo</first>\n        <middle/>\n        <last/>\n      </name>\n      <payment type=\"VISA\">\n        <expirydate>09/2020</expirydate>\n        <securitycode>[FILTERED]</securitycode>\n        <pan>400010[FILTERED]2224</pan>\n      </payment>\n    </billing>\n  </request>\n</requestblock>\n"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 10 Jun 2019 14:23:51 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Strict-Transport-Security: max-age=63072000; includeSubdomains;\r\n"
      -> "X-Frame-Options: DENY\r\n"
      -> "X-XSS-Protection: 1\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Referrer-Policy: strict-origin-when-cross-origin\r\n"
      -> "Content-Security-Policy: default-src 'self' 'unsafe-inline'; block-all-mixed-content\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: text/xml\r\n"
      -> "\r\n"
      -> "281\r\n"
      reading 641 bytes...
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<-eos
      <?xml version='1.0' encoding='utf-8'?>
      <responseblock version="3.67">
        <requestreference>W2-81ekfm9p</requestreference>
        <response type="AUTH">
          <merchant>
            <orderreference>8be9c12d-8dd5-4539-b6ae-6d8b3212de65</orderreference>
            <operatorname>evergiving@committedgiving.uk.net</operatorname>
            <tid>27882788</tid>
            <merchantnumber>00000000</merchantnumber>
            <merchantcountryiso2a>GB</merchantcountryiso2a>
          </merchant>
          <transactionreference>2-9-4019695</transactionreference>
          <timestamp>2019-06-10 13:12:15</timestamp>
          <acquirerresponsecode>00</acquirerresponsecode>
          <operation>
            <splitfinalnumber>1</splitfinalnumber>
            <accounttypedescription>ECOM</accounttypedescription>
          </operation>
          <settlement>
            <settleduedate>2019-06-10</settleduedate>
            <settlestatus>0</settlestatus>
          </settlement>
          <billing>
            <amount currencycode="GBP">100</amount>
            <payment type="VISA">
              <issuer>SecureTrading Test Issuer1</issuer>
              <pan>400010######2224</pan>
              <issuercountry>ZZ</issuercountry>
            </payment>
            <dcc enabled="0"/>
          </billing>
          <authcode>TEST56</authcode>
          <live>0</live>
          <error>
            <message>Ok</message>
            <code>0</code>
          </error>
          <security>
            <postcode>4</postcode>
            <securitycode>2</securitycode>
            <address>4</address>
          </security>
        </response>
        <secrand>X3Z1IVlh</secrand>
      </responseblock>
    eos
  end

  def failed_purchase_response
    <<-eos
      <?xml version='1.0' encoding='utf-8'?>
      <responseblock version="3.67">
        <requestreference>W6-95782a9t</requestreference>
        <response type="AUTH">
          <merchant>
            <orderreference>8be9c12d-8dd5-4539-b6ae-6d8b3212de65</orderreference>
            <operatorname>evergiving@committedgiving.uk.net</operatorname>
            <tid>27882788</tid>
            <merchantnumber>00000000</merchantnumber>
            <merchantcountryiso2a>GB</merchantcountryiso2a>
          </merchant>
          <transactionreference>6-9-4618280</transactionreference>
          <timestamp>2019-06-10 13:18:41</timestamp>
          <acquirerresponsecode>05</acquirerresponsecode>
          <operation>
            <splitfinalnumber>1</splitfinalnumber>
            <accounttypedescription>ECOM</accounttypedescription>
          </operation>
          <settlement>
            <settleduedate>2019-06-10</settleduedate>
            <settlestatus>3</settlestatus>
          </settlement>
          <billing>
            <amount currencycode="GBP">100</amount>
            <payment type="VISA">
              <issuer>SecureTrading Test Issuer1</issuer>
              <pan>400000######0002</pan>
              <issuercountry>ZZ</issuercountry>
            </payment>
            <dcc enabled="0"/>
          </billing>
          <authcode>DECLINED</authcode>
          <live>0</live>
          <error>
            <message>Decline</message>
            <code>70000</code>
          </error>
          <security>
            <postcode>1</postcode>
            <securitycode>1</securitycode>
            <address>1</address>
          </security>
        </response>
        <secrand>iotdAEPbaN0</secrand>
      </responseblock>
    eos
  end

  def successful_authorize_response
    <<-eos
      <?xml version='1.0' encoding='utf-8'?>
      <responseblock version="3.67">
        <requestreference>W5-47y3f0f5</requestreference>
        <response type="ACCOUNTCHECK">
          <merchant>
            <tid>27882788</tid>
            <merchantnumber>00000000</merchantnumber>
            <merchantcountryiso2a>GB</merchantcountryiso2a>
            <orderreference>8be9c12d-8dd5-4539-b6ae-6d8b3212de65</orderreference>
            <operatorname>evergiving@committedgiving.uk.net</operatorname>
          </merchant>
          <transactionreference>5-9-4895083</transactionreference>
          <billing>
            <amount currencycode="GBP">0</amount>
            <payment type="VISA">
              <pan>400010######2224</pan>
              <issuercountry>ZZ</issuercountry>
              <issuer>SecureTrading Test Issuer1</issuer>
            </payment>
            <dcc enabled="0"/>
          </billing>
          <timestamp>2019-06-10 13:40:19</timestamp>
          <error>
            <message>Ok</message>
            <code>0</code>
          </error>
          <acquirerresponsecode>00</acquirerresponsecode>
          <live>0</live>
          <authcode>TEST03</authcode>
          <operation>
            <accounttypedescription>ECOM</accounttypedescription>
          </operation>
          <settlement>
            <settleduedate>2019-06-10</settleduedate>
            <settlestatus>0</settlestatus>
          </settlement>
          <security>
            <address>4</address>
            <postcode>4</postcode>
            <securitycode>2</securitycode>
          </security>
        </response>
        <secrand>x7C2kfKE92UiPAav</secrand>
      </responseblock>
    eos
  end

  def failed_authorize_response
    <<-eos
      <?xml version='1.0' encoding='utf-8'?>
      <responseblock version="3.67">
        <requestreference>W40-4pvqcrw1</requestreference>
        <response type="ACCOUNTCHECK">
          <merchant>
            <tid>27882788</tid>
            <merchantnumber>00000000</merchantnumber>
            <merchantcountryiso2a>GB</merchantcountryiso2a>
            <orderreference>8be9c12d-8dd5-4539-b6ae-6d8b3212de65</orderreference>
            <operatorname>evergiving@committedgiving.uk.net</operatorname>
          </merchant>
          <transactionreference>40-9-28019</transactionreference>
          <billing>
            <amount currencycode="GBP">0</amount>
            <payment type="VISA">
              <pan>400000######0002</pan>
              <issuercountry>ZZ</issuercountry>
              <issuer>SecureTrading Test Issuer1</issuer>
            </payment>
            <dcc enabled="0"/>
          </billing>
          <timestamp>2019-06-10 13:49:27</timestamp>
          <error>
            <message>Decline</message>
            <code>70000</code>
          </error>
          <acquirerresponsecode>05</acquirerresponsecode>
          <live>0</live>
          <authcode>DECLINED</authcode>
          <operation>
            <accounttypedescription>ECOM</accounttypedescription>
          </operation>
          <settlement>
            <settleduedate>2019-06-10</settleduedate>
            <settlestatus>0</settlestatus>
          </settlement>
          <security>
            <address>1</address>
            <postcode>1</postcode>
            <securitycode>1</securitycode>
          </security>
        </response>
        <secrand>MBIpzIk</secrand>
      </responseblock>
    eos
  end
end
