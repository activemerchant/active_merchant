require 'test_helper'

class BlackbaudBbpsTest < Test::Unit::TestCase
  def setup
    @gateway = BlackbaudBbpsGateway.new(url: 'foo', username: 'bar', password: 'sekrit')
    @credit_card = credit_card

    @options = {
      client_app: 'Evergiving Test'
    }
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)
    response = @gateway.store(@credit_card, @options)

    assert_success response
    assert_equal '1a738830-03f4-4f1a-8ccd-3b11dc211113', response.authorization
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)
    response = @gateway.store(@credit_card, @options)

    assert_failure response
    assert_equal 'Credit card number is not valid.', response.message  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-XML
opening connection to bbec1test2.blackbaud.com.au:443...
opened
starting SSL for bbec1test2.blackbaud.com.au:443...
SSL established
<- "POST /bbAppFx/AppFxWebService.asmx HTTP/1.1\r\nContent-Type: text/xml; charset=utf-8\r\nHost: bbec1test2.blackbaud.com.au\r\nSoapaction: Blackbaud.AppFx.WebService.API.1/CreditCardVault\r\nAuthorization: Basic Zm9vOmJhcg==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nContent-Length: 703\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<soap12:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap12=\"http://www.w3.org/2003/05/soap-envelope\"><soap12:Body><CreditCardVaultRequest xmlns=\"Blackbaud.AppFx.WebService.API.1\"><ClientAppInfo REDatabaseToUse=\"BBInfinity\" ClientAppName=\"Evergiving Test\" TimeOutSeconds=\"100\" RunAsUserID=\"00000000-0000-0000-0000-000000000000\"/><CreditCards><CreditCardInfo><CardHolder>Longbob Longsen</CardHolder><CardNumber>4000100011112224</CardNumber><ExpirationDate><Month>09</Month><Year>2018</Year></ExpirationDate></CreditCardInfo></CreditCards></CreditCardVaultRequest></soap12:Body></soap12:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: application/soap+xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/7.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Frame-Options: sameorigin\r\n"
-> "Date: Wed, 06 Dec 2017 01:57:56 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 499\r\n"
-> "\r\n"
reading 499 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><CreditCardVaultReply xmlns=\"Blackbaud.AppFx.WebService.API.1\"><CreditCardResponses><CreditCardVaultResponse><Token>1a738830-03f4-4f1a-8ccd-3b11dc211113</Token><Status>Success</Status></CreditCardVaultResponse></CreditCardResponses></CreditCardVaultReply></soap:Body></soap:Envelope>"
read 499 bytes
Conn close
    XML
  end

  def post_scrubbed
    <<-XML
opening connection to bbec1test2.blackbaud.com.au:443...
opened
starting SSL for bbec1test2.blackbaud.com.au:443...
SSL established
<- "POST /bbAppFx/AppFxWebService.asmx HTTP/1.1\r\nContent-Type: text/xml; charset=utf-8\r\nHost: bbec1test2.blackbaud.com.au\r\nSoapaction: Blackbaud.AppFx.WebService.API.1/CreditCardVault\r\nAuthorization: Basic [FILTERED]==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nContent-Length: 703\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<soap12:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap12=\"http://www.w3.org/2003/05/soap-envelope\"><soap12:Body><CreditCardVaultRequest xmlns=\"Blackbaud.AppFx.WebService.API.1\"><ClientAppInfo REDatabaseToUse=\"BBInfinity\" ClientAppName=\"Evergiving Test\" TimeOutSeconds=\"100\" RunAsUserID=\"00000000-0000-0000-0000-000000000000\"/><CreditCards><CreditCardInfo><CardHolder>Longbob Longsen</CardHolder><CardNumber>[FILTERED]</CardNumber><ExpirationDate><Month>09</Month><Year>2018</Year></ExpirationDate></CreditCardInfo></CreditCards></CreditCardVaultRequest></soap12:Body></soap12:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: application/soap+xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/7.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Frame-Options: sameorigin\r\n"
-> "Date: Wed, 06 Dec 2017 01:57:56 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 499\r\n"
-> "\r\n"
reading 499 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><CreditCardVaultReply xmlns=\"Blackbaud.AppFx.WebService.API.1\"><CreditCardResponses><CreditCardVaultResponse><Token>1a738830-03f4-4f1a-8ccd-3b11dc211113</Token><Status>Success</Status></CreditCardVaultResponse></CreditCardResponses></CreditCardVaultReply></soap:Body></soap:Envelope>"
read 499 bytes
Conn close
    XML
  end

  def successful_store_response
    %(
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><CreditCardVaultReply xmlns="Blackbaud.AppFx.WebService.API.1"><CreditCardResponses><CreditCardVaultResponse><Token>1a738830-03f4-4f1a-8ccd-3b11dc211113</Token><Status>Success</Status></CreditCardVaultResponse></CreditCardResponses></CreditCardVaultReply></soap:Body></soap:Envelope>
    )
  end

  def failed_store_response
    %(
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><CreditCardVaultReply xmlns="Blackbaud.AppFx.WebService.API.1"><CreditCardResponses><CreditCardVaultResponse><Token>00000000-0000-0000-0000-000000000000</Token><Status>Fail</Status><ErrorMessage>Credit card number is not valid.</ErrorMessage></CreditCardVaultResponse></CreditCardResponses></CreditCardVaultReply></soap:Body></soap:Envelope>
    )
  end
end
