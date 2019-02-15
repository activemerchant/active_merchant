require 'test_helper'

class BlueSnapTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = BlueSnapGateway.new(api_username: 'login', api_password: 'password')
    @credit_card = credit_card
    @check = check
    @amount = 100
    @options = { order_id: '1', personal_identification_number: 'CNPJ' }
    @valid_check_options = {
      billing_address: {
        address1: '123 Street',
        address2: 'Apt 1',
        city: 'Happy City',
        state: 'CA',
        zip: '94901'
      },
      authorized_by_shopper: true
    }
  end

  def test_successful_purchase
    @gateway.expects(:raw_ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '1012082839', response.authorization
  end

  def test_successful_echeck_purchase
    @gateway.expects(:raw_ssl_request).returns(successful_echeck_purchase_response)

    response = @gateway.purchase(@amount, @check, @options.merge(@valid_check_options))
    assert_success response
    assert_equal '1019803029', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:raw_ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '14002', response.error_code
  end

  def test_failed_echeck_purchase
    @gateway.expects(:raw_ssl_request).returns(failed_echeck_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '16004', response.error_code
  end

  def test_successful_authorize
    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |type, endpoint, data, headers|
      assert_match '<storeCard>false</storeCard>', data
      assert_match '<personal-identification-number>CNPJ</personal-identification-number>', data
    end.respond_with(successful_authorize_response)
    assert_success response
    assert_equal '1012082893', response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:raw_ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '14002', response.error_code
  end

  def test_successful_capture
    @gateway.expects(:raw_ssl_request).returns(successful_capture_response)

    response = @gateway.capture(@amount, 'Authorization')
    assert_success response
    assert_equal '1012082881', response.authorization
  end

  def test_failed_capture
    @gateway.expects(:raw_ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, 'Authorization')
    assert_failure response
    assert_equal '20008', response.error_code
  end

  def test_successful_refund
    @gateway.expects(:raw_ssl_request).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'Authorization')
    assert_success response
    assert_equal '1012082907', response.authorization
  end

  def test_failed_refund
    @gateway.expects(:raw_ssl_request).returns(failed_refund_response)

    response = @gateway.refund(@amount, 'Authorization')
    assert_failure response
    assert_equal '20008', response.error_code
  end

  def test_successful_void
    @gateway.expects(:raw_ssl_request).returns(successful_void_response)

    response = @gateway.void('Authorization')
    assert_success response
    assert_equal '1012082919', response.authorization
  end

  def test_failed_void
    @gateway.expects(:raw_ssl_request).returns(failed_void_response)

    response = @gateway.void('Authorization')
    assert_failure response
    assert_equal '20008', response.error_code
  end

  def test_successful_verify
    @gateway.expects(:raw_ssl_request).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal '1012082929', response.authorization
  end

  def test_failed_verify
    @gateway.expects(:raw_ssl_request).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal '14002', response.error_code
  end

  def test_successful_store
    @gateway.expects(:raw_ssl_request).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal '20936441', response.authorization
  end

  def test_successful_echeck_store
    @gateway.expects(:raw_ssl_request).returns(successful_echeck_store_response)

    response = @gateway.store(@check, @options)
    assert_success response
    assert_equal '23844081|check', response.authorization
  end

  def test_failed_store
    @gateway.expects(:raw_ssl_request).returns(failed_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal '14002', response.error_code
  end

  def test_failed_echeck_store
    @gateway.expects(:raw_ssl_request).returns(failed_echeck_store_response)

    response = @gateway.store(@check, @options)
    assert_failure response
    assert_equal '10001', response.error_code
  end

  def test_currency_added_correctly
    stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(currency: 'CAD'))
    end.check_request do |method, url, data|
      assert_match(/<currency>CAD<\/currency>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_verify_good_credentials
    @gateway.expects(:raw_ssl_request).returns(credentials_are_legit_response)
    assert @gateway.verify_credentials
  end

  def test_verify_bad_credentials
    @gateway.expects(:raw_ssl_request).returns(credentials_are_bogus_response)
    assert !@gateway.verify_credentials
  end

  def test_failed_forbidden_response
    @gateway.expects(:raw_ssl_request).returns(forbidden_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '<xml>You are not authorized to perform this request due to inappropriate role permissions.</xml>', response.message
  end

  def test_does_not_send_level_3_when_empty
    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |type, endpoint, data, headers|
      assert_not_match(/level-3-data/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_echeck_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed_echeck), post_scrubbed_echeck
  end

  private

  def pre_scrubbed
    %q{
        opening connection to sandbox.bluesnap.com:443...
        starting SSL for sandbox.bluesnap.com:443...
        <- "POST /services/2/transactions HTTP/1.1\r\nContent-Type: application/xml\r\nAuthorization: Basic QVBJXzE0NjExNzM3MTY2NTc2NzM0MDQyMzpuZll3VHg4ZkZBdkpxQlhjeHF3Qzg=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.bluesnap.com\r\nContent-Length: 683\r\n\r\n"
        <- "<card-transaction xmlns=\"http://ws.plimus.com\">\n  <card-transaction-type>AUTH_CAPTURE</card-transaction-type>\n  <recurring-transaction>RECURRING</recurring-transaction>\n  <amount>1.00</amount>\n  <currency>USD</currency>\n  <card-holder-info>\n    <first-name>Longbob</first-name>\n    <last-name>Longsen</last-name>\n    <country>CA</country>\n    <state>ON</state>\n    <city>Ottawa</city>\n    <zip>K1C2N6</zip>\n  </card-holder-info>\n  <transaction-fraud-info/>\n  <credit-card>\n    <card-number>4263982640269299</card-number>\n    <security-code>123</security-code>\n    <expiration-month>9</expiration-month>\n    <expiration-year>2017</expiration-year>\n  </credit-card>\n</card-transaction>"
        -> "HTTP/1.1 200 OK\r\n"
        -> "Set-Cookie: JSESSIONID=156258FCEC747EFAEA6FE909FDF0004A; Path=/services/; Secure; HttpOnly\r\n"
        -> "Content-Encoding: gzip\r\n"
        -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03mS]\x8F\xDA0\x10|\xCF\xAF@\xA9\xD47c\xA0\x1F:Z\xE3\x13\xCD\xD1\x16\xF5\xC4U\x81\xF4\xB52\xB1\xE1,%v\xE4u\xB8K"
        Conn close
    }
  end

  def pre_scrubbed_echeck
    %q{
        opening connection to sandbox.bluesnap.com:443...
        opened
        starting SSL for sandbox.bluesnap.com:443...
        SSL established
        <- "POST /services/2/alt-transactions HTTP/1.1\r\nContent-Type: application/xml\r\nAuthorization: Basic QVBJXzE0NjExNzM3MTY2NTc2NzM0MDQyMzpuZll3VHg4ZkZBdkpxQlhjeHF3Qzg=\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: sandbox.bluesnap.com\r\nContent-Length: 973\r\n\r\n"
        <- "<alt-transaction xmlns=\"http://ws.plimus.com\">\n  <amount>1.00</amount>\n  <currency>USD</currency>\n  <payer-info>\n    <first-name>Jim</first-name>\n    <last-name>Smith</last-name>\n    <state>CA</state>\n    <city>Happy City</city>\n    <zip>94901</zip>\n    <company-name>Jim Smith</company-name>\n  </payer-info>\n  <ecp-transaction>\n    <account-number>15378535</account-number>\n    <routing-number>244183602</routing-number>\n    <account-type>CORPORATE_CHECKING</account-type>\n  </ecp-transaction>\n  <authorized-by-shopper>true</authorized-by-shopper>\n  <transaction-fraud-info/>\n  </alt-transaction>"
        -> "HTTP/1.1 200 200\r\n"
        -> "Set-Cookie: JSESSIONID=65D503B9785EA6641D4757EA568A6532; Path=/services; Secure; HttpOnly\r\n"
        -> "Connection: close\r\n"
    }
  end

  def post_scrubbed
    %q{
        opening connection to sandbox.bluesnap.com:443...
        starting SSL for sandbox.bluesnap.com:443...
        <- "POST /services/2/transactions HTTP/1.1\r\nContent-Type: application/xml\r\nAuthorization: Basic [FILTERED]=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.bluesnap.com\r\nContent-Length: 683\r\n\r\n"
        <- "<card-transaction xmlns=\"http://ws.plimus.com\">\n  <card-transaction-type>AUTH_CAPTURE</card-transaction-type>\n  <recurring-transaction>RECURRING</recurring-transaction>\n  <amount>1.00</amount>\n  <currency>USD</currency>\n  <card-holder-info>\n    <first-name>Longbob</first-name>\n    <last-name>Longsen</last-name>\n    <country>CA</country>\n    <state>ON</state>\n    <city>Ottawa</city>\n    <zip>K1C2N6</zip>\n  </card-holder-info>\n  <transaction-fraud-info/>\n  <credit-card>\n    <card-number>[FILTERED]</card-number>\n    <security-code>[FILTERED]</security-code>\n    <expiration-month>9</expiration-month>\n    <expiration-year>2017</expiration-year>\n  </credit-card>\n</card-transaction>"
        -> "HTTP/1.1 200 OK\r\n"
        -> "Set-Cookie: JSESSIONID=156258FCEC747EFAEA6FE909FDF0004A; Path=/services/; Secure; HttpOnly\r\n"
        -> "Content-Encoding: gzip\r\n"
        -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03mS]\x8F\xDA0\x10|\xCF\xAF@\xA9\xD47c\xA0\x1F:Z\xE3\x13\xCD\xD1\x16\xF5\xC4U\x81\xF4\xB52\xB1\xE1,%v\xE4u\xB8K"
        Conn close
    }
  end

  def post_scrubbed_echeck
    %q{
        opening connection to sandbox.bluesnap.com:443...
        opened
        starting SSL for sandbox.bluesnap.com:443...
        SSL established
        <- "POST /services/2/alt-transactions HTTP/1.1\r\nContent-Type: application/xml\r\nAuthorization: Basic [FILTERED]=\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: sandbox.bluesnap.com\r\nContent-Length: 973\r\n\r\n"
        <- "<alt-transaction xmlns=\"http://ws.plimus.com\">\n  <amount>1.00</amount>\n  <currency>USD</currency>\n  <payer-info>\n    <first-name>Jim</first-name>\n    <last-name>Smith</last-name>\n    <state>CA</state>\n    <city>Happy City</city>\n    <zip>94901</zip>\n    <company-name>Jim Smith</company-name>\n  </payer-info>\n  <ecp-transaction>\n    <account-number>[FILTERED]</account-number>\n    <routing-number>[FILTERED]</routing-number>\n    <account-type>CORPORATE_CHECKING</account-type>\n  </ecp-transaction>\n  <authorized-by-shopper>true</authorized-by-shopper>\n  <transaction-fraud-info/>\n  </alt-transaction>"
        -> "HTTP/1.1 200 200\r\n"
        -> "Set-Cookie: JSESSIONID=65D503B9785EA6641D4757EA568A6532; Path=/services; Secure; HttpOnly\r\n"
        -> "Connection: close\r\n"
    }
  end

  def successful_purchase_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <card-transaction xmlns="http://ws.plimus.com">
      <card-transaction-type>AUTH_CAPTURE</card-transaction-type>
      <transaction-id>1012082839</transaction-id>
      <recurring-transaction>ECOMMERCE</recurring-transaction>
      <soft-descriptor>BLS*Spreedly</soft-descriptor>
      <amount>1.00</amount>
      <currency>USD</currency>
      <card-holder-info>
          <first-name>Longbob</first-name>
          <last-name>Longsen</last-name>
          <country>CA</country>
          <state>ON</state>
          <city>Ottawa</city>
          <zip>K1C2N6</zip>
          <personal-identification-number>CNPJ</personal-identification-number>
      </card-holder-info>
      <credit-card>
          <card-last-four-digits>9299</card-last-four-digits>
          <card-type>VISA</card-type>
          <card-sub-type>CREDIT</card-sub-type>
      </credit-card>
      <processing-info>
          <processing-status>success</processing-status>
          <cvv-response-code>ND</cvv-response-code>
          <avs-response-code-zip>U</avs-response-code-zip>
          <avs-response-code-address>U</avs-response-code-address>
          <avs-response-code-name>U</avs-response-code-name>
      </processing-info>
      </card-transaction>
    XML
  end

  def successful_echeck_purchase_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <alt-transaction xmlns="http://ws.plimus.com">
        <transaction-id>1019803029</transaction-id>
        <amount>1.00</amount>
        <currency>USD</currency>
        <payer-info>
          <first-name>Jim</first-name>
          <last-name>Smith</last-name>
          <state>CA</state>
          <city>Happy City</city>
          <zip>94901</zip>
          <company-name>Jim Smith</company-name>
        </payer-info>
        <ecp-transaction>
          <account-number>15378535</account-number>
          <routing-number>244183602</routing-number>
          <account-type>CORPORATE_CHECKING</account-type>
        </ecp-transaction>
        <processing-info>
          <processing-status>PENDING</processing-status>
        </processing-info>
      </alt-transaction>
    XML
  end

  def failed_purchase_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
        <message>
          <error-name>INCORRECT_INFORMATION</error-name>
          <code>14002</code>
          <description>Transaction failed  because of payment processing failure.: 430285 - Authorization has failed for this transaction. Please try again or contact your bank for assistance</description>
        </message>
      </messages>
    XML

    MockResponse.failed(body, 400)
  end

  def failed_echeck_purchase_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <messages xmlns="http://ws.plimus.com">
        <message>
          <error-name>PAYMENT_NOT_AUTHORIZED_BY_SHOPPER</error-name>
          <code>16004</code>
          <description>The payment was not authorized by shopper. Missing/Invalid 'authorized-by-shopper' element.</description>
        </message>
      </messages>
    XML

    MockResponse.failed(body, 400)
  end

  def successful_authorize_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <card-transaction xmlns="http://ws.plimus.com">
      <card-transaction-type>AUTH_ONLY</card-transaction-type>
      <transaction-id>1012082893</transaction-id>
      <recurring-transaction>ECOMMERCE</recurring-transaction>
      <soft-descriptor>BLS*Spreedly</soft-descriptor>
      <amount>1.00</amount>
      <currency>USD</currency>
      <card-holder-info>
          <first-name>Longbob</first-name>
          <last-name>Longsen</last-name>
          <country>CA</country>
          <state>ON</state>
          <city>Ottawa</city>
          <zip>K1C2N6</zip>
          <personal-identification-number>CNPJ</personal-identification-number>
      </card-holder-info>
      <credit-card>
          <card-last-four-digits>9299</card-last-four-digits>
          <card-type>VISA</card-type>
          <card-sub-type>CREDIT</card-sub-type>
      </credit-card>
      <processing-info>
          <processing-status>success</processing-status>
          <cvv-response-code>ND</cvv-response-code>
          <avs-response-code-zip>U</avs-response-code-zip>
          <avs-response-code-address>U</avs-response-code-address>
          <avs-response-code-name>U</avs-response-code-name>
      </processing-info>
      </card-transaction>
    XML
  end

  def failed_authorize_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
      <message>
          <error-name>INCORRECT_INFORMATION</error-name>
          <code>14002</code>
          <description>Transaction failed  because of payment processing failure.: 430285 - Authorization has failed for this transaction. Please try again or contact your bank for assistance</description>
      </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def successful_capture_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <card-transaction xmlns="http://ws.plimus.com">
      <card-transaction-type>CAPTURE</card-transaction-type>
      <transaction-id>1012082881</transaction-id>
      <recurring-transaction>ECOMMERCE</recurring-transaction>
      <soft-descriptor>BLS*Spreedly</soft-descriptor>
      <amount>1.00</amount>
      <currency>USD</currency>
      <card-holder-info>
          <first-name>Longbob</first-name>
          <last-name>Longsen</last-name>
          <country>ca</country>
          <state>ON</state>
          <city>Ottawa</city>
          <zip>K1C2N6</zip>
          <personal-identification-number>CNPJ</personal-identification-number>
      </card-holder-info>
      <credit-card>
          <card-last-four-digits>9299</card-last-four-digits>
          <card-type>VISA</card-type>
          <card-sub-type>CREDIT</card-sub-type>
      </credit-card>
      <processing-info>
          <processing-status>SUCCESS</processing-status>
          <cvv-response-code>ND</cvv-response-code>
          <avs-response-code-zip>U</avs-response-code-zip>
          <avs-response-code-address>U</avs-response-code-address>
          <avs-response-code-name>U</avs-response-code-name>
      </processing-info>
      </card-transaction>
    XML
  end

  def failed_capture_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
      <message>
          <error-name>TRANSACTION_ID_REQUIRED</error-name>
          <code>20008</code>
          <description>Transaction operation cannot be completed due to missing transaction ID parameter.</description>
      </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def successful_refund_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <card-transaction xmlns="http://ws.plimus.com">
         <card-transaction-type>REFUND</card-transaction-type>
         <transaction-id>1012082907</transaction-id>
         <recurring-transaction>ECOMMERCE</recurring-transaction>
         <soft-descriptor>BLS*Spreedly</soft-descriptor>
         <amount>1.00</amount>
         <currency>USD</currency>
         <card-holder-info>
            <first-name>Longbob</first-name>
            <last-name>Longsen</last-name>
            <country>ca</country>
            <state>ON</state>
            <city>Ottawa</city>
            <zip>K1C2N6</zip>
            <personal-identification-number>CNPJ</personal-identification-number>
         </card-holder-info>
         <credit-card>
            <card-last-four-digits>9299</card-last-four-digits>
            <card-type>VISA</card-type>
            <card-sub-type>CREDIT</card-sub-type>
         </credit-card>
         <processing-info>
            <processing-status>SUCCESS</processing-status>
            <cvv-response-code>ND</cvv-response-code>
            <avs-response-code-zip>U</avs-response-code-zip>
            <avs-response-code-address>U</avs-response-code-address>
            <avs-response-code-name>U</avs-response-code-name>
         </processing-info>
      </card-transaction>
    XML
  end

  def failed_refund_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
         <message>
            <error-name>TRANSACTION_ID_REQUIRED</error-name>
            <code>20008</code>
            <description>Transaction operation cannot be completed due to missing transaction ID parameter.</description>
         </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def successful_void_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <card-transaction xmlns="http://ws.plimus.com">
         <card-transaction-type>AUTH_REVERSAL</card-transaction-type>
         <transaction-id>1012082919</transaction-id>
         <recurring-transaction>ECOMMERCE</recurring-transaction>
         <soft-descriptor>BLS*Spreedly</soft-descriptor>
         <amount>1.00</amount>
         <currency>USD</currency>
         <card-holder-info>
            <first-name>Longbob</first-name>
            <last-name>Longsen</last-name>
            <country>ca</country>
            <state>ON</state>
            <city>Ottawa</city>
            <zip>K1C2N6</zip>
            <personal-identification-number>CNPJ</personal-identification-number>
         </card-holder-info>
         <credit-card>
            <card-last-four-digits>9299</card-last-four-digits>
            <card-type>VISA</card-type>
            <card-sub-type>CREDIT</card-sub-type>
         </credit-card>
         <processing-info>
            <processing-status>SUCCESS</processing-status>
            <cvv-response-code>ND</cvv-response-code>
            <avs-response-code-zip>U</avs-response-code-zip>
            <avs-response-code-address>U</avs-response-code-address>
            <avs-response-code-name>U</avs-response-code-name>
         </processing-info>
      </card-transaction>
    XML
  end

  def failed_void_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
        <message>
          <error-name>TRANSACTION_ID_REQUIRED</error-name>
          <code>20008</code>
          <description>Transaction operation cannot be completed due to missing transaction ID parameter.</description>
        </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def successful_verify_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <card-transaction xmlns="http://ws.plimus.com">
        <card-transaction-type>AUTH_ONLY</card-transaction-type>
        <transaction-id>1012082929</transaction-id>
        <recurring-transaction>ECOMMERCE</recurring-transaction>
        <soft-descriptor>Spreedly</soft-descriptor>
        <amount>0.00</amount>
        <currency>USD</currency>
        <card-holder-info>
          <first-name>Longbob</first-name>
          <last-name>Longsen</last-name>
          <country>CA</country>
          <state>ON</state>
          <city>Ottawa</city>
          <zip>K1C2N6</zip>
          <personal-identification-number>CNPJ</personal-identification-number>
        </card-holder-info>
        <credit-card>
          <card-last-four-digits>9299</card-last-four-digits>
          <card-type>VISA</card-type>
          <card-sub-type>CREDIT</card-sub-type>
        </credit-card>
        <processing-info>
          <processing-status>success</processing-status>
          <cvv-response-code>ND</cvv-response-code>
          <avs-response-code-zip>U</avs-response-code-zip>
          <avs-response-code-address>U</avs-response-code-address>
          <avs-response-code-name>U</avs-response-code-name>
        </processing-info>
      </card-transaction>
    XML
  end

  def failed_verify_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
        <message>
          <error-name>INCORRECT_INFORMATION</error-name>
          <code>14002</code>
          <description>Transaction failed  because of payment processing failure.: 430285 - Authorization has failed for this transaction. Please try again or contact your bank for assistance</description>
        </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def successful_store_response
    response = MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <vaulted-shopper xmlns="http://ws.plimus.com">
        <first-name>Longbob</first-name>
        <last-name>Longsen</last-name>
        <country>ca</country>
        <state>ON</state>
        <city>Ottawa</city>
        <zip>K1C2N6</zip>
        <personal-identification-number>CNPJ</personal-identification-number>
        <shopper-currency>USD</shopper-currency>
        <payment-sources>
          <credit-card-info>
            <billing-contact-info>
              <first-name>Longbob</first-name>
              <last-name>Longsen</last-name>
              <city />
            </billing-contact-info>
            <credit-card>
              <card-last-four-digits>9299</card-last-four-digits>
              <card-type>VISA</card-type>
              <card-sub-type>CREDIT</card-sub-type>
            </credit-card>
            <processing-info>
              <cvv-response-code>ND</cvv-response-code>
              <avs-response-code-zip>U</avs-response-code-zip>
              <avs-response-code-address>U</avs-response-code-address>
              <avs-response-code-name>U</avs-response-code-name>
            </processing-info>
          </credit-card-info>
        </payment-sources>
      </vaulted-shopper>
    XML

    response.headers = { 'content-location' => 'https://sandbox.bluesnap.com/services/2/vaulted-shoppers/20936441' }
    response
  end

  def successful_echeck_store_response
    response = MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <vaulted-shopper xmlns="http://ws.plimus.com">
        <vaulted-shopper-id>23844081</vaulted-shopper-id>
        <first-name>Jim</first-name>
        <last-name>Smith</last-name>
        <city>Happy City</city>
        <zip>94901</zip>
        <company-name>Jim Smith</company-name>
        <shopper-currency>USD</shopper-currency>
        <payment-sources>
          <ecp-info>
            <billing-contact-info>
              <first-name>Jim</first-name>
              <last-name>Smith</last-name>
              <city></city>
              <company-name>Jim Smith</company-name>
            </billing-contact-info>
            <ecp>
              <account-number>15378535</account-number>
              <routing-number>244183602</routing-number>
              <account-type>CORPORATE_CHECKING</account-type>
            </ecp>
          </ecp-info>
        </payment-sources>
      </vaulted-shopper>
    XML

    response.headers = { 'content-location' => 'https://sandbox.bluesnap.com/services/2/vaulted-shoppers/23844081' }
    response
  end

  def failed_store_response
    body =  <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
        <message>
          <error-name>INCORRECT_INFORMATION</error-name>
          <code>14002</code>
          <description>Transaction failed  because of payment processing failure.: 430285 - Authorization has failed for this transaction. Please try again or contact your bank for assistance</description>
        </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def failed_echeck_store_response
    body =  <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <messages xmlns="http://ws.plimus.com">
        <message>
          <error-name>VALIDATION_GENERAL_FAILURE</error-name>
          <code>10001</code>
          <description>ECP data validity check failed</description>
        </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def forbidden_response
    MockResponse.new(403, '<xml>You are not authorized to perform this request due to inappropriate role permissions.</xml>')
  end

  def credentials_are_legit_response
    MockResponse.new(400, '<xml>Server Error</xml>')
  end

  def credentials_are_bogus_response
    MockResponse.new(401, %{<!DOCTYPE html><html lang="en"><head><title>HTTP Status 401 – Unauthorized</title><style type="text/css">h1 {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;font-size:22px;} h2 {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;font-size:16px;} h3 {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;font-size:14px;} body {font-family:Tahoma,Arial,sans-serif;color:black;background-color:white;} b {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;} p {font-family:Tahoma,Arial,sans-serif;background:white;color:black;font-size:12px;} a {color:black;} a.name {color:black;} .line {height:1px;background-color:#525D76;border:none;}</style></head><body><h1>HTTP Status 401 – Unauthorized</h1><hr class="line" /><p><b>Type</b> Status Report</p><p><b>Message</b> Bad credentials</p><p><b>Description</b> The request has not been applied because it lacks valid authentication credentials for the target resource.</p><hr class="line" /><h3>Apache Tomcat Version X</h3></body></html>})
  end
end
