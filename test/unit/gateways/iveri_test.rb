require 'test_helper'

class IveriTest < Test::Unit::TestCase
  def setup
    @gateway = IveriGateway.new(app_id: '123', cert_id: '321')
    @credit_card = credit_card('4242424242424242')
    @amount = 100

    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: 'Store Purchase',
      currency: 'ZAR'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "{F0568958-D10B-4093-A3BF-663168B06140}|{5CEF96FD-960E-4EA5-811F-D02CE6E36A96}|48b63446223ce91451fc3c1641a9ec03", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '4', response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "{B90D7CDB-C8E8-4477-BDF2-695F28137874}|{EF0DC64E-2D00-4B6C-BDA0-2AD265391317}|23b4125c3b8e2777bffee52e196a863b", response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '4', response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, '{B90D7CDB-C8E8-4477-BDF2-695F28137874}|{EF0DC64E-2D00-4B6C-BDA0-2AD265391317}|23b4125c3b8e2777bffee52e196a863b')
    assert_success response
    assert_equal "{7C91245F-607D-44AE-8958-C26E447BAEB7}|{EF0DC64E-2D00-4B6C-BDA0-2AD265391317}|23b4125c3b8e2777bffee52e196a863b", response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_equal '14', response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, '{33C8274D-6811-409A-BF86-661F24084A2F}|{D50DB1B4-B6EC-4AF1-AFF7-71C2AA4A957B}|5be2c040bd46b7eebc70274659779acf')
    assert_success response
    assert_equal "{097C55B5-D020-40AD-8949-F9F5E4102F1D}|{D50DB1B4-B6EC-4AF1-AFF7-71C2AA4A957B}|5be2c040bd46b7eebc70274659779acf", response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, '', @options)
    assert_failure response
    assert_equal '255', response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('{230390C8-4A9E-4426-BDD3-15D072F135FE}|{3CC6E6A8-13E0-41A6-AB1E-71BE1AEEAE58}|1435f1a008137cd8508bf43751e07495')
    assert_success response
    assert_equal "{0A1A3FFF-C2A3-4B91-85FD-10D1C25B765B}||", response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('', @options)
    assert_failure response
    assert_equal '255', response.error_code
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "{F4337D04-B526-4A7E-A400-2A6DEADDCF57}|{5D5F8BF7-2D9D-42C3-AF32-08C5E62CD45E}|c0006d1d739905afc9e70beaf4194ea3", response.authorization
    assert response.test?
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)

    response = @gateway.verify(credit_card('2121212121212121'), @options)
    assert_failure response
    assert_equal '4', response.error_code
  end

  def test_successful_verify_credentials
    @gateway.expects(:ssl_post).returns(successful_verify_credentials_response)
    assert @gateway.verify_credentials
  end

  def test_failed_verify_credentials
    @gateway.expects(:ssl_post).returns(failed_verify_credentials_response)
    assert !@gateway.verify_credentials
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
opening connection to portal.nedsecure.co.za:443...
opened
starting SSL for portal.nedsecure.co.za:443...
SSL established
<- "POST /iVeriWebService/Service.asmx HTTP/1.1\r\nContent-Type: text/xml; charset=utf-8\r\nContent-Length: 1016\r\nSoapaction: http://iveri.com/Execute\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: portal.nedsecure.co.za\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n  <soap:Body>\n    <Execute xmlns=\"http://iveri.com/\">\n      <validateRequest>true</validateRequest>\n      <protocol>V_XML</protocol>\n      <protocolVersion>2.0</protocolVersion>\n      <request>&lt;V_XML Version=\"2.0\" CertificateID=\"CB69E68D-C7E7-46B9-9B7A-025DCABAD6EF\" Direction=\"Request\"&gt;\n  &lt;Transaction ApplicationID=\"D10A603D-4ADE-405B-93F1-826DFC0181E8\" Command=\"Debit\" Mode=\"Test\"&gt;\n    &lt;Amount&gt;100&lt;/Amount&gt;\n    &lt;Currency&gt;ZAR&lt;/Currency&gt;\n    &lt;ExpiryDate&gt;092018&lt;/ExpiryDate&gt;\n    &lt;MerchantReference&gt;b3ceea8b93d5611cbde7d162baef1245&lt;/MerchantReference&gt;\n    &lt;CardSecurityCode&gt;123&lt;/CardSecurityCode&gt;\n    &lt;PAN&gt;4242424242424242&lt;/PAN&gt;\n  &lt;/Transaction&gt;\n&lt;/V_XML&gt;</request>\n    </Execute>\n  </soap:Body>\n</soap:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/8.0\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Wed, 12 Apr 2017 19:46:44 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 2377\r\n"
-> "\r\n"
reading 2377 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ExecuteResponse xmlns=\"http://iveri.com/\"><ExecuteResult>&lt;V_XML Version=\"2.0\" Direction=\"Response\"&gt;\r\n  &lt;Transaction ApplicationID=\"{D10A603D-4ADE-405B-93F1-826DFC0181E8}\" Command=\"Debit\" Mode=\"Test\" RequestID=\"{5485B5EA-2661-4436-BAA9-CD6DD546FA0D}\"&gt;\r\n    &lt;Result Status=\"0\" AppServer=\"105IVERIAPPPR02\" DBServer=\"105iveridbpr01\" Gateway=\"Nedbank\" AcquirerCode=\"00\" /&gt;\r\n    &lt;Amount&gt;100&lt;/Amount&gt;\r\n    &lt;AuthorisationCode&gt;115205&lt;/AuthorisationCode&gt;\r\n    &lt;Currency&gt;ZAR&lt;/Currency&gt;\r\n    &lt;ExpiryDate&gt;092018&lt;/ExpiryDate&gt;\r\n    &lt;MerchantReference&gt;b3ceea8b93d5611cbde7d162baef1245&lt;/MerchantReference&gt;\r\n    &lt;Terminal&gt;Default&lt;/Terminal&gt;\r\n    &lt;TransactionIndex&gt;{10418186-FE90-44F9-AB7A-FEC11C9027F8}&lt;/TransactionIndex&gt;\r\n    &lt;MerchantName&gt;iVeri Payment Technology&lt;/MerchantName&gt;\r\n    &lt;MerchantUSN&gt;7771777&lt;/MerchantUSN&gt;\r\n    &lt;Acquirer&gt;NBPostilionBICISONBSouthAfrica&lt;/Acquirer&gt;\r\n    &lt;AcquirerReference&gt;70412:04077382&lt;/AcquirerReference&gt;\r\n    &lt;AcquirerDate&gt;20170412&lt;/AcquirerDate&gt;\r\n    &lt;AcquirerTime&gt;214645&lt;/AcquirerTime&gt;\r\n    &lt;DisplayAmount&gt;R 1.00&lt;/DisplayAmount&gt;\r\n    &lt;BIN&gt;4&lt;/BIN&gt;\r\n    &lt;Association&gt;VISA&lt;/Association&gt;\r\n    &lt;CardType&gt;Unknown CardType&lt;/CardType&gt;\r\n    &lt;Issuer&gt;Unknown&lt;/Issuer&gt;\r\n    &lt;Jurisdiction&gt;International&lt;/Jurisdiction&gt;\r\n    &lt;PANMode&gt;Keyed,CVV&lt;/PANMode&gt;\r\n    &lt;ReconReference&gt;04077382&lt;/ReconReference&gt;\r\n    &lt;CardHolderPresence&gt;CardNotPresent&lt;/CardHolderPresence&gt;\r\n    &lt;MerchantAddress&gt;MERCHANT ADDRESS&lt;/MerchantAddress&gt;\r\n    &lt;MerchantCity&gt;Sandton&lt;/MerchantCity&gt;\r\n    &lt;MerchantCountryCode&gt;ZA&lt;/MerchantCountryCode&gt;\r\n    &lt;MerchantCountry&gt;South Africa&lt;/MerchantCountry&gt;\r\n    &lt;DistributorName&gt;Nedbank&lt;/DistributorName&gt;\r\n    &lt;CCNumber&gt;4242........4242&lt;/CCNumber&gt;\r\n    &lt;PAN&gt;[4242........4242]&lt;/PAN&gt;\r\n  &lt;/Transaction&gt;\r\n&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>"
read 2377 bytes
Conn close
)
  end

  def post_scrubbed
    %q(
opening connection to portal.nedsecure.co.za:443...
opened
starting SSL for portal.nedsecure.co.za:443...
SSL established
<- "POST /iVeriWebService/Service.asmx HTTP/1.1\r\nContent-Type: text/xml; charset=utf-8\r\nContent-Length: 1016\r\nSoapaction: http://iveri.com/Execute\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: portal.nedsecure.co.za\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n  <soap:Body>\n    <Execute xmlns=\"http://iveri.com/\">\n      <validateRequest>true</validateRequest>\n      <protocol>V_XML</protocol>\n      <protocolVersion>2.0</protocolVersion>\n      <request>&lt;V_XML Version=\"2.0\" CertificateID=\"[FILTERED]\" Direction=\"Request\"&gt;\n  &lt;Transaction ApplicationID=\"D10A603D-4ADE-405B-93F1-826DFC0181E8\" Command=\"Debit\" Mode=\"Test\"&gt;\n    &lt;Amount&gt;100&lt;/Amount&gt;\n    &lt;Currency&gt;ZAR&lt;/Currency&gt;\n    &lt;ExpiryDate&gt;092018&lt;/ExpiryDate&gt;\n    &lt;MerchantReference&gt;b3ceea8b93d5611cbde7d162baef1245&lt;/MerchantReference&gt;\n    &lt;CardSecurityCode&gt;[FILTERED]&lt;/CardSecurityCode&gt;\n    &lt;PAN&gt;[FILTERED]&lt;/PAN&gt;\n  &lt;/Transaction&gt;\n&lt;/V_XML&gt;</request>\n    </Execute>\n  </soap:Body>\n</soap:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/8.0\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Wed, 12 Apr 2017 19:46:44 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 2377\r\n"
-> "\r\n"
reading 2377 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ExecuteResponse xmlns=\"http://iveri.com/\"><ExecuteResult>&lt;V_XML Version=\"2.0\" Direction=\"Response\"&gt;\r\n  &lt;Transaction ApplicationID=\"{D10A603D-4ADE-405B-93F1-826DFC0181E8}\" Command=\"Debit\" Mode=\"Test\" RequestID=\"{5485B5EA-2661-4436-BAA9-CD6DD546FA0D}\"&gt;\r\n    &lt;Result Status=\"0\" AppServer=\"105IVERIAPPPR02\" DBServer=\"105iveridbpr01\" Gateway=\"Nedbank\" AcquirerCode=\"00\" /&gt;\r\n    &lt;Amount&gt;100&lt;/Amount&gt;\r\n    &lt;AuthorisationCode&gt;115205&lt;/AuthorisationCode&gt;\r\n    &lt;Currency&gt;ZAR&lt;/Currency&gt;\r\n    &lt;ExpiryDate&gt;092018&lt;/ExpiryDate&gt;\r\n    &lt;MerchantReference&gt;b3ceea8b93d5611cbde7d162baef1245&lt;/MerchantReference&gt;\r\n    &lt;Terminal&gt;Default&lt;/Terminal&gt;\r\n    &lt;TransactionIndex&gt;{10418186-FE90-44F9-AB7A-FEC11C9027F8}&lt;/TransactionIndex&gt;\r\n    &lt;MerchantName&gt;iVeri Payment Technology&lt;/MerchantName&gt;\r\n    &lt;MerchantUSN&gt;7771777&lt;/MerchantUSN&gt;\r\n    &lt;Acquirer&gt;NBPostilionBICISONBSouthAfrica&lt;/Acquirer&gt;\r\n    &lt;AcquirerReference&gt;70412:04077382&lt;/AcquirerReference&gt;\r\n    &lt;AcquirerDate&gt;20170412&lt;/AcquirerDate&gt;\r\n    &lt;AcquirerTime&gt;214645&lt;/AcquirerTime&gt;\r\n    &lt;DisplayAmount&gt;R 1.00&lt;/DisplayAmount&gt;\r\n    &lt;BIN&gt;4&lt;/BIN&gt;\r\n    &lt;Association&gt;VISA&lt;/Association&gt;\r\n    &lt;CardType&gt;Unknown CardType&lt;/CardType&gt;\r\n    &lt;Issuer&gt;Unknown&lt;/Issuer&gt;\r\n    &lt;Jurisdiction&gt;International&lt;/Jurisdiction&gt;\r\n    &lt;PANMode&gt;Keyed,CVV&lt;/PANMode&gt;\r\n    &lt;ReconReference&gt;04077382&lt;/ReconReference&gt;\r\n    &lt;CardHolderPresence&gt;CardNotPresent&lt;/CardHolderPresence&gt;\r\n    &lt;MerchantAddress&gt;MERCHANT ADDRESS&lt;/MerchantAddress&gt;\r\n    &lt;MerchantCity&gt;Sandton&lt;/MerchantCity&gt;\r\n    &lt;MerchantCountryCode&gt;ZA&lt;/MerchantCountryCode&gt;\r\n    &lt;MerchantCountry&gt;South Africa&lt;/MerchantCountry&gt;\r\n    &lt;DistributorName&gt;Nedbank&lt;/DistributorName&gt;\r\n    &lt;CCNumber&gt;4242........4242&lt;/CCNumber&gt;\r\n    &lt;PAN&gt;[FILTERED]&lt;/PAN&gt;\r\n  &lt;/Transaction&gt;\r\n&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>"
read 2377 bytes
Conn close
)
  end

  def successful_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
