require 'test_helper'

class BarclaycardSmartpayTest < Test::Unit::TestCase
  def setup
    @gateway = BarclaycardSmartpayGateway.new(
      company: 'company',
      merchant: 'merchant',
      password: 'password'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }

    @avs_address = @options
    @avs_address.update(billing_address: {
        name:     'Jim Smith',
        street:   'Test AVS result',
        houseNumberOrName: '2',
        city:     'Cupertino',
        state:    'CA',
        zip:      '95014',
        country:  'US'
        })
  end

  def test_successful_authorize
    @gateway.stubs(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '7914002629995504', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.stubs(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_capture
    @gateway.stubs(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, '7914002629995504', @options)
    assert_success response
    assert response.test?
  end

  def test_failed_capture
    @gateway.stubs(:ssl_post).raises(ActiveMerchant::ResponseError.new(stub(:code => '500', :body => failed_capture_response)))

    response = @gateway.capture(@amount, '0000000000000000', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, '7914002629995504', @options)
    assert_success response
    assert response.test?

  end

  def test_failed_refund
    @gateway.stubs(:ssl_post).raises(ActiveMerchant::ResponseError.new(stub(:code => '500', :body => failed_refund_response)))

    response = @gateway.refund(@amount, '0000000000000000', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('7914002629995504', @options)
    assert_success response
    assert response.test?
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_unsuccessful_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal "Refused", response.message
  end

  def test_fractional_currency
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    @gateway.expects(:post_data).with do |params|
      '100' == params['amount.value'] && 'JPY' == params['amount.currency']
    end

    @options[:currency] = 'JPY'

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_failed_store
    @gateway.stubs(:ssl_post).raises(ActiveMerchant::ResponseError.new(stub(:code => '422', :body => failed_store_response)))

    response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(failed_avs_response)

    response = @gateway.authorize(@amount, @credit_card, @avs_address)
    assert_equal "N", response.avs_result['code']
    assert response.test?
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_authorize_response
    'pspReference=7914002629995504&authCode=56469&resultCode=Authorised'
  end

  def failed_authorize_response
    'pspReference=7914002630895750&refusalReason=Refused&resultCode=Refused'
  end

  def successful_capture_response
    'pspReference=8814002632606717&response=%5Bcapture-received%5D'
  end

  def failed_capture_response
    'validation 100 No amount specified'
  end

  def successful_refund_response
    'pspReference=8814002634988063&response=%5Brefund-received%5D'
  end

  def failed_refund_response
    'validation 100 No amount specified'
  end

  def successful_void_response
    'pspReference=7914002636728161&response=%5Bcancel-received%5D'
  end

  def successful_store_response
    'alias=H167852639363479&aliasType=Default&pspReference=8614540938336754&rechargeReference=8314540938334240&recurringDetailReference=8414540862673349&result=Success'
  end

  def failed_store_response
    'errorType=validation&errorCode=129&message=Expiry+Date+Invalid&status=422'
  end

  def failed_avs_response
    'additionalData.liabilityShift=false&additionalData.authCode=3115&additionalData.avsResult=2+Neither+postal+code+nor+address+match&additionalData.cardHolderName=Longbob+Longsen&additionalData.threeDOffered=false&additionalData.refusalReasonRaw=AUTHORISED&additionalData.issuerCountry=US&additionalData.cvcResult=1+Matches&additionalData.avsResultRaw=2&additionalData.threeDAuthenticated=false&additionalData.cvcResultRaw=1&additionalData.acquirerCode=SmartPayTestPmmAcquirer&additionalData.acquirerReference=7F50RDN2L06&fraudResult.accountScore=170&fraudResult.results.0.accountScore=20&fraudResult.results.0.checkId=2&fraudResult.results.0.name=CardChunkUsage&fraudResult.results.1.accountScore=25&fraudResult.results.1.checkId=4&fraudResult.results.1.name=HolderNameUsage&fraudResult.results.2.accountScore=25&fraudResult.results.2.checkId=8&fraudResult.results.2.name=ShopperEmailUsage&fraudResult.results.3.accountScore=0&fraudResult.results.3.checkId=1&fraudResult.results.3.name=PaymentDetailRefCheck&fraudResult.results.4.accountScore=0&fraudResult.results.4.checkId=13&fraudResult.results.4.name=IssuerRefCheck&fraudResult.results.5.accountScore=0&fraudResult.results.5.checkId=15&fraudResult.results.5.name=IssuingCountryReferral&fraudResult.results.6.accountScore=0&fraudResult.results.6.checkId=26&fraudResult.results.6.name=ShopperEmailRefCheck&fraudResult.results.7.accountScore=0&fraudResult.results.7.checkId=27&fraudResult.results.7.name=PmOwnerRefCheck&fraudResult.results.8.accountScore=0&fraudResult.results.8.checkId=10&fraudResult.results.8.name=HolderNameContainsNumber&fraudResult.results.9.accountScore=0&fraudResult.results.9.checkId=11&fraudResult.results.9.name=HolderNameIsOneWord&fraudResult.results.10.accountScore=0&fraudResult.results.10.checkId=21&fraudResult.results.10.name=EmailDomainValidation&fraudResult.results.11.accountScore=100&fraudResult.results.11.checkId=20&fraudResult.results.11.name=AVSAuthResultCheck&fraudResult.results.12.accountScore=0&fraudResult.results.12.checkId=25&fraudResult.results.12.name=CVCAuthResultCheck&pspReference=8814591938804745&refusalReason=FRAUD-CANCELLED&resultCode=Cancelled&authCode=3115'
  end

  def transcript
    %(
    opening connection to pal-test.barclaycardsmartpay.com:443...
    opened
    starting SSL for pal-test.barclaycardsmartpay.com:443...
    SSL established
    <- "POST /pal/servlet/Payment/v12/authorise HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded; charset=utf-8\r\nAuthorization: Basic d3NAQ29tcGFueS5QbHVzNTAwQ1k6UVpiWWd3Z2pDejNiZEdiNEhqYXk=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.barclaycardsmartpay.com\r\nContent-Length: 466\r\n\r\n"
    <- "merchantAccount=Plus500CYEcom&reference=1&shopperEmail=long%40bob.com&shopperReference=Longbob+Longsen&amount.currency=EUR&amount.value=100&card.cvc=737&card.expiryMonth=06&card.expiryYear=2016&card.holderName=Longbob+Longsen&card.number=4111111111111111&billingAddress.city=Ottawa&billingAddress.street=My+Street+Apt&billingAddress.houseNumberOrName=456+1&billingAddress.postalCode=K1C2N6&billingAddress.stateOrProvince=ON&billingAddress.country=CA&action=authorise"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Thu, 28 Jan 2016 21:32:16 GMT\r\n"
    -> "Server: Apache\r\n"
    -> "Set-Cookie: JSESSIONID=69398C80F6B1CBB04AA98B1D1895898B.test4e; Path=/pal/; Secure; HttpOnly\r\n"
    -> "pspReference: 8614540167365201\r\n"
    -> "Content-Length: 66\r\n"
    -> "Connection: close\r\n"
    -> "Content-Type: application/x-www-form-urlencoded;charset=utf-8\r\n"
    -> "\r\n"
    reading 66 bytes...
    -> ""
    -> "pspReference=8614540167365201&resultCode=Authorised&authCode=33683"
    read 66 bytes
    Conn close
    opening connection to pal-test.barclaycardsmartpay.com:443...
    opened
    starting SSL for pal-test.barclaycardsmartpay.com:443...
    SSL established
    <- "POST /pal/servlet/Payment/v12/capture HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded; charset=utf-8\r\nAuthorization: Basic d3NAQ29tcGFueS5QbHVzNTAwQ1k6UVpiWWd3Z2pDejNiZEdiNEhqYXk=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.barclaycardsmartpay.com\r\nContent-Length: 140\r\n\r\n"
    <- "merchantAccount=Plus500CYEcom&originalReference=8614540167365201&modificationAmount.currency=EUR&modificationAmount.value=100&action=capture"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Thu, 28 Jan 2016 21:32:18 GMT\r\n"
    -> "Server: Apache\r\n"
    -> "Set-Cookie: JSESSIONID=951837A566ED97C5869AA7C9DF91B608.test104e; Path=/pal/; Secure; HttpOnly\r\n"
    -> "pspReference: 7914540167387121\r\n"
    -> "Content-Length: 61\r\n"
    -> "Connection: close\r\n"
    -> "Content-Type: application/x-www-form-urlencoded;charset=utf-8\r\n"
    -> "\r\n"
    reading 61 bytes...
    -> ""
    -> "pspReference=7914540167387121&response=%5Bcapture-received%5D"
    read 61 bytes
    Conn close
    )
  end

  def scrubbed_transcript
    %(
    opening connection to pal-test.barclaycardsmartpay.com:443...
    opened
    starting SSL for pal-test.barclaycardsmartpay.com:443...
    SSL established
    <- "POST /pal/servlet/Payment/v12/authorise HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded; charset=utf-8\r\nAuthorization: Basic [FILTERED]Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.barclaycardsmartpay.com\r\nContent-Length: 466\r\n\r\n"
    <- "merchantAccount=Plus500CYEcom&reference=1&shopperEmail=long%40bob.com&shopperReference=Longbob+Longsen&amount.currency=EUR&amount.value=100&card.cvc=[FILTERED]&card.expiryMonth=06&card.expiryYear=2016&card.holderName=Longbob+Longsen&card.number=[FILTERED]&billingAddress.city=Ottawa&billingAddress.street=My+Street+Apt&billingAddress.houseNumberOrName=456+1&billingAddress.postalCode=K1C2N6&billingAddress.stateOrProvince=ON&billingAddress.country=CA&action=authorise"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Thu, 28 Jan 2016 21:32:16 GMT\r\n"
    -> "Server: Apache\r\n"
    -> "Set-Cookie: JSESSIONID=69398C80F6B1CBB04AA98B1D1895898B.test4e; Path=/pal/; Secure; HttpOnly\r\n"
    -> "pspReference: 8614540167365201\r\n"
    -> "Content-Length: 66\r\n"
    -> "Connection: close\r\n"
    -> "Content-Type: application/x-www-form-urlencoded;charset=utf-8\r\n"
    -> "\r\n"
    reading 66 bytes...
    -> ""
    -> "pspReference=8614540167365201&resultCode=Authorised&authCode=33683"
    read 66 bytes
    Conn close
    opening connection to pal-test.barclaycardsmartpay.com:443...
    opened
    starting SSL for pal-test.barclaycardsmartpay.com:443...
    SSL established
    <- "POST /pal/servlet/Payment/v12/capture HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded; charset=utf-8\r\nAuthorization: Basic [FILTERED]Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.barclaycardsmartpay.com\r\nContent-Length: 140\r\n\r\n"
    <- "merchantAccount=Plus500CYEcom&originalReference=8614540167365201&modificationAmount.currency=EUR&modificationAmount.value=100&action=capture"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Thu, 28 Jan 2016 21:32:18 GMT\r\n"
    -> "Server: Apache\r\n"
    -> "Set-Cookie: JSESSIONID=951837A566ED97C5869AA7C9DF91B608.test104e; Path=/pal/; Secure; HttpOnly\r\n"
    -> "pspReference: 7914540167387121\r\n"
    -> "Content-Length: 61\r\n"
    -> "Connection: close\r\n"
    -> "Content-Type: application/x-www-form-urlencoded;charset=utf-8\r\n"
    -> "\r\n"
    reading 61 bytes...
    -> ""
    -> "pspReference=7914540167387121&response=%5Bcapture-received%5D"
    read 61 bytes
    Conn close
    )
  end

end
