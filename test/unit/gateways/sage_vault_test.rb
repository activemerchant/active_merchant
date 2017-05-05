require 'test_helper'

class SageVaultGatewayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = SageVaultGateway.new(
                 :login => 'login',
                 :password => 'password'
               )
    @credit_card = credit_card
    @options = { }
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<ns1:M_ID>login<\/ns1:M_ID>/, data)
      assert_match(/<ns1:M_KEY>password<\/ns1:M_KEY>/, data)
      assert_match(/<ns1:CARDNUMBER>#{credit_card.number}<\/ns1:CARDNUMBER>/, data)
      assert_match(/<ns1:EXPIRATION_DATE>0915<\/ns1:EXPIRATION_DATE>/, data)
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
      assert_match(/<ns1:EXPIRATION_DATE>0915<\/ns1:EXPIRATION_DATE>/, data)
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