&lt;Transaction ApplicationID="{D10A603D-4ADE-405B-93F1-826DFC0181E8}" Command="Debit" Mode="Test" RequestID="{F0568958-D10B-4093-A3BF-663168B06140}"&gt;
  &lt;Result Status="0" AppServer="105IVERIAPPPR01" DBServer="105IVERIDBPR01" Gateway="Nedbank" AcquirerCode="00" /&gt;
  &lt;Amount&gt;100&lt;/Amount&gt;
  &lt;AuthorisationCode&gt;537473&lt;/AuthorisationCode&gt;
  &lt;Currency&gt;ZAR&lt;/Currency&gt;
  &lt;ExpiryDate&gt;092018&lt;/ExpiryDate&gt;
  &lt;MerchantReference&gt;48b63446223ce91451fc3c1641a9ec03&lt;/MerchantReference&gt;
  &lt;Terminal&gt;Default&lt;/Terminal&gt;
  &lt;TransactionIndex&gt;{5CEF96FD-960E-4EA5-811F-D02CE6E36A96}&lt;/TransactionIndex&gt;
  &lt;MerchantName&gt;iVeri Payment Technology&lt;/MerchantName&gt;
  &lt;MerchantUSN&gt;7771777&lt;/MerchantUSN&gt;
  &lt;Acquirer&gt;NBPostilionBICISONBSouthAfrica&lt;/Acquirer&gt;
  &lt;AcquirerReference&gt;70417:04077982&lt;/AcquirerReference&gt;
  &lt;AcquirerDate&gt;20170417&lt;/AcquirerDate&gt;
  &lt;AcquirerTime&gt;190433&lt;/AcquirerTime&gt;
  &lt;DisplayAmount&gt;R 1.00&lt;/DisplayAmount&gt;
  &lt;BIN&gt;4&lt;/BIN&gt;
  &lt;Association&gt;VISA&lt;/Association&gt;
  &lt;CardType&gt;Unknown CardType&lt;/CardType&gt;
  &lt;Issuer&gt;Unknown&lt;/Issuer&gt;
  &lt;Jurisdiction&gt;International&lt;/Jurisdiction&gt;
  &lt;PANMode&gt;Keyed,CVV&lt;/PANMode&gt;
  &lt;ReconReference&gt;04077982&lt;/ReconReference&gt;
  &lt;CardHolderPresence&gt;CardNotPresent&lt;/CardHolderPresence&gt;
  &lt;MerchantAddress&gt;MERCHANT ADDRESS&lt;/MerchantAddress&gt;
  &lt;MerchantCity&gt;Sandton&lt;/MerchantCity&gt;
  &lt;MerchantCountryCode&gt;ZA&lt;/MerchantCountryCode&gt;
  &lt;MerchantCountry&gt;South Africa&lt;/MerchantCountry&gt;
  &lt;DistributorName&gt;Nedbank&lt;/DistributorName&gt;
  &lt;CCNumber&gt;4242........4242&lt;/CCNumber&gt;
  &lt;PAN&gt;4242........4242&lt;/PAN&gt;
