require 'test_helper'

class SageGatewayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = SageGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @check = check
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }

    @check_options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :shipping_address => address,
      :email => 'longbob@example.com',
      :drivers_license_state => 'CA',
      :drivers_license_number => '12345689',
      :date_of_birth => Date.new(1978, 8, 11),
      :ssn => '078051120'
    }
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal "APPROVED", response.message
    assert_equal "1234567890;bankcard", response.authorization

    assert_equal "A",                  response.params["success"]
    assert_equal "911911",             response.params["code"]
    assert_equal "APPROVED",           response.params["message"]
    assert_equal "00",                 response.params["front_end"]
    assert_equal "M",                  response.params["cvv_result"]
    assert_equal "X",                  response.params["avs_result"]
    assert_equal "00",                 response.params["risk"]
    assert_equal "1234567890",         response.params["reference"]
    assert_equal "1000",               response.params["order_number"]
    assert_equal "0",                  response.params["recurring"]
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal "APPROVED 000001", response.message
    assert_equal "B5O89VPdf0;bankcard", response.authorization

    assert_equal "A",                    response.params["success"]
    assert_equal "000001",               response.params["code"]
    assert_equal "APPROVED 000001",      response.params["message"]
    assert_equal "10",                   response.params["front_end"]
    assert_equal "M",                    response.params["cvv_result"]
    assert_equal "",                     response.params["avs_result"]
    assert_equal "00",                   response.params["risk"]
    assert_equal "B5O89VPdf0",           response.params["reference"]
    assert_equal "e81cab9e6144a160da82", response.params["order_number"]
    assert_equal "0",                    response.params["recurring"]
  end

  def test_declined_purchase
    @gateway.expects(:ssl_post).returns(declined_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal "DECLINED", response.message
    assert_equal "A5O89kkix0;bankcard", response.authorization

    assert_equal "E",                    response.params["success"]
    assert_equal "000002",               response.params["code"]
    assert_equal "DECLINED",             response.params["message"]
    assert_equal "10",                   response.params["front_end"]
    assert_equal "N",                    response.params["cvv_result"]
    assert_equal "",                     response.params["avs_result"]
    assert_equal "00",                   response.params["risk"]
    assert_equal "A5O89kkix0",           response.params["reference"]
    assert_equal "3443d6426188f8256b8f", response.params["order_number"]
    assert_equal "0",                    response.params["recurring"]
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, "A5O89kkix0")
    assert_instance_of Response, response
    assert_success response

    assert_equal "APPROVED 000001", response.message
    assert_equal "B5O8AdFhu0;bankcard", response.authorization

    assert_equal "A",                    response.params["success"]
    assert_equal "000001",               response.params["code"]
    assert_equal "APPROVED 000001",      response.params["message"]
    assert_equal "10",                   response.params["front_end"]
    assert_equal "P",                    response.params["cvv_result"]
    assert_equal "",                     response.params["avs_result"]
    assert_equal "00",                   response.params["risk"]
    assert_equal "B5O8AdFhu0",           response.params["reference"]
    assert_equal "ID5O8AdFhw",           response.params["order_number"]
    assert_equal "0",                    response.params["recurring"]
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, "Authorization")
    assert_success response
    assert_equal "G68FCU2c60;bankcard", response.authorization
    assert_equal "APPROVED", response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, "Authorization")
    assert_failure response
    assert_equal "INVALID T_REFERENCE", response.message
  end

  def test_invalid_login
    @gateway.expects(:ssl_post).returns(invalid_login_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal "SECURITY VIOLATION", response.message
    assert_equal "0000000000;bankcard", response.authorization

    assert_equal "X",                  response.params["success"]
    assert_equal "911911",             response.params["code"]
    assert_equal "SECURITY VIOLATION", response.params["message"]
    assert_equal "00",                 response.params["front_end"]
    assert_equal "P",                  response.params["cvv_result"]
    assert_equal "",                   response.params["avs_result"]
    assert_equal "00",                 response.params["risk"]
    assert_equal "0000000000",         response.params["reference"]
    assert_equal "",                   response.params["order_number"]
    assert_equal "0",                  response.params["recurring"]
  end

  def test_include_customer_number_for_numeric_values
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({:customer => "123"}))
    end.check_request do |method, data|
      assert data =~ /T_customer_number=123/
    end.respond_with(successful_authorization_response)
  end

  def test_dont_include_customer_number_for_numeric_values
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({:customer => "bob@test.com"}))
    end.check_request do |method, data|
      assert data !~ /T_customer_number/
    end.respond_with(successful_authorization_response)
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'X', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_address_with_state
    post = {}
    options = {
      :billing_address => { :country => "US", :state => "CA"}
    }
    @gateway.send(:add_addresses, post, options)

    assert_equal "US", post[:C_country]
    assert_equal "CA", post[:C_state]
  end

  def test_address_without_state
    post = {}
    options = {
      :billing_address => { :country => "NZ", :state => ""}
    }
    @gateway.send(:add_addresses, post, options)

    assert_equal "NZ", post[:C_country]
    assert_equal "Outside of US", post[:C_state]
  end

  def test_successful_check_purchase
    @gateway.expects(:ssl_post).returns(successful_check_purchase_response)

    response = @gateway.purchase(@amount, @check, @check_options)
    assert_instance_of Response, response
    assert_success response

    assert_equal "ACCEPTED", response.message
    assert_equal "C5O8NUdNt0;virtual_check", response.authorization

    assert_equal "A",                    response.params["success"]
    assert_equal "",                     response.params["code"]
    assert_equal "ACCEPTED",             response.params["message"]
    assert_equal "00",                   response.params["risk"]
    assert_equal "C5O8NUdNt0",           response.params["reference"]
    assert_equal "89be635e663b05eca587", response.params["order_number"]
    assert_equal  "0",                   response.params["authentication_indicator"]
    assert_equal  "NONE",                response.params["authentication_disclosure"]
  end

  def test_declined_check_purchase
    @gateway.expects(:ssl_post).returns(declined_check_purchase_response)

    response = @gateway.purchase(@amount, @check, @check_options)
    assert_failure response
    assert response.test?
    assert_equal "INVALID C_RTE", response.message
    assert_equal "C5O8NR6Nr0;virtual_check", response.authorization

    assert_equal "X",                    response.params["success"]
    assert_equal "900016",               response.params["code"]
    assert_equal "INVALID C_RTE",        response.params["message"]
    assert_equal "00",                   response.params["risk"]
    assert_equal "C5O8NR6Nr0",           response.params["reference"]
    assert_equal "d98cf50f7a2430fe04ad", response.params["order_number"]
    assert_equal  "0",                    response.params["authentication_indicator"]
    assert_equal  nil,                    response.params["authentication_disclosure"]
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<ns1:M_ID>login<\/ns1:M_ID>/, data)
      assert_match(/<ns1:M_KEY>password<\/ns1:M_KEY>/, data)
      assert_match(/<ns1:CARDNUMBER>#{credit_card.number}<\/ns1:CARDNUMBER>/, data)
      assert_match(/<ns1:EXPIRATION_DATE>#{expected_expiration_date}<\/ns1:EXPIRATION_DATE>/, data)
      assert_equal headers['SOAPAction'], 'https://www.sagepayments.net/web_services/wsVault/wsVault/INSERT_CREDIT_CARD_DATA'
    end.respond_with(successful_store_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '66234d2dfec24efe9fdcd4b751578c11', response.authorization
    assert_equal 'Success', response.message
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<ns1:M_ID>login<\/ns1:M_ID>/, data)
      assert_match(/<ns1:M_KEY>password<\/ns1:M_KEY>/, data)
      assert_match(/<ns1:CARDNUMBER>#{credit_card.number}<\/ns1:CARDNUMBER>/, data)
      assert_match(/<ns1:EXPIRATION_DATE>#{expected_expiration_date}<\/ns1:EXPIRATION_DATE>/, data)
      assert_equal headers['SOAPAction'], 'https://www.sagepayments.net/web_services/wsVault/wsVault/INSERT_CREDIT_CARD_DATA'
    end.respond_with(failed_store_response)

    assert response
    assert_instance_of Response, response
    assert_failure response
    assert_nil response.authorization
    assert_equal 'Unable to verify vault service', response.message
  end

  def test_successful_unstore
    response = stub_comms do
      @gateway.unstore('1234', @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<ns1:M_ID>login<\/ns1:M_ID>/, data)
      assert_match(/<ns1:M_KEY>password<\/ns1:M_KEY>/, data)
      assert_match(/<ns1:GUID>1234<\/ns1:GUID>/, data)
      assert_equal headers['SOAPAction'], 'https://www.sagepayments.net/web_services/wsVault/wsVault/DELETE_DATA'
    end.respond_with(successful_unstore_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_unstore
    response = stub_comms do
      @gateway.unstore('1234', @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<ns1:M_ID>login<\/ns1:M_ID>/, data)
      assert_match(/<ns1:M_KEY>password<\/ns1:M_KEY>/, data)
      assert_match(/<ns1:GUID>1234<\/ns1:GUID>/, data)
      assert_equal headers['SOAPAction'], 'https://www.sagepayments.net/web_services/wsVault/wsVault/DELETE_DATA'
    end.respond_with(failed_unstore_response)

    assert response
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Failed', response.message
  end

  def test_scrub
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
    assert_equal @gateway.scrub(pre_scrubbed_echeck), post_scrubbed_echeck
  end

  def test_supports_scrubbing?
    assert @gateway.supports_scrubbing?
  end

  private
  def successful_authorization_response
    "\002A911911APPROVED                        00MX001234567890\0341000\0340\034\003"
  end

  def successful_purchase_response
    "\002A000001APPROVED 000001                 10M 00B5O89VPdf0\034e81cab9e6144a160da82\0340\034\003"
  end

  def successful_capture_response
    "\002A000001APPROVED 000001                 10P 00B5O8AdFhu0\034ID5O8AdFhw\0340\034\003"
  end

  def declined_purchase_response
    "\002E000002DECLINED                        10N 00A5O89kkix0\0343443d6426188f8256b8f\0340\034\003"
  end

  def successful_refund_response
    "\x02A      APPROVED                        10P 00G68FCU2c60\x1C16119318c1edb9a27f70\x1C0\x1C\x03"
  end

  def failed_refund_response
    "\x02X900022INVALID T_REFERENCE             00P 00G68FCVJd10\x1C72bf690488cf72c81120\x1C0\x1C\x03"
  end

  def invalid_login_response
    "\002X911911SECURITY VIOLATION              00P 000000000000\034\0340\034\003"
  end

  def successful_check_purchase_response
    "\002A      ACCEPTED                        00C5O8NUdNt0\03489be635e663b05eca587\0340\034NONE\034\003"
  end

  def declined_check_purchase_response
    "\002X900016INVALID C_RTE                   00C5O8NR6Nr0\034d98cf50f7a2430fe04ad\0340\034\034\003"
  end

  def expected_expiration_date
    '%02d%02d' % [@credit_card.month, @credit_card.year.to_s[2..4]]
  end

  def successful_store_response
    <<-XML
<?xml version="1.0" encoding="utf-8" ?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <INSERT_CREDIT_CARD_DATAResponse xmlns="https://www.sagepayments.net/web_services/wsVault/wsVault">
      <INSERT_CREDIT_CARD_DATAResult>
        <!-- Bunch of xs:schema stuff. Then... -->
        <diffgr:diffgram xmlns:msdata="urn:schemas-microsoft-com:xml-msdata" xmlns:diffgr="urn:schemas-microsoft-com:xml-diffgram-v1">
          <NewDataSet xmlns="">
            <Table1 diffgr:id="Table11" msdata:rowOrder="0" diffgr:hasChanges="inserted">
              <SUCCESS>true</SUCCESS>
              <GUID>66234d2dfec24efe9fdcd4b751578c11</GUID>
              <MESSAGE>SUCCESS</MESSAGE>
            </Table1>
          </NewDataSet>
        </diffgr:diffgram>
      </INSERT_CREDIT_CARD_DATAResult>
    </INSERT_CREDIT_CARD_DATAResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def failed_store_response
    <<-XML
<?xml version="1.0" encoding="utf-8" ?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <INSERT_CREDIT_CARD_DATAResponse xmlns="https://www.sagepayments.net/web_services/wsVault/wsVault">
      <INSERT_CREDIT_CARD_DATAResult>
        <!-- Bunch of xs:schema stuff. Then... -->
        <diffgr:diffgram xmlns:msdata="urn:schemas-microsoft-com:xml-msdata" xmlns:diffgr="urn:schemas-microsoft-com:xml-diffgram-v1">
          <NewDataSet xmlns="">
            <Table1 diffgr:id="Table11" msdata:rowOrder="0" diffgr:hasChanges="inserted">
              <SUCCESS>false</SUCCESS>
              <GUID />
              <MESSAGE>UNABLE TO VERIFY VAULT SERVICE</MESSAGE>
            </Table1>
          </NewDataSet>
        </diffgr:diffgram>
      </INSERT_CREDIT_CARD_DATAResult>
    </INSERT_CREDIT_CARD_DATAResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def successful_unstore_response
    <<-XML
<?xml version="1.0" encoding="utf-8" ?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <DELETE_DATAResponse xmlns="https://www.sagepayments.net/web_services/wsVault/wsVault">
      <DELETE_DATAResult>true</DELETE_DATAResult>
    </DELETE_DATAResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def failed_unstore_response
    <<-XML
<?xml version="1.0" encoding="utf-8" ?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <DELETE_DATAResponse xmlns="https://www.sagepayments.net/web_services/wsVault/wsVault">
      <DELETE_DATAResult>false</DELETE_DATAResult>
    </DELETE_DATAResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
opening connection to www.sagepayments.net:443...
opened
starting SSL for www.sagepayments.net:443...
SSL established
<- "POST /cgi-bin/eftBankcard.dll?transaction HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: www.sagepayments.net\r\nContent-Length: 444\r\n\r\n"
<- "C_name=Longbob+Longsen&C_cardnumber=4111111111111111&C_exp=0917&C_cvv=123&T_amt=1.00&T_ordernum=1741a24e00a5a5f11653&C_address=456+My+Street&C_city=Ottawa&C_state=ON&C_zip=K1C2N6&C_country=CA&C_telephone=%28555%29555-5555&C_fax=%28555%29555-6666&C_email=longbob%40example.com&C_ship_name=Jim+Smith&C_ship_address=456+My+Street&C_ship_city=Ottawa&C_ship_state=ON&C_ship_zip=K1C2N6&C_ship_country=CA&M_id=214282982451&M_key=Z5W2S8J7X8T5&T_code=01"
-> "HTTP/1.1 200 OK\r\n"
-> "Content-Type: text/html\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Server: \r\n"
-> "X-AspNet-Version: \r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Thu, 30 Jun 2016 02:58:40 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 185\r\n"
-> "\r\n"
reading 185 bytes...
-> "\x1F\x8B\b\x00\x00\x00\x00\x00\x04\x00\xED\xBD\a`\x1CI\x96%&/m\xCA{\x7FJ\xF5J\xD7\xE0t\xA1\b\x80`\x13$\xD8\x90@\x10\xEC\xC1\x88\xCD\xE6\x92\xEC\x1DiG#)\xAB*\x81\xCAeVe]f\x16@\xCC\xED\x9D\xBC\xF7\xDE{\xEF\xBD\xF7\xDE{\xEF\xBD\xF7\xBA;\x9DN'\xF7\xDF\xFF?\\fd\x01l\xF6\xCEJ\xDA\xC9\x9E!\x80\xAA\xC8\x1F?~|\x1F?\"~\xAD\xE3\x1D<\xBB\xC7/_\xBE\xFA\xF2'O\x9F\xA6\xF4\a\xFD\x99v\x9F\xDD\x9D/\xE8\xAB\xCF?}\xF3\xF9\x17\xEF\xCE\xBF;\xDF\xF9\x9Dv\x1F\xEC\xEFf{\xFB\xF9\xCENv?\xBB\x7F\xBE\xBB\xFB\xE9\xFD{\xBF\xD3\xCE\xEF\xF4k\xFF?XI\x04rQ\x00\x00\x00"
read 185 bytes
Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
opening connection to www.sagepayments.net:443...
opened
starting SSL for www.sagepayments.net:443...
SSL established
<- "POST /cgi-bin/eftBankcard.dll?transaction HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: www.sagepayments.net\r\nContent-Length: 444\r\n\r\n"
<- "C_name=Longbob+Longsen&C_cardnumber=[FILTERED]&C_exp=0917&C_cvv=[FILTERED]&T_amt=1.00&T_ordernum=1741a24e00a5a5f11653&C_address=456+My+Street&C_city=Ottawa&C_state=ON&C_zip=K1C2N6&C_country=CA&C_telephone=%28555%29555-5555&C_fax=%28555%29555-6666&C_email=longbob%40example.com&C_ship_name=Jim+Smith&C_ship_address=456+My+Street&C_ship_city=Ottawa&C_ship_state=ON&C_ship_zip=K1C2N6&C_ship_country=CA&M_id=[FILTERED]&M_key=[FILTERED]&T_code=01"
-> "HTTP/1.1 200 OK\r\n"
-> "Content-Type: text/html\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Server: \r\n"
-> "X-AspNet-Version: \r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Thu, 30 Jun 2016 02:58:40 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 185\r\n"
-> "\r\n"
reading 185 bytes...
-> \"\u001F?\b\u0000\u0000\u0000\u0000\u0000\u0004\u0000??\a`\u001CI?%&/m?{\u007FJ?J??t?\b?`\u0013$?@\u0010??????\u001DiG#)?*??eVe]f\u0016@????{???{???;?N'????\\fd\u0001l??J??!???\u001F?~|\u001F?\"~??\u001D<??/_???'O???\a??v??/???}??\u0017??;???v\u001F??f{???Nv??\u007F?????{?????k??XI\u0004rQ\u0000\u0000\u0000\"
read 185 bytes
Conn close
    POST_SCRUBBED
  end

  def pre_scrubbed_echeck
    <<-PRE_SCRUBBED
opening connection to www.sagepayments.net:443...
opened
starting SSL for www.sagepayments.net:443...
SSL established
<- "POST /cgi-bin/eftVirtualCheck.dll?transaction HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: www.sagepayments.net\r\nContent-Length: 562\r\n\r\n"
<- "C_first_name=Jim&C_last_name=Smith&C_rte=244183602&C_acct=15378535&C_check_number=1&C_acct_type=DDA&C_customer_type=WEB&C_originator_id=&T_addenda=&C_ssn=&C_dl_state_code=&C_dl_number=&C_dob=&T_amt=1.00&T_ordernum=0ac6fd1f74a98de94bf9&C_address=456+My+Street&C_city=Ottawa&C_state=ON&C_zip=K1C2N6&C_country=CA&C_telephone=%28555%29555-5555&C_fax=%28555%29555-6666&C_email=longbob%40example.com&C_ship_name=Jim+Smith&C_ship_address=456+My+Street&C_ship_city=Ottawa&C_ship_state=ON&C_ship_zip=K1C2N6&C_ship_country=CA&M_id=562313162894&M_key=J6U9B3G2F6L3&T_code=01"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: no-cache\r\n"
-> "Pragma: no-cache\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "Content-Type: text/html; charset=us-ascii\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Expires: -1\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Server: Microsoft-IIS/7.5\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Thu, 02 Nov 2017 13:26:30 GMT\r\n"
-> "Connection: close\r\n"
-> "\r\n"
-> "ac\r\n"
reading 172 bytes...
-> "\x1F\x8B\b\x00\x00\x00\x00\x00\x04\x00\xED\xBD\a`\x1CI\x96%&/m\xCA{\x7FJ\xF5J\xD7\xE0t\xA1\b\x80`\x13$\xD8\x90@\x10\xEC\xC1\x88\xCD\xE6\x92\xEC\x1DiG#)\xAB*\x81\xCAeVe]f\x16@\xCC\xED\x9D\xBC\xF7\xDE{\xEF\xBD\xF7\xDE{\xEF\xBD\xF7\xBA;\x9DN'\xF7\xDF\xFF?\\fd\x01l\xF6\xCEJ\xDA\xC9\x9E!\x80\xAA\xC8\x1F?~|\x1F?\"~\xAD\xE3\x94\x9F\xE3\x93\x93\xD3\x97oN\x9F\xD2\xAF\xD1gg\xE7\xD9\x93\xBDo?\xFC\x89\xAF\x16\xF7v~\xA7\x9Dl\xFA\xE9\xF9l\xF7\xFC\xC1~\xF6\xF0`\x96?\xDC\x9F\x9C?\xFC\x9Dv~\xA7\x17_\xBE8\xA5\x1F\xBF"
read 172 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "b\r\n"
reading 11 bytes...
-> "\xF6\xFF\x03\x90\xEB\x1E T\x00\x00\x00"
read 11 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed_echeck
    <<-POST_SCRUBBED
opening connection to www.sagepayments.net:443...\nopened\nstarting SSL for www.sagepayments.net:443...\nSSL established\n<- \"POST /cgi-bin/eftVirtualCheck.dll?transaction HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: www.sagepayments.net\r\nContent-Length: 562\r\n\r\n\"\n<- \"C_first_name=Jim&C_last_name=Smith&C_rte=[FILTERED]&C_acct=[FILTERED]&C_check_number=1&C_acct_type=DDA&C_customer_type=WEB&C_originator_id=&T_addenda=&C_ssn=[FILTERED]&C_dl_state_code=&C_dl_number=&C_dob=&T_amt=1.00&T_ordernum=0ac6fd1f74a98de94bf9&C_address=456+My+Street&C_city=Ottawa&C_state=ON&C_zip=K1C2N6&C_country=CA&C_telephone=%28555%29555-5555&C_fax=%28555%29555-6666&C_email=longbob%40example.com&C_ship_name=Jim+Smith&C_ship_address=456+My+Street&C_ship_city=Ottawa&C_ship_state=ON&C_ship_zip=K1C2N6&C_ship_country=CA&M_id=[FILTERED]&M_key=[FILTERED]&T_code=01\"\n-> \"HTTP/1.1 200 OK\r\n\"\n-> \"Cache-Control: no-cache\r\n\"\n-> \"Pragma: no-cache\r\n\"\n-> \"Transfer-Encoding: chunked\r\n\"\n-> \"Content-Type: text/html; charset=us-ascii\r\n\"\n-> \"Content-Encoding: gzip\r\n\"\n-> \"Expires: -1\r\n\"\n-> \"Vary: Accept-Encoding\r\n\"\n-> \"Server: Microsoft-IIS/7.5\r\n\"\n-> \"X-Powered-By: ASP.NET\r\n\"\n-> \"Date: Thu, 02 Nov 2017 13:26:30 GMT\r\n\"\n-> \"Connection: close\r\n\"\n-> \"\r\n\"\n-> \"ac\r\n\"\nreading 172 bytes...\n-> \"\u001F?\b\u0000\u0000\u0000\u0000\u0000\u0004\u0000??\a`\u001CI?%&/m?{\u007FJ?J??t?\b?`\u0013$?@\u0010??????\u001DiG#)?*??eVe]f\u0016@????{???{???;?N'????\\fd\u0001l??J??!???\u001F?~|\u001F?\"~????oN???gg???o????\u0016?v~??l???l???~??`???????v~?\u0017_?8?\u001F?\"\nread 172 bytes\nreading 2 bytes...\n-> \"\r\n\"\nread 2 bytes\n-> \"b\r\n\"\nreading 11 bytes...\n-> \"??\u0003??\u001E T\u0000\u0000\u0000\"\nread 11 bytes\nreading 2 bytes...\n-> \"\r\n\"\nread 2 bytes\n-> \"0\r\n\"\n-> \"\r\n\"\nConn close
    POST_SCRUBBED
  end
end
