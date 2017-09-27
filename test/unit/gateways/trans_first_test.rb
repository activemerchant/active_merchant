require 'test_helper'

class TransFirstTest < Test::Unit::TestCase

  def setup
    @gateway = TransFirstGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @credit_card = credit_card('4242424242424242')
    @check = check
    @options = {
      :billing_address => address
    }
    @amount = 100
  end

  def test_missing_field_response
    @gateway.stubs(:ssl_post).returns(missing_field_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert response.test?
    assert_equal 'Missing parameter: UserId.', response.message
  end

  def test_successful_purchase
    @gateway.stubs(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'test transaction', response.message
    assert_equal '355|creditcard', response.authorization
  end

  def test_failed_purchase
    @gateway.stubs(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert response.test?
    assert_equal '29005716|creditcard', response.authorization
    assert_equal 'Invalid cardholder number', response.message
  end

  def test_successful_purchase_with_echeck
    @gateway.stubs(:ssl_post).returns(successful_purchase_echeck_response)
    response = @gateway.purchase(@amount, @check, @options)

    assert_success response
  end

  def test_failed_purchase_with_echeck
    @gateway.stubs(:ssl_post).returns(failed_purchase_echeck_response)
    response = @gateway.purchase(@amount, @check, @options)

    assert_failure response
  end

  def test_successful_refund
    @gateway.stubs(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, "TransID")
    assert_success response
    assert_equal '207686608|creditcard', response.authorization
    assert_equal @amount, response.params["amount"].to_i*100
  end

  def test_failed_refund
    @gateway.stubs(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, "TransID")
    assert_failure response
  end
 
  def test_successful_void
    @gateway.stubs(:ssl_post).returns(successful_void_response)

    response = @gateway.void("TransID")
    assert_success response
  end

  def test_failed_void
    @gateway.stubs(:ssl_post).returns(failed_void_response)

    response = @gateway.void("TransID")
    assert_failure response
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'X', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_scrub_echeck
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed_echeck), post_scrubbed_echeck
  end

  private

  def missing_field_response
    "Missing parameter: UserId.\r\n"
  end

  def pre_scrubbed
    %q(
      opening connection to ws.cert.transfirst.com:443...
      opened
      starting SSL for ws.cert.transfirst.com:443...
      SSL established
      <- "POST /creditcard.asmx/CCSale HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ws.cert.transfirst.com\r\nContent-Length: 507\r\n\r\n"
      <- "Amount=12.01&RefID=80d6ca993942c62f90079990e3b6ae8f&SECCCode=ActiveMerchant+Sale&PONumber=ActiveMerchant+Sale&SaleTaxAmount=0.00&PaymentDesc=&TaxIndicator=0&CompanyName=&CardHolderName=Longbob+Longsen&CardNumber=4485896261017708&Expiration=0916&CVV2=999&Address=456+My+Street&ZipCode=K1C2N6&ECIValue=&UserId=&CAVVData=&TrackData=&POSInd=&EComInd=&MerchZIP=&MerchCustPNum=&MCC=&InstallmentNum=&InstallmentOf=&POSEntryMode=&POSConditionCode=&AuthCharInd=&CardCertData=&MerchantID=45567&RegKey=TNYYKYMFZ59HSN7Q"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: private, max-age=0\r\n"
      -> "Content-Type: text/xml; charset=utf-8\r\n"
      -> "Server: Microsoft-IIS/7.5\r\n"
      -> "X-AspNet-Version: 2.0.50727\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "Date: Wed, 16 Dec 2015 18:46:28 GMT\r\n"
      -> "Cteonnt-Length: 679\r\n"
      -> "Set-Cookie: NSC_JOb34jhgcucdnowdxp3wxrei43g5edn=ffffffff0918171e45525d5f4f58455e445a4a42378b;expires=Wed, 16-Dec-2015 18:55:08 GMT;path=/;secure;httponly\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Content-Length:        383\r\n"
      -> "\r\n"
      reading 383 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03\x8D\x92\xD1k\x830\x10\xC6\xDF\a\xFB\x1F\xC4wMb[\xABb-\xC5\xBE\x14V\x18u\xC8^\xD3x\xB6\x01M\x8A\x89\xB5\xFB\xEF\x97j-\x0E\x06\xDB\xDB\xE5\xBB\xEFw\x17\xEE.^\xDF\xEA\xCA\xBAB\xA3\xB8\x14+\x9B\xB8\xD8\xB6@0YpqZ\xD9\xAD.\x9D\xC0^'\xAF/q\x9Af\xB4\x82-\x1C\xB9>\x80\xBAH\xA1\xC02\xA8P\xD1M\xF1\x95}\xD6\xFA\x12!\xD4u\x9D\xDB\xCD\\\xD9\x9C\x90\x871A\x9F\xFB\xB7\x8C\x9D\xA1\xA6\x0E\x17JS\xC1\xC0~R\xC5\xDF\xD4\xC3\xFC\xC3x\xA1_5\b\xDD\x80\x92m\xC3@\xB9L\xD6\xA8\x83\xA3\x82\xE6\xCA\xCD\e\xD9\xE6\xBB\x96\x15\x7F4T\xA8\xDD6\xC11\x1A\xC3^?@i\xC2\x00\x17>\xA3a8\v\xE7\x1E\xF3\xBD2\xC4x\x19\x86!\x86\xD9\xD1\xA7\x10\x941\x1A|=\xF2.\x95\x86bK5$\x1E&\v\x87x\x0E\xF1?\b\x8E\xE6~\xE4\x05.Y\x06$X,\x1C\x1CD\xD8t\x9B\xB8{:\x03\xAD\xAB\xFF\xE3S{\xCFoj\xD9\n\x9D\x10\xCF\xC5$F\x8F\xD7\x90i\xF59\x95\x05X\xE8\xD1IS\xDD\xAA$\xBD\xCF\xD9\x940\xB5\x06a0\xE7\xD9\xD4\xBB\a\xA5\xE8\t\x92\xA2\xBDT\x9C\x99f\x962\xFB\x8D\xD1\xA8\xF7\xA64\xCF\xBD\xB4Iw\xCF\xD0\xF4\xCE\xFA\r\x8CJ?e\xCA\xB49\xA4]a6\xC4K\x0E\xCD\x98\xCCi\xC5\vz\xCFM\xEB\xA5\x9B<7\xD7\xD4V\xFA\xA9\xC6\xE8\x97KK\xBE\x01\xFA\xDC>T\xA7\x02\x00\x00"
      read 383 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to ws.cert.transfirst.com:443...
      opened
      starting SSL for ws.cert.transfirst.com:443...
      SSL established
      <- "POST /creditcard.asmx/CCSale HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ws.cert.transfirst.com\r\nContent-Length: 507\r\n\r\n"
      <- "Amount=12.01&RefID=80d6ca993942c62f90079990e3b6ae8f&SECCCode=ActiveMerchant+Sale&PONumber=ActiveMerchant+Sale&SaleTaxAmount=0.00&PaymentDesc=&TaxIndicator=0&CompanyName=&CardHolderName=Longbob+Longsen&CardNumber=[FILTERED]&Expiration=0916&CVV2=[FILTERED]&Address=456+My+Street&ZipCode=K1C2N6&ECIValue=&UserId=&CAVVData=&TrackData=&POSInd=&EComInd=&MerchZIP=&MerchCustPNum=&MCC=&InstallmentNum=&InstallmentOf=&POSEntryMode=&POSConditionCode=&AuthCharInd=&CardCertData=&MerchantID=45567&RegKey=[FILTERED]"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: private, max-age=0\r\n"
      -> "Content-Type: text/xml; charset=utf-8\r\n"
      -> "Server: Microsoft-IIS/7.5\r\n"
      -> "X-AspNet-Version: 2.0.50727\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "Date: Wed, 16 Dec 2015 18:46:28 GMT\r\n"
      -> "Cteonnt-Length: 679\r\n"
      -> "Set-Cookie: NSC_JOb34jhgcucdnowdxp3wxrei43g5edn=ffffffff0918171e45525d5f4f58455e445a4a42378b;expires=Wed, 16-Dec-2015 18:55:08 GMT;path=/;secure;httponly\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Content-Length:        383\r\n"
      -> "\r\n"
      reading 383 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03\x8D\x92\xD1k\x830\x10\xC6\xDF\a\xFB\x1F\xC4wMb[\xABb-\xC5\xBE\x14V\x18u\xC8^\xD3x\xB6\x01M\x8A\x89\xB5\xFB\xEF\x97j-\x0E\x06\xDB\xDB\xE5\xBB\xEFw\x17\xEE.^\xDF\xEA\xCA\xBAB\xA3\xB8\x14+\x9B\xB8\xD8\xB6@0YpqZ\xD9\xAD.\x9D\xC0^'\xAF/q\x9Af\xB4\x82-\x1C\xB9>\x80\xBAH\xA1\xC02\xA8P\xD1M\xF1\x95}\xD6\xFA\x12!\xD4u\x9D\xDB\xCD\\\xD9\x9C\x90\x871A\x9F\xFB\xB7\x8C\x9D\xA1\xA6\x0E\x17JS\xC1\xC0~R\xC5\xDF\xD4\xC3\xFC\xC3x\xA1_5\b\xDD\x80\x92m\xC3@\xB9L\xD6\xA8\x83\xA3\x82\xE6\xCA\xCD\e\xD9\xE6\xBB\x96\x15\x7F4T\xA8\xDD6\xC11\x1A\xC3^?@i\xC2\x00\x17>\xA3a8\v\xE7\x1E\xF3\xBD2\xC4x\x19\x86!\x86\xD9\xD1\xA7\x10\x941\x1A|=\xF2.\x95\x86bK5$\x1E&\v\x87x\x0E\xF1?\b\x8E\xE6~\xE4\x05.Y\x06$X,\x1C\x1CD\xD8t\x9B\xB8{:\x03\xAD\xAB\xFF\xE3S{\xCFoj\xD9\n\x9D\x10\xCF\xC5$F\x8F\xD7\x90i\xF59\x95\x05X\xE8\xD1IS\xDD\xAA$\xBD\xCF\xD9\x940\xB5\x06a0\xE7\xD9\xD4\xBB\a\xA5\xE8\t\x92\xA2\xBDT\x9C\x99f\x962\xFB\x8D\xD1\xA8\xF7\xA64\xCF\xBD\xB4Iw\xCF\xD0\xF4\xCE\xFA\r\x8CJ?e\xCA\xB49\xA4]a6\xC4K\x0E\xCD\x98\xCCi\xC5\vz\xCFM\xEB\xA5\x9B<7\xD7\xD4V\xFA\xA9\xC6\xE8\x97KK\xBE\x01\xFA\xDC>T\xA7\x02\x00\x00"
      read 383 bytes
      Conn close
    )
  end

  def pre_scrubbed_echeck
    %q(
      opening connection to ws.cert.transfirst.com:443...
      opened
      starting SSL for ws.cert.transfirst.com:443...
      SSL established
      <- "POST /checkverifyws/checkverifyws.asmx/ACHDebit HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ws.cert.transfirst.com\r\nContent-Length: 558\r\n\r\n"
      <- "Amount=12.01&RefID=4b75519794a46dddcc50ed7349560d18&SECCCode=ActiveMerchant+Sale&PONumber=ActiveMerchant+Sale&SaleTaxAmount=0.00&PaymentDesc=&TaxIndicator=0&CompanyName=&TransRoute=244183602&BankAccountNo=15378535&BankAccountType=Checking&CheckType=Personal&Name=Jim+Smith&ProcessDate=121615&Description=&Address=456+My+Street&ZipCode=K1C2N6&ECIValue=&UserId=&CAVVData=&TrackData=&POSInd=&EComInd=&MerchZIP=&MerchCustPNum=&MCC=&InstallmentNum=&InstallmentOf=&POSEntryMode=&POSConditionCode=&AuthCharInd=&CardCertData=&MerchantID=45567&RegKey=TNYYKYMFZ59HSN7Q"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: private, max-age=0\r\n"
      -> "Content-Type: text/xml; charset=utf-8\r\n"
      -> "Server: Microsoft-IIS/7.5\r\n"
      -> "X-AspNet-Version: 2.0.50727\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "Date: Wed, 16 Dec 2015 18:55:56 GMT\r\n"
      -> "Cteonnt-Length: 504\r\n"
      -> "Set-Cookie: NSC_JOb34jhgcucdnowdxp3wxrei43g5edn=ffffffff0918171e45525d5f4f58455e445a4a42378b;expires=Wed, 16-Dec-2015 19:04:36 GMT;path=/;secure;httponly\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Content-Length:        341\r\n"
      -> "\r\n"
      reading 341 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03\x85\x91_o\x820\x14\xC5\xDF\x97\xEC;4\xBCC[\xE4\x9F\x04k\f\xBA\x8ClN\xA3\xC6\xEC\x15\xDB\xAB\x90\x8Dbh\x11\xF7\xED\xC7\x80\x19\xF7\xB4\xB7{\xCF9\xBF\xE6\xDE\xDEhz->\xD1\x05*\x95\x97rbP\x8B\x18\b$/E.O\x13\xA3\xD6G30\xA6\xEC\xF1!\x8A3\xE0\x1F[\x9D\xEAZ\xA1\x16\x91*\xBC\xAA|bdZ\x9FC\x8C\x9B\xA6\xB1\x9A\x91UV'l\x13B\xF1\xFB\xF2u\xCB3R3\x97J\xA7\x92\x83q\xA3\xC4\xFF\xD4\x10\xFE\x13<\xA7_\x05H]\x81*\xEB\x8A\x83\xC5\xCB\x027pPP]r\x0E\n\e\xED\x94\bE\xB3Zgq\x80\xC5\xCF\x8B\xF8\x05%[\xF4\xB6\xDA\xA1\xFDb\x93<%\x8By\x84o~\x97^\x82R\xE9\t\x10\xEE\xDBu\xA94\x88y\xAA\x81\xD9\x84\xBA&\xB5M\xEA\xED\t]7t=\xCB\xA7#\xC7\xA7\xBEI\x82\x90\x90\b\xDF\xA5;z\x03\xC7d\xCE\x9C\x83\xEF\xBAt\xEC\x8F\x9D\xD4\xF1\x84\x10\x9C\xBB\x04\x84?r\xC6\xAEG\x04\r\"\xDC\xE7:\xA4\xFFP6[\xAF7\xAB\xFD\xCFx\x83\xD0\x9B5o\x17S\x8C\xB6\xF2Pv\xFA\xAEJ\xA5j_\xB0\x03\xEA8\x9E\xEFE\xF8W\xE9\xECYQ\xD6R3j[\xA4%\x87\xAE\xBD \xBE;!\xFB\x06\xEF\x9A\xBA\x89\xF8\x01\x00\x00"
      read 341 bytes
      Conn close
    )
  end

  def post_scrubbed_echeck
    %q(
      opening connection to ws.cert.transfirst.com:443...
      opened
      starting SSL for ws.cert.transfirst.com:443...
      SSL established
      <- "POST /checkverifyws/checkverifyws.asmx/ACHDebit HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ws.cert.transfirst.com\r\nContent-Length: 558\r\n\r\n"
      <- "Amount=12.01&RefID=4b75519794a46dddcc50ed7349560d18&SECCCode=ActiveMerchant+Sale&PONumber=ActiveMerchant+Sale&SaleTaxAmount=0.00&PaymentDesc=&TaxIndicator=0&CompanyName=&TransRoute=[FILTERED]&BankAccountNo=[FILTERED]&BankAccountType=Checking&CheckType=Personal&Name=Jim+Smith&ProcessDate=121615&Description=&Address=456+My+Street&ZipCode=K1C2N6&ECIValue=&UserId=&CAVVData=&TrackData=&POSInd=&EComInd=&MerchZIP=&MerchCustPNum=&MCC=&InstallmentNum=&InstallmentOf=&POSEntryMode=&POSConditionCode=&AuthCharInd=&CardCertData=&MerchantID=45567&RegKey=[FILTERED]"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: private, max-age=0\r\n"
      -> "Content-Type: text/xml; charset=utf-8\r\n"
      -> "Server: Microsoft-IIS/7.5\r\n"
      -> "X-AspNet-Version: 2.0.50727\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "Date: Wed, 16 Dec 2015 18:55:56 GMT\r\n"
      -> "Cteonnt-Length: 504\r\n"
      -> "Set-Cookie: NSC_JOb34jhgcucdnowdxp3wxrei43g5edn=ffffffff0918171e45525d5f4f58455e445a4a42378b;expires=Wed, 16-Dec-2015 19:04:36 GMT;path=/;secure;httponly\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Content-Length:        341\r\n"
      -> "\r\n"
      reading 341 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03\x85\x91_o\x820\x14\xC5\xDF\x97\xEC;4\xBCC[\xE4\x9F\x04k\f\xBA\x8ClN\xA3\xC6\xEC\x15\xDB\xAB\x90\x8Dbh\x11\xF7\xED\xC7\x80\x19\xF7\xB4\xB7{\xCF9\xBF\xE6\xDE\xDEhz->\xD1\x05*\x95\x97rbP\x8B\x18\b$/E.O\x13\xA3\xD6G30\xA6\xEC\xF1!\x8A3\xE0\x1F[\x9D\xEAZ\xA1\x16\x91*\xBC\xAA|bdZ\x9FC\x8C\x9B\xA6\xB1\x9A\x91UV'l\x13B\xF1\xFB\xF2u\xCB3R3\x97J\xA7\x92\x83q\xA3\xC4\xFF\xD4\x10\xFE\x13<\xA7_\x05H]\x81*\xEB\x8A\x83\xC5\xCB\x027pPP]r\x0E\n\e\xED\x94\bE\xB3Zgq\x80\xC5\xCF\x8B\xF8\x05%[\xF4\xB6\xDA\xA1\xFDb\x93<%\x8By\x84o~\x97^\x82R\xE9\t\x10\xEE\xDBu\xA94\x88y\xAA\x81\xD9\x84\xBA&\xB5M\xEA\xED\t]7t=\xCB\xA7#\xC7\xA7\xBEI\x82\x90\x90\b\xDF\xA5;z\x03\xC7d\xCE\x9C\x83\xEF\xBAt\xEC\x8F\x9D\xD4\xF1\x84\x10\x9C\xBB\x04\x84?r\xC6\xAEG\x04\r\"\xDC\xE7:\xA4\xFFP6[\xAF7\xAB\xFD\xCFx\x83\xD0\x9B5o\x17S\x8C\xB6\xF2Pv\xFA\xAEJ\xA5j_\xB0\x03\xEA8\x9E\xEFE\xF8W\xE9\xECYQ\xD6R3j[\xA4%\x87\xAE\xBD \xBE;!\xFB\x06\xEF\x9A\xBA\x89\xF8\x01\x00\x00"
      read 341 bytes
      Conn close
    )
  end

  def successful_purchase_response
    <<-XML
    <?xml version="1.0" encoding="utf-8"?>
    <CCSaleDebitResponse xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.paymentresources.com/webservices/">
      <TransID>355</TransID>
      <RefID>c2535abbf0bb38005a14fd575553df65</RefID>
      <Amount>1.00</Amount>
      <AuthCode>Test00</AuthCode>
      <Status>Authorized</Status>
      <AVSCode>X</AVSCode>
      <Message>test transaction</Message>
      <CVV2Code>M</CVV2Code>
      <ACI />
      <AuthSource />
      <TransactionIdentifier />
      <ValidationCode />
      <CAVVResultCode />
    </CCSaleDebitResponse>
    XML
  end

  def failed_purchase_response
    <<-XML
    <?xml version="1.0" encoding="utf-8" ?>
    <CCSaleDebitResponse xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.paymentresources.com/webservices/">
      <TransID>29005716</TransID>
      <RefID>0610</RefID>
      <PostedDate>2005-09-29T15:16:23.7297658-07:00</PostedDate>
      <SettledDate>2005-09-29T15:16:23.9641468-07:00</SettledDate>
      <Amount>0.02</Amount>
      <AuthCode />
      <Status>Declined</Status>
      <AVSCode />
      <Message>Invalid cardholder number</Message>
      <CVV2Code />
      <ACI />
      <AuthSource />
      <TransactionIdentifier />
      <ValidationCode />
      <CAVVResultCode />
    </CCSaleDebitResponse>
    XML
  end

  def successful_purchase_echeck_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <CheckStatus>
      xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema- instance" xmlns="http://www.paymentresources.com/webservices/">
        <Success>1</Success>
        <TransID>11996</TransID>
        <RefID>PRICreditTest</RefID>
        <PostedDate>004-02-04T08:23:02.9467720-08:00</PostedDate>
        <AuthCode> CHECK IS NOT VERIFIED </AuthCode>
        <Status>APPROVED</Status>
        <Message />
        <Amount>1.01</Amount>
      </CheckStatus>
    XML
  end

  def failed_purchase_echeck_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <CheckStatus>
      xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema- instance" xmlns="http://www.paymentresources.com/webservices/">
        <Success>0</Success>
        <TransID>0</TransID>
        <RefID>PRICreditTest</RefID>
        <PostedDate>2004-02-04T08:23:02.9467720-08:00</PostedDate>
        <AuthCode> CHECK IS NOT VERIFIED </AuthCode>
        <Status>DENIED</Status>
        <Message> Error Message </Message>
        <Amount>1.01</Amount>
      </CheckStatus>
    XML
  end

  def successful_refund_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <BankCardRefundStatus xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.paymentresources.com/webservices/">
        <TransID>207686608</TransID>
        <CreditID>5681409</CreditID>
        <RefID />
        <PostedDate>2010-08-09T15:20:50.9740575-06:00</PostedDate> <SettledDate>0001-01-01T00:00:00</SettledDate>
        <Amount>1.0000</Amount>
        <Status>Authorized</Status>
      </BankCardRefundStatus>
    XML
  end

  def failed_refund_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <BankCardRefundStatus xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.paymentresources.com/webservices/">
        <TransID>0</TransID>
        <CreditID>0</CreditID>
        <PostedDate>0001-01-01T00:00:00</PostedDate> <SettledDate>0001-01-01T00:00:00</SettledDate>
        <Amount>0</Amount>
        <Status>Canceled</Status>
        <Message>Transaction Is Not Allowed To Void or Refund</Message>
      </BankCardRefundStatus>
    XML
  end

  def successful_void_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <BankCardRefundStatus xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.paymentresources.com/webservices/">
        <TransID>0</TransID>
      <TransID>207616632</TransID>
      <CreditID>0</CreditID>
      <RefID>123</RefID>
      <PostedDate>2010-08-09T12:25:00</PostedDate> <SettledDate>0001-01-01T00:00:00</SettledDate>
      <Amount>1.3100</Amount>
      <AuthCode>012921</AuthCode>
      <Status>Voided</Status>
      <AVSCode>N</AVSCode>
      <CVV2Code />
      </BankCardRefundStatus>
   XML
  end

  def failed_void_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <BankCardRefundStatus xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.paymentresources.com/webservices/">
      <TransID>0</TransID>
      <CreditID>0</CreditID>
      <PostedDate>0001-01-01T00:00:00</PostedDate> <SettledDate>0001-01-01T00:00:00</SettledDate>
      <Amount>0</Amount>
      <Status>Canceled</Status>
      <Message>Transaction Is Not Allowed To Void or Refund</Message>
      </BankCardRefundStatus>
     XML
   end
end
