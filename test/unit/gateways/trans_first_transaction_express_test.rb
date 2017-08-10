require "test_helper"

class TransFirstTransactionExpressTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = TransFirstTransactionExpressGateway.new(
      gateway_id: "gateway_id",
      reg_key: "reg_key"
    )

    @credit_card = credit_card
    @check = check
    @amount = 100
    @declined_amount = 21
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal "purchase|000015212561", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@declined_amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal "Not sufficient funds", response.message
    assert_equal "51", response.error_code
    assert response.test?
  end

  def test_successful_purchase_with_echeck
    @gateway.stubs(:ssl_post).returns(successful_purchase_echeck_response)
    response = @gateway.purchase(@amount, @check)

    assert_success response
    assert_equal "purchase_echeck|000028705491", response.authorization
  end

  def test_failed_purchase_with_echeck
    @gateway.stubs(:ssl_post).returns(failed_purchase_echeck_response)
    response = @gateway.purchase(@amount, @check)

    assert_failure response
    assert_equal "Error. Bank routing number validation negative (ABA).", response.message
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "authorize|000015377801", response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/000015377801/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal "Not sufficient funds", response.message
    assert_equal "51", response.error_code
    assert response.test?
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(100, "")
    end.respond_with(failed_capture_response)

    assert_failure response
  end

  def test_successful_void
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "purchase|000015212561", response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/000015212561/, data)
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void("purchase|5d53a33d960c46d00f5dc061947d998c")
    end.check_request do |endpoint, data, headers|
      assert_match(/5d53a33d960c46d00f5dc061947d998c/, data)
    end.respond_with(failed_void_response)

    assert_failure response
    assert_equal "50011", response.error_code
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "purchase|000015212561", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/000015212561/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, "")
    end.respond_with(failed_refund_response)

    assert_failure response
    assert_equal "50011", response.error_code
  end

  def test_successful_refund_with_echeck
    response = stub_comms do
      @gateway.purchase(@amount, @check)
    end.respond_with(successful_purchase_echeck_response)

    assert_success response
    assert_equal "purchase_echeck|000028705491", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/000028705491/, data)
    end.respond_with(successful_refund_echeck_response)

    assert_success refund
  end

  def test_failed_refund_with_echeck
    response = stub_comms do
      @gateway.refund(@amount, 'purchase_echeck|000028706091')
    end.respond_with(failed_refund_response)

    assert_failure response
    assert_equal "50011", response.error_code
  end

  def test_successful_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(successful_credit_response)

    assert_success response

    assert_equal "credit|000001677461", response.authorization
    assert response.test?
  end

  def test_failed_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(failed_credit_response)

    assert_failure response
    assert_equal "Validation Error", response.message
    assert_equal "51334", response.error_code
    assert response.test?
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal "Not sufficient funds", response.message
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(successful_store_response)

    assert_success response

    assert_equal "Succeeded", response.message
    assert_equal "store|1453495229881170023", response.authorization
    assert response.test?
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(failed_store_response)

    assert_failure response
    assert_equal "Validation Failure", response.message
    assert response.test?
  end

  def test_empty_response_fails
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(empty_purchase_response)

    assert_failure response
    assert_equal nil, response.message
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_purchase_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"><S:Body><ns2:SendTranResponse xmlns="http://postilion/realtime/portal/soa/xsd/Faults/2009/01" xmlns:ns2="http://postilion/realtime/merchantframework/xsd/v1/"><ns2:rspCode>00</ns2:rspCode><ns2:authRsp><ns2:aci>Y</ns2:aci></ns2:authRsp><ns2:tranData><ns2:swchKey>0A1009331525B2A2DBFAF771E2E62B</ns2:swchKey><ns2:tranNr>000015212561</ns2:tranNr><ns2:dtTm>2016-01-19T10:33:57.000-08:00</ns2:dtTm><ns2:amt>000000000100</ns2:amt><ns2:stan>305156</ns2:stan><ns2:auth>Lexc05</ns2:auth></ns2:tranData><ns2:cardType>0</ns2:cardType><ns2:mapCaid>300979940268000</ns2:mapCaid></ns2:SendTranResponse></S:Body></S:Envelope>)
  end

  def failed_purchase_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"><S:Body><ns2:SendTranResponse xmlns="http://postilion/realtime/portal/soa/xsd/Faults/2009/01" xmlns:ns2="http://postilion/realtime/merchantframework/xsd/v1/"><ns2:rspCode>51</ns2:rspCode><ns2:authRsp><ns2:aci>Y</ns2:aci></ns2:authRsp><ns2:tranData><ns2:swchKey>0A1009331525BA8F333FC15F59AB32</ns2:swchKey><ns2:tranNr>000015220671</ns2:tranNr><ns2:dtTm>2016-01-19T12:52:25.000-08:00</ns2:dtTm><ns2:amt>000000000021</ns2:amt><ns2:stan>305918</ns2:stan><ns2:auth>Lexc05</ns2:auth></ns2:tranData><ns2:cardType>0</ns2:cardType><ns2:mapCaid>300979940268000</ns2:mapCaid></ns2:SendTranResponse></S:Body></S:Envelope>)
  end

  def successful_authorize_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S=\"http://schemas.xmlsoap.org/soap/envelope/\"><S:Body><ns2:SendTranResponse xmlns=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns:ns2=\"http://postilion/realtime/merchantframework/xsd/v1/\"><ns2:rspCode>00</ns2:rspCode><ns2:authRsp><ns2:secRslt>M</ns2:secRslt><ns2:avsRslt>Z</ns2:avsRslt><ns2:aci>Y</ns2:aci></ns2:authRsp><ns2:tranData><ns2:swchKey>0A10093315265DE34CE542A9E44548</ns2:swchKey><ns2:tranNr>000015377801</ns2:tranNr><ns2:dtTm>2016-01-21T12:26:47.000-08:00</ns2:dtTm><ns2:amt>000000000100</ns2:amt><ns2:stan>319955</ns2:stan><ns2:auth>Lexc05</ns2:auth></ns2:tranData><ns2:cardType>0</ns2:cardType><ns2:mapCaid>300979940268000</ns2:mapCaid></ns2:SendTranResponse></S:Body></S:Envelope>)
  end

  def failed_authorize_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S=\"http://schemas.xmlsoap.org/soap/envelope/\"><S:Body><ns2:SendTranResponse xmlns=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns:ns2=\"http://postilion/realtime/merchantframework/xsd/v1/\"><ns2:rspCode>51</ns2:rspCode><ns2:authRsp><ns2:secRslt>M</ns2:secRslt><ns2:avsRslt>Z</ns2:avsRslt><ns2:aci>Y</ns2:aci></ns2:authRsp><ns2:tranData><ns2:swchKey>0A10093315265F2FCEF82DB9231D67</ns2:swchKey><ns2:tranNr>000015378101</ns2:tranNr><ns2:dtTm>2016-01-21T12:49:29.000-08:00</ns2:dtTm><ns2:amt>000000000000</ns2:amt><ns2:stan>319985</ns2:stan><ns2:auth>Lexc05</ns2:auth></ns2:tranData><ns2:cardType>0</ns2:cardType><ns2:mapCaid>300979940268000</ns2:mapCaid></ns2:SendTranResponse></S:Body></S:Envelope>)
  end

  def successful_capture_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S=\"http://schemas.xmlsoap.org/soap/envelope/\"><S:Body><ns2:SendTranResponse xmlns=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns:ns2=\"http://postilion/realtime/merchantframework/xsd/v1/\"><ns2:rspCode>00</ns2:rspCode><ns2:authRsp/><ns2:tranData><ns2:swchKey>0A10093315265DF34907B4587F31D5</ns2:swchKey><ns2:tranNr>000015377821</ns2:tranNr><ns2:dtTm>2016-01-21T12:27:52.000-08:00</ns2:dtTm><ns2:amt>000000000100</ns2:amt><ns2:stan>319958</ns2:stan><ns2:auth>Lexc05</ns2:auth></ns2:tranData><ns2:cardType>0</ns2:cardType><ns2:mapCaid>300979940268000</ns2:mapCaid></ns2:SendTranResponse></S:Body></S:Envelope>)
  end

  def failed_capture_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S=\"http://schemas.xmlsoap.org/soap/envelope/\"><S:Body><S:Fault xmlns:ns4=\"http://www.w3.org/2003/05/soap-envelope\"><faultcode>S:Server</faultcode><faultstring>Validation Failure</faultstring><detail><SystemFault:SystemFault xmlns:SystemFault=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns:ns2=\"http://postilion/realtime/merchantframework/xsd/v1/\"><name>Validation Fault</name><message>cvc-type.3.1.3: The value '' of element 'v1:tranNr' is not valid.</message><errorCode>50011</errorCode></SystemFault:SystemFault></detail></S:Fault></S:Body></S:Envelope>)
  end

  def successful_void_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"><S:Body><ns2:SendTranResponse xmlns="http://postilion/realtime/portal/soa/xsd/Faults/2009/01" xmlns:ns2="http://postilion/realtime/merchantframework/xsd/v1/"><ns2:rspCode>00</ns2:rspCode><ns2:authRsp/><ns2:tranData><ns2:swchKey>0A1009331525BAC88E077EFB8D7542</ns2:swchKey><ns2:tranNr>000015212561</ns2:tranNr><ns2:dtTm>2016-01-19T12:56:20.000-08:00</ns2:dtTm><ns2:amt>000000000100</ns2:amt><ns2:stan>305938</ns2:stan><ns2:auth>Lexc05</ns2:auth></ns2:tranData><ns2:cardType>0</ns2:cardType><ns2:mapCaid>300979940268000</ns2:mapCaid><ns2:additionalAmount><ns2:accountType>30</ns2:accountType><ns2:amountType>53</ns2:amountType><ns2:currencyCode>840</ns2:currencyCode><ns2:amountSign>D</ns2:amountSign><ns2:amount>000000000100</ns2:amount></ns2:additionalAmount></ns2:SendTranResponse></S:Body></S:Envelope>)
  end

  def failed_void_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S=\"http://schemas.xmlsoap.org/soap/envelope/\"><S:Body><S:Fault xmlns:ns4=\"http://www.w3.org/2003/05/soap-envelope\"><faultcode>S:Server</faultcode><faultstring>Validation Failure</faultstring><detail><SystemFault:SystemFault xmlns:SystemFault=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns:ns2=\"http://postilion/realtime/merchantframework/xsd/v1/\"><name>Validation Fault</name><message>cvc-type.3.1.3: The value '' of element 'v1:tranNr' is not valid.</message><errorCode>50011</errorCode></SystemFault:SystemFault></detail></S:Fault></S:Body></S:Envelope>)
  end

  def successful_refund_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"><S:Body><SendTranResponse xmlns="http://postilion/realtime/merchantframework/xsd/v1/" xmlns:ns2="http://postilion/realtime/portal/soa/xsd/Faults/2009/01"> <ns2:rspCode>00</ns2:rspCode><ns2:tranData><ns2:swchKey>0A10064112F57B9D997D4D1111888E</ns2:swchKey><ns2:tranNr>000001829611</ns2:tranNr><ns2:dtTm>2011-04-14T22:54:48.000-07:00</ns2:dtTm><ns2:amt>000000000100</ns2:amt></ns2:tranData></SendTranResponse></S:Body></S:Envelope>)
  end

  def failed_refund_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S=\"http://schemas.xmlsoap.org/soap/envelope/\"><S:Body><S:Fault xmlns:ns4=\"http://www.w3.org/2003/05/soap-envelope\"><faultcode>S:Server</faultcode><faultstring>Validation Failure</faultstring><detail><SystemFault:SystemFault xmlns:SystemFault=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns:ns2=\"http://postilion/realtime/merchantframework/xsd/v1/\"><name>Validation Fault</name><message>cvc-type.3.1.3: The value '' of element 'v1:tranNr' is not valid.</message><errorCode>50011</errorCode></SystemFault:SystemFault></detail></S:Fault></S:Body></S:Envelope>)
  end

  def successful_credit_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"><S:Body><ns2:SendTranResponse xmlns="http://postilion/realtime/portal/soa/xsd/Faults/2009/01" xmlns:ns2="http://postilion/realtime/merchantframework/xsd/v1/"><ns2:rspCode>00</ns2:rspCode><ns2:authRsp/><ns2:tranData><ns2:swchKey>0A6E6B4B135B08437C7C1370A116B7</ns2:swchKey><ns2:tranNr>000001677461</ns2:tranNr><ns2:dtTm>2012-02-24T09:59:09.000-08:00</ns2:dtTm><ns2:amt>000000000100</ns2:amt><ns2:stan>000301</ns2:stan></ns2:tranData><ns2:cardType>0</ns2:cardType><ns2:mapCaid>7310</ns2:mapCaid></ns2:SendTranResponse></S:Body></S:Envelope>)
  end

  def failed_credit_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S=\"http://schemas.xmlsoap.org/soap/envelope/\"><S:Body><S:Fault xmlns:ns4=\"http://www.w3.org/2003/05/soap-envelope\"><faultcode>S:Server</faultcode><faultstring>Validation Error</faultstring><detail><SystemFault:SystemFault xmlns:SystemFault=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns:ns2=\"http://postilion/realtime/merchantframework/xsd/v1/\"><name>Validation Error</name><message>Validation Error Fault</message><errorCode>51334</errorCode></SystemFault:SystemFault></detail></S:Fault></S:Body></S:Envelope>)
  end

  def successful_store_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S=\"http://schemas.xmlsoap.org/soap/envelope/\"><S:Body><ns2:UpdtRecurrProfResponse xmlns=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns:ns2=\"http://postilion/realtime/merchantframework/xsd/v1/\"><ns2:pmtId>1453495229881170023</ns2:pmtId><ns2:rspCode>00</ns2:rspCode></ns2:UpdtRecurrProfResponse></S:Body></S:Envelope>)
  end

  def failed_store_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S=\"http://schemas.xmlsoap.org/soap/envelope/\"><S:Body><S:Fault xmlns:ns4=\"http://www.w3.org/2003/05/soap-envelope\"><faultcode>S:Server</faultcode><faultstring>Validation Failure</faultstring><detail><SystemFault:SystemFault xmlns:SystemFault=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns=\"http://postilion/realtime/portal/soa/xsd/Faults/2009/01\" xmlns:ns2=\"http://postilion/realtime/merchantframework/xsd/v1/\"><name>Validation Fault</name><message>cvc-type.3.1.3: The value '123' of element 'v1:pan' is not valid.</message><errorCode>50011</errorCode></SystemFault:SystemFault></detail></S:Fault></S:Body></S:Envelope>)
  end

  def successful_purchase_echeck_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"><S:Body><ns2:SendTranResponse xmlns="http://postilion/realtime/portal/soa/xsd/Faults/2009/01" xmlns:ns2="http://postilion/realtime/merchantframework/xsd/v1/"><ns2:rspCode>00</ns2:rspCode><ns2:authRsp><ns2:gwyTranId>43550871</ns2:gwyTranId></ns2:authRsp><ns2:tranData><ns2:swchKey>0A09071615AD2403F804EFDA26EA76</ns2:swchKey><ns2:tranNr>000028705491</ns2:tranNr><ns2:dtTm>2017-03-15T06:55:10-07:00</ns2:dtTm><ns2:amt>000000000100</ns2:amt><ns2:stan>386950</ns2:stan></ns2:tranData><ns2:achResponse><ns2:Message>Transaction processed.</ns2:Message><ns2:Note>PrevPay: nil +0</ns2:Note><ns2:Note>Score: 100/100</ns2:Note></ns2:achResponse></ns2:SendTranResponse></S:Body></S:Envelope>)
  end

  def failed_purchase_echeck_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"><S:Body><ns2:SendTranResponse xmlns="http://postilion/realtime/portal/soa/xsd/Faults/2009/01" xmlns:ns2="http://postilion/realtime/merchantframework/xsd/v1/"><ns2:rspCode>06</ns2:rspCode><ns2:authRsp/><ns2:tranData><ns2:swchKey>0A09071715AD2654A6814EE9ADC0EF</ns2:swchKey><ns2:tranNr>000028705711</ns2:tranNr><ns2:dtTm>2017-03-15T07:35:38-07:00</ns2:dtTm><ns2:amt>000000000100</ns2:amt><ns2:stan>386972</ns2:stan></ns2:tranData><ns2:achResponse><ns2:Message>Bank routing number validation negative (ABA).</ns2:Message></ns2:achResponse></ns2:SendTranResponse></S:Body></S:Envelope>)
  end

  def successful_refund_echeck_response
    %( <?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"><S:Body><ns2:SendTranResponse xmlns="http://postilion/realtime/portal/soa/xsd/Faults/2009/01" xmlns:ns2="http://postilion/realtime/merchantframework/xsd/v1/"><ns2:rspCode>00</ns2:rspCode><ns2:authRsp><ns2:gwyTranId>43550889</ns2:gwyTranId></ns2:authRsp><ns2:tranData><ns2:swchKey>0A09071715AD2786821E2F357D7E52</ns2:swchKey><ns2:tranNr>000028706091</ns2:tranNr><ns2:dtTm>2017-03-15T07:56:31-07:00</ns2:dtTm><ns2:amt>000000000100</ns2:amt><ns2:stan>387010</ns2:stan></ns2:tranData><ns2:achResponse><ns2:Message>Transaction Cancelled.</ns2:Message><ns2:Note>PrevPay: nil +0</ns2:Note><ns2:Note>Score: 100/100</ns2:Note><ns2:Note>Cancellation Notes: RefNumber:28706091</ns2:Note></ns2:achResponse></ns2:SendTranResponse></S:Body></S:Envelope>)
  end

  def failed_refund_echeck_response
    %(<?xml version='1.0' encoding='UTF-8'?><S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"><S:Body><ns2:SendTranResponse xmlns="http://postilion/realtime/portal/soa/xsd/Faults/2009/01" xmlns:ns2="http://postilion/realtime/merchantframework/xsd/v1/"><ns2:rspCode>12</ns2:rspCode><ns2:extRspCode>B40F</ns2:extRspCode><ns2:authRsp><ns2:gwyTranId>43550889</ns2:gwyTranId></ns2:authRsp><ns2:tranData><ns2:swchKey>0A09071615AD285C3E4E0AE3A42CF3</ns2:swchKey><ns2:tranNr>000028706091</ns2:tranNr><ns2:dtTm>2017-03-15T08:11:06-07:00</ns2:dtTm><ns2:amt>000000000100</ns2:amt></ns2:tranData></ns2:SendTranResponse></S:Body></S:Envelope>)
  end

  def empty_purchase_response
    %()
  end

  def transcript
    <<-PRE_SCRUBBED
opening connection to ws.cert.transactionexpress.com:443...
opened
starting SSL for ws.cert.transactionexpress.com:443...
SSL established
<- "POST /portal/merchantframework/MerchantWebServices-v1?wsdl HTTP/1.1\r\nContent-Type: text/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ws.cert.transactionexpress.com\r\nContent-Length: 1186\r\n\r\n"
<- "<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"><soapenv:Body><v1:SendTranRequest xmlns:v1=\"http://postilion/realtime/merchantframework/xsd/v1/\"><v1:merc><v1:id>7777778764</v1:id><v1:regKey>M84PKPDMD5BY86HN</v1:regKey><v1:inType>1</v1:inType></v1:merc><v1:tranCode>1</v1:tranCode><v1:card><v1:pan>4485896261017708</v1:pan><v1:xprDt>1709</v1:xprDt></v1:card><v1:contact><v1:fullName>Longbob Longsen</v1:fullName><v1:coName>Acme</v1:coName><v1:title>QA Manager</v1:title><v1:phone><v1:type>4</v1:type><v1:nr>3334445555</v1:nr></v1:phone><v1:addrLn1>450 Main</v1:addrLn1><v1:addrLn2>Suite 100</v1:addrLn2><v1:city>Broomfield</v1:city><v1:state>CO</v1:state><v1:zipCode>85284</v1:zipCode><v1:ctry>US</v1:ctry><v1:email>example@example.com</v1:email><v1:ship><v1:fullName>Longbob Longsen</v1:fullName><v1:addrLn1>450 Main</v1:addrLn1><v1:addrLn2>Suite 100</v1:addrLn2><v1:city>Broomfield</v1:city><v1:state>CO</v1:state><v1:zipCode>85284</v1:zipCode><v1:phone>3334445555</v1:phone></v1:ship></v1:contact><v1:reqAmt>100</v1:reqAmt><v1:authReq><v1:ordNr>7a0f975b6e86aff44364360cbc6d0f00</v1:ordNr></v1:authReq></v1:SendTranRequest></soapenv:Body></soapenv:Envelope>"
-> "HTTP/1.1 200 OK\r\n"
-> "Content-Type: text/xml;charset=utf-8\r\n"
-> "Date: Thu, 21 Jan 2016 20:09:44 GMT\r\n"
-> "Server: WebServer\r\n"
-> "Set-Cookie: NSC_UMT12_DFSU-xt.dfsu.UYQ.dpn=ffffffff0918172545525d5f4f58455e445a4a42378b;expires=Thu, 21-Jan-2016 20:17:43 GMT;path=/;secure;httponly\r\n"
-> "Cache-Control: private\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "\r\n"
-> "1AA \r\n"
reading 426 bytes...
-> ""
read 426 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
    PRE_SCRUBBED
  end

  def scrubbed_transcript
    <<-POST_SCRUBBED
opening connection to ws.cert.transactionexpress.com:443...
opened
starting SSL for ws.cert.transactionexpress.com:443...
SSL established
<- "POST /portal/merchantframework/MerchantWebServices-v1?wsdl HTTP/1.1\r\nContent-Type: text/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ws.cert.transactionexpress.com\r\nContent-Length: 1186\r\n\r\n"
<- "<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"><soapenv:Body><v1:SendTranRequest xmlns:v1=\"http://postilion/realtime/merchantframework/xsd/v1/\"><v1:merc><v1:id>[FILTERED]</v1:id><v1:regKey>[FILTERED]</v1:regKey><v1:inType>1</v1:inType></v1:merc><v1:tranCode>1</v1:tranCode><v1:card><v1:pan>[FILTERED]</v1:pan><v1:xprDt>1709</v1:xprDt></v1:card><v1:contact><v1:fullName>Longbob Longsen</v1:fullName><v1:coName>Acme</v1:coName><v1:title>QA Manager</v1:title><v1:phone><v1:type>4</v1:type><v1:nr>3334445555</v1:nr></v1:phone><v1:addrLn1>450 Main</v1:addrLn1><v1:addrLn2>Suite 100</v1:addrLn2><v1:city>Broomfield</v1:city><v1:state>CO</v1:state><v1:zipCode>85284</v1:zipCode><v1:ctry>US</v1:ctry><v1:email>example@example.com</v1:email><v1:ship><v1:fullName>Longbob Longsen</v1:fullName><v1:addrLn1>450 Main</v1:addrLn1><v1:addrLn2>Suite 100</v1:addrLn2><v1:city>Broomfield</v1:city><v1:state>CO</v1:state><v1:zipCode>85284</v1:zipCode><v1:phone>3334445555</v1:phone></v1:ship></v1:contact><v1:reqAmt>100</v1:reqAmt><v1:authReq><v1:ordNr>7a0f975b6e86aff44364360cbc6d0f00</v1:ordNr></v1:authReq></v1:SendTranRequest></soapenv:Body></soapenv:Envelope>"
-> "HTTP/1.1 200 OK\r\n"
-> "Content-Type: text/xml;charset=utf-8\r\n"
-> "Date: Thu, 21 Jan 2016 20:09:44 GMT\r\n"
-> "Server: WebServer\r\n"
-> "Set-Cookie: NSC_UMT12_DFSU-xt.dfsu.UYQ.dpn=ffffffff0918172545525d5f4f58455e445a4a42378b;expires=Thu, 21-Jan-2016 20:17:43 GMT;path=/;secure;httponly\r\n"
-> "Cache-Control: private\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "\r\n"
-> "1AA \r\n"
reading 426 bytes...
-> ""
read 426 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
    POST_SCRUBBED
  end
end
