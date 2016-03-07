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

  def test_us_address_with_state
    post = {}
    options = {
      :billing_address => { :country => "US", :state => "CA"}
    }
    @gateway.send(:add_addresses, post, options)

    assert_equal "US", post[:C_country]
    assert_equal "CA", post[:C_state]
  end

  def test_us_address_without_state
    post = {}
    options = {
      :billing_address => { :country => "US", :state => ""}
    }
    @gateway.send(:add_addresses, post, options)

    assert_equal "US", post[:C_country]
    assert_equal "", post[:C_state]
  end


  def test_international_address_without_state
    post = {}
    options = {
      :billing_address => { :country => "JP", :state => ""}
    }
    @gateway.send(:add_addresses, post, options)

    assert_equal "JP", post[:C_country]
    assert_equal "Outside of United States", post[:C_state]
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
end