&lt;/Transaction&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end

  def failed_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
  &lt;Transaction ApplicationID="{D10A603D-4ADE-405B-93F1-826DFC0181E8}" Command="Debit" Mode="Test" RequestID="{B14C3834-72B9-4ACA-B362-B3C9EC96E8C0}"&gt;
    &lt;Result Status="-1" Code="4" Description="Denied" Source="NBPostilionBICISONBSouthAfrica" AppServer="105IVERIAPPPR01" DBServer="105IVERIDBPR01" Gateway="Nedbank" AcquirerCode="05" AcquirerDescription="Do not Honour" /&gt;
    &lt;Amount&gt;100&lt;/Amount&gt;
    &lt;Currency&gt;ZAR&lt;/Currency&gt;
    &lt;ExpiryDate&gt;092018&lt;/ExpiryDate&gt;
    &lt;MerchantReference&gt;435a5d60b5fe874840c34e2e0504626b&lt;/MerchantReference&gt;
    &lt;Terminal&gt;Default&lt;/Terminal&gt;
    &lt;TransactionIndex&gt;{B35872A9-39C7-4DB8-9774-A5E34FFA519E}&lt;/TransactionIndex&gt;
    &lt;MerchantName&gt;iVeri Payment Technology&lt;/MerchantName&gt;
    &lt;MerchantUSN&gt;7771777&lt;/MerchantUSN&gt;
    &lt;Acquirer&gt;NBPostilionBICISONBSouthAfrica&lt;/Acquirer&gt;
    &lt;AcquirerReference&gt;70417:04077988&lt;/AcquirerReference&gt;
    &lt;AcquirerDate&gt;20170417&lt;/AcquirerDate&gt;
    &lt;AcquirerTime&gt;192038&lt;/AcquirerTime&gt;
    &lt;DisplayAmount&gt;R 1.00&lt;/DisplayAmount&gt;
    &lt;BIN&gt;2&lt;/BIN&gt;
    &lt;Association&gt;Unknown Association&lt;/Association&gt;
    &lt;CardType&gt;Unknown CardType&lt;/CardType&gt;
    &lt;Issuer&gt;Unknown&lt;/Issuer&gt;
    &lt;Jurisdiction&gt;Local&lt;/Jurisdiction&gt;
    &lt;PANMode&gt;Keyed,CVV&lt;/PANMode&gt;
    &lt;ReconReference&gt;04077988&lt;/ReconReference&gt;
    &lt;CardHolderPresence&gt;CardNotPresent&lt;/CardHolderPresence&gt;
    &lt;MerchantAddress&gt;MERCHANT ADDRESS&lt;/MerchantAddress&gt;
    &lt;MerchantCity&gt;Sandton&lt;/MerchantCity&gt;
    &lt;MerchantCountryCode&gt;ZA&lt;/MerchantCountryCode&gt;
    &lt;MerchantCountry&gt;South Africa&lt;/MerchantCountry&gt;
    &lt;DistributorName&gt;Nedbank&lt;/DistributorName&gt;
    &lt;CCNumber&gt;2121........2121&lt;/CCNumber&gt;
    &lt;PAN&gt;2121........2121&lt;/PAN&gt;
  &lt;/Transaction&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end

  def successful_authorize_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
  &lt;Transaction ApplicationID="{D10A603D-4ADE-405B-93F1-826DFC0181E8}" Command="Authorisation" Mode="Test" RequestID="{B90D7CDB-C8E8-4477-BDF2-695F28137874}"&gt;
    &lt;Result Status="0" AppServer="105IVERIAPPPR01" DBServer="105IVERIDBPR01" Gateway="Nedbank" AcquirerCode="00" /&gt;
    &lt;Amount&gt;100&lt;/Amount&gt;
    &lt;AuthorisationCode&gt;541267&lt;/AuthorisationCode&gt;
    &lt;Currency&gt;ZAR&lt;/Currency&gt;
    &lt;ExpiryDate&gt;092018&lt;/ExpiryDate&gt;
    &lt;MerchantReference&gt;23b4125c3b8e2777bffee52e196a863b&lt;/MerchantReference&gt;
    &lt;Terminal&gt;Default&lt;/Terminal&gt;
    &lt;TransactionIndex&gt;{EF0DC64E-2D00-4B6C-BDA0-2AD265391317}&lt;/TransactionIndex&gt;
    &lt;MerchantName&gt;iVeri Payment Technology&lt;/MerchantName&gt;
    &lt;MerchantUSN&gt;7771777&lt;/MerchantUSN&gt;
    &lt;Acquirer&gt;NBPostilionBICISONBSouthAfrica&lt;/Acquirer&gt;
    &lt;AcquirerReference&gt;70417:04078057&lt;/AcquirerReference&gt;
    &lt;AcquirerDate&gt;20170417&lt;/AcquirerDate&gt;
    &lt;AcquirerTime&gt;200747&lt;/AcquirerTime&gt;
    &lt;DisplayAmount&gt;R 1.00&lt;/DisplayAmount&gt;
    &lt;BIN&gt;4&lt;/BIN&gt;
    &lt;Association&gt;VISA&lt;/Association&gt;
    &lt;CardType&gt;Unknown CardType&lt;/CardType&gt;
    &lt;Issuer&gt;Unknown&lt;/Issuer&gt;
    &lt;Jurisdiction&gt;International&lt;/Jurisdiction&gt;
    &lt;PANMode&gt;Keyed,CVV&lt;/PANMode&gt;
    &lt;ReconReference&gt;04078057&lt;/ReconReference&gt;
    &lt;CardHolderPresence&gt;CardNotPresent&lt;/CardHolderPresence&gt;
    &lt;MerchantAddress&gt;MERCHANT ADDRESS&lt;/MerchantAddress&gt;
    &lt;MerchantCity&gt;Sandton&lt;/MerchantCity&gt;
    &lt;MerchantCountryCode&gt;ZA&lt;/MerchantCountryCode&gt;
    &lt;MerchantCountry&gt;South Africa&lt;/MerchantCountry&gt;
    &lt;DistributorName&gt;Nedbank&lt;/DistributorName&gt;
    &lt;CCNumber&gt;4242........4242&lt;/CCNumber&gt;
    &lt;PAN&gt;4242........4242&lt;/PAN&gt;
  &lt;/Transaction&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end

  def failed_authorize_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
  &lt;Transaction ApplicationID="{D10A603D-4ADE-405B-93F1-826DFC0181E8}" Command="Authorisation" Mode="Test" RequestID="{3A1A29BE-288F-4FEE-8C15-B3BB8A207544}"&gt;
    &lt;Result Status="-1" Code="4" Description="Denied" Source="NBPostilionBICISONBSouthAfrica" AppServer="105IVERIAPPPR01" DBServer="105IVERIDBPR01" Gateway="Nedbank" AcquirerCode="05" AcquirerDescription="Do not Honour" /&gt;
    &lt;Amount&gt;100&lt;/Amount&gt;
    &lt;Currency&gt;ZAR&lt;/Currency&gt;
    &lt;ExpiryDate&gt;092018&lt;/ExpiryDate&gt;
    &lt;MerchantReference&gt;3d12442ea042e78fd33057b7b50c76f7&lt;/MerchantReference&gt;
    &lt;Terminal&gt;Default&lt;/Terminal&gt;
    &lt;TransactionIndex&gt;{8AC33FB1-0D2E-42C7-A0DB-CF8B20279825}&lt;/TransactionIndex&gt;
    &lt;MerchantName&gt;iVeri Payment Technology&lt;/MerchantName&gt;
    &lt;MerchantUSN&gt;7771777&lt;/MerchantUSN&gt;
    &lt;Acquirer&gt;NBPostilionBICISONBSouthAfrica&lt;/Acquirer&gt;
    &lt;AcquirerReference&gt;70417:04078062&lt;/AcquirerReference&gt;
    &lt;AcquirerDate&gt;20170417&lt;/AcquirerDate&gt;
    &lt;AcquirerTime&gt;202648&lt;/AcquirerTime&gt;
    &lt;DisplayAmount&gt;R 1.00&lt;/DisplayAmount&gt;
    &lt;BIN&gt;2&lt;/BIN&gt;
    &lt;Association&gt;Unknown Association&lt;/Association&gt;
    &lt;CardType&gt;Unknown CardType&lt;/CardType&gt;
    &lt;Issuer&gt;Unknown&lt;/Issuer&gt;
    &lt;Jurisdiction&gt;Local&lt;/Jurisdiction&gt;
    &lt;PANMode&gt;Keyed,CVV&lt;/PANMode&gt;
    &lt;ReconReference&gt;04078062&lt;/ReconReference&gt;
    &lt;CardHolderPresence&gt;CardNotPresent&lt;/CardHolderPresence&gt;
    &lt;MerchantAddress&gt;MERCHANT ADDRESS&lt;/MerchantAddress&gt;
    &lt;MerchantCity&gt;Sandton&lt;/MerchantCity&gt;
    &lt;MerchantCountryCode&gt;ZA&lt;/MerchantCountryCode&gt;
    &lt;MerchantCountry&gt;South Africa&lt;/MerchantCountry&gt;
    &lt;DistributorName&gt;Nedbank&lt;/DistributorName&gt;
    &lt;CCNumber&gt;2121........2121&lt;/CCNumber&gt;
    &lt;PAN&gt;2121........2121&lt;/PAN&gt;
  &lt;/Transaction&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end

  def successful_capture_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
  &lt;Transaction ApplicationID="{D10A603D-4ADE-405B-93F1-826DFC0181E8}" Command="Debit" Mode="Test" RequestID="{7C91245F-607D-44AE-8958-C26E447BAEB7}"&gt;
    &lt;Result Status="0" AppServer="105IVERIAPPPR02" DBServer="105iveridbpr01" Gateway="Nedbank" AcquirerCode="00" /&gt;
    &lt;Amount&gt;100&lt;/Amount&gt;
    &lt;AuthorisationCode&gt;541268&lt;/AuthorisationCode&gt;
    &lt;Currency&gt;ZAR&lt;/Currency&gt;
    &lt;ExpiryDate&gt;092018&lt;/ExpiryDate&gt;
    &lt;MerchantReference&gt;23b4125c3b8e2777bffee52e196a863b&lt;/MerchantReference&gt;
    &lt;Terminal&gt;Default&lt;/Terminal&gt;
    &lt;TransactionIndex&gt;{EF0DC64E-2D00-4B6C-BDA0-2AD265391317}&lt;/TransactionIndex&gt;
    &lt;MerchantName&gt;iVeri Payment Technology&lt;/MerchantName&gt;
    &lt;MerchantUSN&gt;7771777&lt;/MerchantUSN&gt;
    &lt;Acquirer&gt;NBPostilionBICISONBSouthAfrica&lt;/Acquirer&gt;
    &lt;AcquirerReference&gt;70417:04078057&lt;/AcquirerReference&gt;
    &lt;AcquirerDate&gt;20170417&lt;/AcquirerDate&gt;
    &lt;AcquirerTime&gt;200748&lt;/AcquirerTime&gt;
    &lt;DisplayAmount&gt;R 1.00&lt;/DisplayAmount&gt;
    &lt;BIN&gt;4&lt;/BIN&gt;
    &lt;Association&gt;VISA&lt;/Association&gt;
    &lt;CardType&gt;Unknown CardType&lt;/CardType&gt;
    &lt;Issuer&gt;Unknown&lt;/Issuer&gt;
    &lt;Jurisdiction&gt;International&lt;/Jurisdiction&gt;
    &lt;PANMode&gt;Keyed,CVV&lt;/PANMode&gt;
    &lt;ReconReference&gt;04078057&lt;/ReconReference&gt;
    &lt;CardHolderPresence&gt;CardNotPresent&lt;/CardHolderPresence&gt;
    &lt;MerchantAddress&gt;MERCHANT ADDRESS&lt;/MerchantAddress&gt;
    &lt;MerchantCity&gt;Sandton&lt;/MerchantCity&gt;
    &lt;MerchantCountryCode&gt;ZA&lt;/MerchantCountryCode&gt;
    &lt;MerchantCountry&gt;South Africa&lt;/MerchantCountry&gt;
    &lt;DistributorName&gt;Nedbank&lt;/DistributorName&gt;
    &lt;CCNumber&gt;4242........4242&lt;/CCNumber&gt;
    &lt;PAN&gt;4242........4242&lt;/PAN&gt;
  &lt;/Transaction&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end

  def failed_capture_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
  &lt;Transaction ApplicationID="{D10A603D-4ADE-405B-93F1-826DFC0181E8}" Command="Debit" Mode="Test" RequestID="{9DAAA002-0EF9-46DC-A440-8DCD9E78B36F}"&gt;
    &lt;Result Status="-1" Code="14" Description="Missing PAN" Source="NBPostilionBICISONBSouthAfricaTestProvider" AppServer="105IVERIAPPPR02" DBServer="105iveridbpr01" Gateway="Nedbank" AcquirerCode="" AcquirerDescription="" /&gt;
  &lt;/Transaction&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end

  def successful_refund_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
  &lt;Transaction ApplicationID="{D10A603D-4ADE-405B-93F1-826DFC0181E8}" Command="Credit" Mode="Test" RequestID="{097C55B5-D020-40AD-8949-F9F5E4102F1D}"&gt;
    &lt;Result Status="0" AppServer="105IVERIAPPPR02" DBServer="105iveridbpr01" Gateway="Nedbank" AcquirerCode="00" /&gt;
    &lt;Amount&gt;100&lt;/Amount&gt;
    &lt;AuthorisationCode&gt;541996&lt;/AuthorisationCode&gt;
    &lt;Currency&gt;ZAR&lt;/Currency&gt;
    &lt;ExpiryDate&gt;092018&lt;/ExpiryDate&gt;
    &lt;MerchantReference&gt;5be2c040bd46b7eebc70274659779acf&lt;/MerchantReference&gt;
    &lt;Terminal&gt;Default&lt;/Terminal&gt;
    &lt;TransactionIndex&gt;{D50DB1B4-B6EC-4AF1-AFF7-71C2AA4A957B}&lt;/TransactionIndex&gt;
    &lt;MerchantName&gt;iVeri Payment Technology&lt;/MerchantName&gt;
    &lt;MerchantUSN&gt;7771777&lt;/MerchantUSN&gt;
    &lt;Acquirer&gt;NBPostilionBICISONBSouthAfrica&lt;/Acquirer&gt;
    &lt;AcquirerReference&gt;70417:04078059&lt;/AcquirerReference&gt;
    &lt;AcquirerDate&gt;20170417&lt;/AcquirerDate&gt;
    &lt;AcquirerTime&gt;201956&lt;/AcquirerTime&gt;
    &lt;DisplayAmount&gt;R 1.00&lt;/DisplayAmount&gt;
    &lt;BIN&gt;4&lt;/BIN&gt;
    &lt;Association&gt;VISA&lt;/Association&gt;
    &lt;CardType&gt;Unknown CardType&lt;/CardType&gt;
    &lt;Issuer&gt;Unknown&lt;/Issuer&gt;
    &lt;Jurisdiction&gt;International&lt;/Jurisdiction&gt;
    &lt;PANMode /&gt;
    &lt;ReconReference&gt;04078059&lt;/ReconReference&gt;
    &lt;CardHolderPresence&gt;CardNotPresent&lt;/CardHolderPresence&gt;
    &lt;MerchantAddress&gt;MERCHANT ADDRESS&lt;/MerchantAddress&gt;
    &lt;MerchantCity&gt;Sandton&lt;/MerchantCity&gt;
    &lt;MerchantCountryCode&gt;ZA&lt;/MerchantCountryCode&gt;
    &lt;MerchantCountry&gt;South Africa&lt;/MerchantCountry&gt;
    &lt;DistributorName&gt;Nedbank&lt;/DistributorName&gt;
    &lt;CCNumber&gt;4242........4242&lt;/CCNumber&gt;
    &lt;PAN&gt;4242........4242&lt;/PAN&gt;
  &lt;/Transaction&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end

  def failed_refund_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
  &lt;Transaction ApplicationID="{D10A603D-4ADE-405B-93F1-826DFC0181E8}" Command="Credit" Mode="Test" RequestID="{5097A60A-A112-42F1-9490-FA17A859E7A3}"&gt;
    &lt;Result Status="-1" Code="255" Description="Credit is not supported for ApplicationID (D10A603D-4ADE-405B-93F1-826DFC0181E8)" Source="PortalService" AppServer="105IVERIAPPPR02" DBServer="105iveridbpr01" Gateway="Nedbank" AcquirerCode="" AcquirerDescription="" /&gt;
  &lt;/Transaction&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end

  def successful_void_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
  &lt;Transaction ApplicationID="{D10A603D-4ADE-405B-93F1-826DFC0181E8}" Command="Void" Mode="Test" RequestID="{0A1A3FFF-C2A3-4B91-85FD-10D1C25B765B}"&gt;
    &lt;Result Status="0" AppServer="105IVERIAPPPR02" DBServer="105iveridbpr01" Gateway="Nedbank" /&gt;
    &lt;OriginalRequestID&gt;{230390C8-4A9E-4426-BDD3-15D072F135FE}&lt;/OriginalRequestID&gt;
  &lt;/Transaction&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end

  def failed_void_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
  &lt;Transaction ApplicationID="{D10A603D-4ADE-405B-93F1-826DFC0181E8}" Command="Void" Mode="Test" RequestID="{AE97CCE4-0631-4F08-AB47-9C2698ABEC75}"&gt;
    &lt;Result Status="-1" Code="255" Description="Missing OriginalMerchantTrace" Source="NBPostilionBICISONBSouthAfricaTestProvider" AppServer="105IVERIAPPPR01" DBServer="105IVERIDBPR01" Gateway="Nedbank" AcquirerCode="" AcquirerDescription="" /&gt;
  &lt;/Transaction&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end

  def successful_verify_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
  &lt;Transaction ApplicationID="{D10A603D-4ADE-405B-93F1-826DFC0181E8}" Command="Authorisation" Mode="Test" RequestID="{F4337D04-B526-4A7E-A400-2A6DEADDCF57}"&gt;
    &lt;Result Status="0" AppServer="105IVERIAPPPR01" DBServer="105IVERIDBPR01" Gateway="Nedbank" AcquirerCode="00" /&gt;
    &lt;Amount&gt;0&lt;/Amount&gt;
    &lt;AuthorisationCode&gt;613755&lt;/AuthorisationCode&gt;
    &lt;Currency&gt;ZAR&lt;/Currency&gt;
    &lt;ExpiryDate&gt;092018&lt;/ExpiryDate&gt;
    &lt;MerchantReference&gt;c0006d1d739905afc9e70beaf4194ea3&lt;/MerchantReference&gt;
    &lt;Terminal&gt;Default&lt;/Terminal&gt;
    &lt;TransactionIndex&gt;{5D5F8BF7-2D9D-42C3-AF32-08C5E62CD45E}&lt;/TransactionIndex&gt;
    &lt;MerchantName&gt;iVeri Payment Technology&lt;/MerchantName&gt;
    &lt;MerchantUSN&gt;7771777&lt;/MerchantUSN&gt;
    &lt;Acquirer&gt;NBPostilionBICISONBSouthAfrica&lt;/Acquirer&gt;
    &lt;AcquirerReference&gt;70418:04078335&lt;/AcquirerReference&gt;
    &lt;AcquirerDate&gt;20170418&lt;/AcquirerDate&gt;
    &lt;AcquirerTime&gt;161555&lt;/AcquirerTime&gt;
    &lt;DisplayAmount&gt;R 0.00&lt;/DisplayAmount&gt;
    &lt;BIN&gt;4&lt;/BIN&gt;
    &lt;Association&gt;VISA&lt;/Association&gt;
    &lt;CardType&gt;Unknown CardType&lt;/CardType&gt;
    &lt;Issuer&gt;Unknown&lt;/Issuer&gt;
    &lt;Jurisdiction&gt;International&lt;/Jurisdiction&gt;
    &lt;PANMode&gt;Keyed,CVV&lt;/PANMode&gt;
    &lt;ReconReference&gt;04078335&lt;/ReconReference&gt;
    &lt;CardHolderPresence&gt;CardNotPresent&lt;/CardHolderPresence&gt;
    &lt;MerchantAddress&gt;MERCHANT ADDRESS&lt;/MerchantAddress&gt;
    &lt;MerchantCity&gt;Sandton&lt;/MerchantCity&gt;
    &lt;MerchantCountryCode&gt;ZA&lt;/MerchantCountryCode&gt;
    &lt;MerchantCountry&gt;South Africa&lt;/MerchantCountry&gt;
    &lt;DistributorName&gt;Nedbank&lt;/DistributorName&gt;
    &lt;CCNumber&gt;4242........4242&lt;/CCNumber&gt;
    &lt;PAN&gt;4242........4242&lt;/PAN&gt;
  &lt;/Transaction&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end

  def failed_verify_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
  &lt;Transaction ApplicationID="{D10A603D-4ADE-405B-93F1-826DFC0181E8}" Command="Authorisation" Mode="Test" RequestID="{A700FAE2-2A76-407D-A540-B41668E2B703}"&gt;
    &lt;Result Status="-1" Code="4" Description="Denied" Source="NBPostilionBICISONBSouthAfrica" AppServer="105IVERIAPPPR02" DBServer="105iveridbpr01" Gateway="Nedbank" AcquirerCode="05" AcquirerDescription="Do not Honour" /&gt;
    &lt;Amount&gt;0&lt;/Amount&gt;
    &lt;Currency&gt;ZAR&lt;/Currency&gt;
    &lt;ExpiryDate&gt;092018&lt;/ExpiryDate&gt;
    &lt;MerchantReference&gt;e955afb03f224284b09ad6ae7e9b4683&lt;/MerchantReference&gt;
    &lt;Terminal&gt;Default&lt;/Terminal&gt;
    &lt;TransactionIndex&gt;{2A378547-AEA4-48E1-8A3E-29F9BBEA954D}&lt;/TransactionIndex&gt;
    &lt;MerchantName&gt;iVeri Payment Technology&lt;/MerchantName&gt;
    &lt;MerchantUSN&gt;7771777&lt;/MerchantUSN&gt;
    &lt;Acquirer&gt;NBPostilionBICISONBSouthAfrica&lt;/Acquirer&gt;
    &lt;AcquirerReference&gt;70418:04078337&lt;/AcquirerReference&gt;
    &lt;AcquirerDate&gt;20170418&lt;/AcquirerDate&gt;
    &lt;AcquirerTime&gt;161716&lt;/AcquirerTime&gt;
    &lt;DisplayAmount&gt;R 0.00&lt;/DisplayAmount&gt;
    &lt;BIN&gt;2&lt;/BIN&gt;
    &lt;Association&gt;Unknown Association&lt;/Association&gt;
    &lt;CardType&gt;Unknown CardType&lt;/CardType&gt;
    &lt;Issuer&gt;Unknown&lt;/Issuer&gt;
    &lt;Jurisdiction&gt;Local&lt;/Jurisdiction&gt;
    &lt;PANMode&gt;Keyed,CVV&lt;/PANMode&gt;
    &lt;ReconReference&gt;04078337&lt;/ReconReference&gt;
    &lt;CardHolderPresence&gt;CardNotPresent&lt;/CardHolderPresence&gt;
    &lt;MerchantAddress&gt;MERCHANT ADDRESS&lt;/MerchantAddress&gt;
    &lt;MerchantCity&gt;Sandton&lt;/MerchantCity&gt;
    &lt;MerchantCountryCode&gt;ZA&lt;/MerchantCountryCode&gt;
    &lt;MerchantCountry&gt;South Africa&lt;/MerchantCountry&gt;
    &lt;DistributorName&gt;Nedbank&lt;/DistributorName&gt;
    &lt;CCNumber&gt;2121........2121&lt;/CCNumber&gt;
    &lt;PAN&gt;2121........2121&lt;/PAN&gt;
  &lt;/Transaction&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end

  def successful_verify_credentials_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
  &lt;Transaction ApplicationID="{D10A603D-4ADE-405B-93F1-826DFC0181E8}" Command="Void" Mode="Test" RequestID="{5ED922D0-92AD-40DF-9019-320591A4BA59}"&gt;
    &lt;Result Status="-1" Code="255" Description="Missing OriginalMerchantTrace" Source="NBPostilionBICISONBSouthAfricaTestProvider" AppServer="105IVERIAPPPR01" DBServer="105IVERIDBPR01" Gateway="Nedbank" AcquirerCode="" AcquirerDescription="" /&gt;
  &lt;/Transaction&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end

  def failed_verify_credentials_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><ExecuteResponse xmlns="http://iveri.com/"><ExecuteResult>&lt;V_XML Version="2.0" Direction="Response"&gt;
  &lt;Result Status="-1" Code="255" Description="The ApplicationID {11111111-1111-1111-1111-111111111111} is not valid for the current CertificateID {11111111-1111-1111-1111-111111111111}" Source="RequestHandler" RequestID="{EE6E5B39-63AD-402C-8331-F25082AD8564}" AppServer="105IVERIAPPPR01" DBServer="105IVERIDBPR01" Gateway="Nedbank" AcquirerCode="" AcquirerDescription="" /&gt;
&lt;/V_XML&gt;</ExecuteResult></ExecuteResponse></soap:Body></soap:Envelope>
    XML
  end
end
