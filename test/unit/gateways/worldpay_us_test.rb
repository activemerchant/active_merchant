require 'test_helper'

class WorldpayUsTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = WorldpayUsGateway.new(
      acctid: 'acctid',
      subid: 'subid',
      merchantpin: 'merchantpin'
    )

    @credit_card = credit_card
    @check = check
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal '353583515|252889136', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_echeck_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @check)
    end.respond_with(successful_echeck_purchase_response)

    assert_success response

    assert_equal '421414035|306588394', response.authorization
    assert response.test?
  end

  def test_failed_echeck_purchase
    @gateway.expects(:ssl_post).returns(failed_echeck_purchase_response)

    response = @gateway.purchase(@amount, @check, @options)
    assert_failure response
  end

  def test_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal '354275517|253394390', response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/postonly=354275517/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '353583515|252889136', response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/historykeyid=353583515/, data)
      assert_match(/orderkeyid=252889136/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_void
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '353583515|252889136', response.authorization

    refund = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/historykeyid=353583515/, data)
      assert_match(/orderkeyid=252889136/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_unsuccessful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert response.message =~ /DECLINED/
  end

  def test_passing_cvv
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/#{@credit_card.verification_value}/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_billing_address
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :billing_address => address)
    end.check_request do |endpoint, data, headers|
      assert_match(/ci_billaddr1=456\+My\+Street/, data)
      assert_match(/ci_billzip=K1C2N6/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_phone_number
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :billing_address => address)
    end.check_request do |endpoint, data, headers|
      assert_match(/ci_phone=%28555%29555-5555/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_billing_address_without_phone
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :billing_address => address(:phone => nil))
    end.check_request do |endpoint, data, headers|
      assert_no_match(/udf3/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_empty_response_fails
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(empty_purchase_response)

    assert_failure response
    assert_equal 'Unable to read error message', response.message
  end

  def test_backup_url
    response = stub_comms(@gateway) do
      @gateway.purchase(@amount, @credit_card, use_backup_url: true)
    end.check_request do |endpoint, data, headers|
      assert_equal WorldpayUsGateway.backup_url, endpoint
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
    assert_equal @gateway.scrub(pre_scrubbed_check), post_scrubbed_check
  end

  private

  def successful_purchase_response
    %(
<html>
    <body>
        <plaintext>
Accepted=SALE:016918:891::353583515:::
historyid=353583515
orderid=252889136
Accepted=SALE:016918:891::353583515:::
ACCOUNTNUMBER=444666xxxxxx7892
authcode=016918
AuthNo=SALE:016918:891::353583515:::
AVS_RESULT=
BALANCE=
BATCHNUMBER=
CVV2_RESULT=
DEBIT_TRACE_NUMBER=
ENTRYMETHOD=KEYED
historyid=353583515
MERCHANT_DBA_ADDR=11121 Willows Road NE
MERCHANT_DBA_CITY=Redmond
MERCHANT_DBA_NAME=Merchant Partners
MERCHANT_DBA_PHONE=4254979909
MERCHANT_DBA_STATE=WA
MERCHANTID=542929804946788
orderid=252889136
PAYTYPE=Visa
PRODUCT_DESCRIPTION=
Reason=
RECEIPT_FOOTER=Thank You
recurid=0
refcode=353583515-016918
result=1
SEQUENCE_NUMBER=22818217
Status=Accepted
SYSTEMAUDITTRACENUMBER=891
TERMINALID=160551
TRANSGUID=3178ed9f-4d03-4d29-98c0-1b203f52cfe1:374
transid=22818217
transresult=APPROVED
    )
  end

  def failed_purchase_response
    %(
<html>
    <body>
        <plaintext>
Declined=DECLINED:1101970001:Invalid Expiration Date:
historyid=354275106
orderid=253393990
ACCOUNTNUMBER=444666xxxxxx7892
Declined=DECLINED:1101970001:Invalid Expiration Date:
ENTRYMETHOD=KEYED
historyid=354275106
orderid=253393990
PAYTYPE=Visa
rcode=1101970001
Reason=DECLINED:1101970001:Invalid Expiration Date:
recurid=0
result=0
Status=Declined
transid=0
    )
  end

  def successful_authorize_response
    %(
<html>
    <body>
        <plaintext>
Accepted=AUTH:070484:548::354275517:::
historyid=354275517
orderid=253394390
Accepted=AUTH:070484:548::354275517:::
ACCOUNTNUMBER=444666xxxxxx7892
authcode=070484
AuthNo=AUTH:070484:548::354275517:::
AVS_RESULT=
BALANCE=
BATCHNUMBER=
CVV2_RESULT=
DEBIT_TRACE_NUMBER=
ENTRYMETHOD=KEYED
historyid=354275517
MERCHANT_DBA_ADDR=11121 Willows Road NE
MERCHANT_DBA_CITY=Redmond
MERCHANT_DBA_NAME=Merchant Partners
MERCHANT_DBA_PHONE=4254979909
MERCHANT_DBA_STATE=WA
MERCHANTID=542929804946788
orderid=253394390
PAYTYPE=Visa
PRODUCT_DESCRIPTION=
Reason=
RECEIPT_FOOTER=Thank You
recurid=0
refcode=354275517-070484
result=1
SEQUENCE_NUMBER=23067552
Status=Accepted
SYSTEMAUDITTRACENUMBER=548
TERMINALID=160551
TRANSGUID=561a665f-12d2-4416-a153-c0def07b13c5:265
transid=23067552
transresult=APPROVED
    )
  end

  def successful_echeck_purchase_response
    %(
<html><body><plaintext>
Accepted=CHECKAUTH:421414035:::421414035:::
historyid=421414035
orderid=306588394
Accepted=CHECKAUTH:421414035:::421414035:::
ACCOUNTNUMBER=****8535
authcode=421414035
AuthNo=CHECKAUTH:421414035:::421414035:::
ENTRYMETHOD=KEYED
historyid=421414035
MERCHANTORDERNUMBER=691831d72f862d0fe24c52420f7f6963
orderid=306588394
PAYTYPE=Check
recurid=0
refcode=421414035-421414035
result=1
Status=Accepted
transid=0
      )
  end

  def failed_echeck_purchase_response
    %(
<html><body><plaintext>
Declined=DECLINED:1102780001:Invalid Bank:
historyid=421428338
orderid=306594834
ACCOUNTNUMBER=****8535
Declined=DECLINED:1102780001:Invalid Bank:
ENTRYMETHOD=KEYED
historyid=421428338
MERCHANTORDERNUMBER=5e9e7e04267187992c959eb9a55c4017
orderid=306594834
PAYTYPE=Check
rcode=1102780001
Reason=DECLINED:1102780001:Invalid Bank:
recurid=0
result=0
Status=Declined
transid=0
      )
  end

  def failed_authorize_response
    %(
<html><body><plaintext>
Declined=DECLINED:0500870009:PICK UP CARD:
historyid=354468057
orderid=253537576
ACCOUNTNUMBER=400030xxxxxx2220
Declined=DECLINED:0500870009:PICK UP CARD:
ENTRYMETHOD=KEYED
historyid=354468057
MERCHANTORDERNUMBER=1
orderid=253537576
PAYTYPE=Visa
rcode=0500870009
Reason=DECLINED:0500870009:PICK UP CARD:
recurid=0
result=0
Status=Declined
SYSTEMAUDITTRACENUMBER=652
TRANSGUID=408e6eae-fc22-4117-bd22-92d51218c27c:546
transid=23132495
    )
  end

  alias successful_capture_response successful_authorize_response
  alias successful_refund_response successful_authorize_response

  def empty_purchase_response
    %(
    )
  end

  def successful_void_response
    %(
<html><body><plaintext>
Accepted=VOID:001849:643::354467495:::
historyid=354467495
orderid=253537232
Accepted=VOID:001849:643::354467495:::
ACCOUNTNUMBER=444666xxxxxx7892
authcode=001849
AuthNo=VOID:001849:643::354467495:::
AVS_RESULT=
BALANCE=
BATCHNUMBER=
CVV2_RESULT=
DEBIT_TRACE_NUMBER=
ENTRYMETHOD=KEYED
historyid=354467495
MERCHANT_DBA_ADDR=11121 Willows Road NE
MERCHANT_DBA_CITY=Redmond
MERCHANT_DBA_NAME=Merchant Partners
MERCHANT_DBA_PHONE=4254979909
MERCHANT_DBA_STATE=WA
MERCHANTID=542929804946788
MERCHANTORDERNUMBER=1
orderid=253537232
PAYTYPE=Visa
PRODUCT_DESCRIPTION=
Reason=
RECEIPT_FOOTER=Thank You
recurid=0
refcode=354467495-001849
result=1
SEQUENCE_NUMBER=23132246
Status=Accepted
SYSTEMAUDITTRACENUMBER=643
TERMINALID=160551
TRANSGUID=15681fd7-b3a8-48b1-90be-9857ab426ca4:265
transid=23132246
transresult=APPROVED
    )
  end

  def failed_void_response
    %(
<html><body><plaintext>
Declined=DECLINED:3101680001:Invalid acct type:
historyid=
orderid=
Declined=DECLINED:3101680001:Invalid acct type:
rcode=3101680001
Reason=DECLINED:3101680001:Invalid acct type:
result=0
Status=Declined
transid=0
    )
  end

  def pre_scrubbed
    <<-EOS
opening connection to trans.worldpay.us:443...
opened
starting SSL for trans.worldpay.us:443...
SSL established
<- "POST /cgi-bin/process.cgi HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: trans.worldpay.us\r\nContent-Length: 425\r\n\r\n"
<- "acctid=MPNAB&action=ns_quicksale_cc&amount=1.00&ccname=Longbob+Longsen&ccnum=4446661234567892&ci_billaddr1=456+My+Street&ci_billaddr2=Apt+1&ci_billcity=Ottawa&ci_billcountry=CA&ci_billstate=ON&ci_billzip=K1C2N6&ci_companyname=Widgets+Inc&ci_email=&ci_ipaddress=&ci_phone=%28555%29555-5555&currencycode=USD&cvv2=987&expmon=09&expyear=2019&merchantordernumber=67f4f20082e79684f036f25dafe96304&merchantpin=1234567890&subid=SPREE"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 13 Feb 2018 19:28:27 GMT\r\n"
-> "Server: Apache\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "Content-Type: text/html;charset=ISO-8859-1\r\n"
-> "Content-Length: 962\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 962 bytes...
-> "<html><body><plaintext>\r\nAccepted=SALE:036586:477::919067116:N::N\r\nhistoryid=919067116\r\norderid=722189706\r\nAccepted=SALE:036586:477::919067116:N::N\r\nACCOUNTNUMBER=************7892\r\nACCTID=MPNAB\r\nauthcode=036586\r\nAuthNo=SALE:036586:477::919067116:N::N\r\nAVS_RESULT=N\r\nBATCHNUMBER=\r\nCVV2_RESULT=N\r\nDEBIT_TRACE_NUMBER=\r\nENTRYMETHOD=M\r\nhistoryid=919067116\r\nMERCHANT_DBA_ADDR=11121 Willows Road NE\r\nMERCHANT_DBA_CITY=Redmond\r\nMERCHANT_DBA_NAME=Merchant Partners\r\nMERCHANT_DBA_PHONE=4254979909\r\nMERCHANT_DBA_STATE=WA\r\nMERCHANTID=542929804946788\r\nMERCHANTORDERNUMBER=67f4f20082e79684f036f25dafe96304\r\norderid=722189706\r\nPAYTYPE=Visa\r\nPRODUCT_DESCRIPTION=\r\nReason=\r\nRECEIPT_FOOTER=Thank You\r\nrecurid=0\r\nrefcode=919067116-036586\r\nresult=1\r\nSEQUENCE_NUMBER=370609730\r\nStatus=Accepted\r\nSUBID=SPREE\r\nSYSTEMAUDITTRACENUMBER=477\r\nTERMINALID=160551\r\nTRANSGUID=d5701d57-9147-4ded-b596-6805581f081c:266\r\ntransid=370609730\r\ntransresult=APPROVED\r\nVISATRANSACTIONID=088044000036586\r\n"
read 962 bytes
Conn close
    EOS
  end

  def post_scrubbed
    <<-EOS
opening connection to trans.worldpay.us:443...
opened
starting SSL for trans.worldpay.us:443...
SSL established
<- "POST /cgi-bin/process.cgi HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: trans.worldpay.us\r\nContent-Length: 425\r\n\r\n"
<- "acctid=MPNAB&action=ns_quicksale_cc&amount=1.00&ccname=Longbob+Longsen&ccnum=[FILTERED]&ci_billaddr1=456+My+Street&ci_billaddr2=Apt+1&ci_billcity=Ottawa&ci_billcountry=CA&ci_billstate=ON&ci_billzip=K1C2N6&ci_companyname=Widgets+Inc&ci_email=&ci_ipaddress=&ci_phone=%28555%29555-5555&currencycode=USD&cvv2=[FILTERED]&expmon=09&expyear=2019&merchantordernumber=67f4f20082e79684f036f25dafe96304&merchantpin=[FILTERED]&subid=SPREE"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 13 Feb 2018 19:28:27 GMT\r\n"
-> "Server: Apache\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "Content-Type: text/html;charset=ISO-8859-1\r\n"
-> "Content-Length: 962\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 962 bytes...
-> "<html><body><plaintext>\r\nAccepted=SALE:036586:477::919067116:N::N\r\nhistoryid=919067116\r\norderid=722189706\r\nAccepted=SALE:036586:477::919067116:N::N\r\nACCOUNTNUMBER=************7892\r\nACCTID=MPNAB\r\nauthcode=036586\r\nAuthNo=SALE:036586:477::919067116:N::N\r\nAVS_RESULT=N\r\nBATCHNUMBER=\r\nCVV2_RESULT=N\r\nDEBIT_TRACE_NUMBER=\r\nENTRYMETHOD=M\r\nhistoryid=919067116\r\nMERCHANT_DBA_ADDR=11121 Willows Road NE\r\nMERCHANT_DBA_CITY=Redmond\r\nMERCHANT_DBA_NAME=Merchant Partners\r\nMERCHANT_DBA_PHONE=4254979909\r\nMERCHANT_DBA_STATE=WA\r\nMERCHANTID=542929804946788\r\nMERCHANTORDERNUMBER=67f4f20082e79684f036f25dafe96304\r\norderid=722189706\r\nPAYTYPE=Visa\r\nPRODUCT_DESCRIPTION=\r\nReason=\r\nRECEIPT_FOOTER=Thank You\r\nrecurid=0\r\nrefcode=919067116-036586\r\nresult=1\r\nSEQUENCE_NUMBER=370609730\r\nStatus=Accepted\r\nSUBID=SPREE\r\nSYSTEMAUDITTRACENUMBER=477\r\nTERMINALID=160551\r\nTRANSGUID=d5701d57-9147-4ded-b596-6805581f081c:266\r\ntransid=370609730\r\ntransresult=APPROVED\r\nVISATRANSACTIONID=088044000036586\r\n"
read 962 bytes
Conn close
    EOS
  end

  def pre_scrubbed_check
    <<-EOS
opening connection to trans.worldpay.us:443...
opened
starting SSL for trans.worldpay.us:443...
SSL established
<- "POST /cgi-bin/process.cgi HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: trans.worldpay.us\r\nContent-Length: 412\r\n\r\n"
<- "acctid=MPNAB&action=ns_quicksale_check&amount=1.00&ci_billaddr1=456+My+Street&ci_billaddr2=Apt+1&ci_billcity=Ottawa&ci_billcountry=CA&ci_billstate=ON&ci_billzip=K1C2N6&ci_companyname=Widgets+Inc&ci_email=&ci_ipaddress=&ci_phone=%28555%29555-5555&ckaba=244183602&ckacct=15378535&ckaccttype=1&ckno=12345654321&currencycode=USD&merchantordernumber=5ec80ff8210dc9d24248ac2777d6b4f3&merchantpin=1234567890&subid=SPREE"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 13 Feb 2018 19:29:38 GMT\r\n"
-> "Server: Apache\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "Content-Type: text/html;charset=ISO-8859-1\r\n"
-> "Content-Length: 414\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 414 bytes...
-> "<html><body><plaintext>\r\nDeclined=DECLINED:1103180001:Invalid Bank:\r\nhistoryid=919060608\r\norderid=722196666\r\nACCOUNTNUMBER=****8535\r\nDeclined=DECLINED:1103180001:Invalid Bank:\r\nENTRYMETHOD=KEYED\r\nhistoryid=919060608\r\nMERCHANTORDERNUMBER=5ec80ff8210dc9d24248ac2777d6b4f3\r\norderid=722196666\r\nPAYTYPE=Check\r\nrcode=1103180001\r\nReason=DECLINED:1103180001:Invalid Bank:\r\nrecurid=0\r\nresult=0\r\nStatus=Declined\r\ntransid=0\r\n"
read 414 bytes
Conn close
    EOS
  end

  def post_scrubbed_check
    <<-EOS
opening connection to trans.worldpay.us:443...
opened
starting SSL for trans.worldpay.us:443...
SSL established
<- "POST /cgi-bin/process.cgi HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: trans.worldpay.us\r\nContent-Length: 412\r\n\r\n"
<- "acctid=MPNAB&action=ns_quicksale_check&amount=1.00&ci_billaddr1=456+My+Street&ci_billaddr2=Apt+1&ci_billcity=Ottawa&ci_billcountry=CA&ci_billstate=ON&ci_billzip=K1C2N6&ci_companyname=Widgets+Inc&ci_email=&ci_ipaddress=&ci_phone=%28555%29555-5555&ckaba=244183602&ckacct=[FILTERED]&ckaccttype=1&ckno=12345654321&currencycode=USD&merchantordernumber=5ec80ff8210dc9d24248ac2777d6b4f3&merchantpin=[FILTERED]&subid=SPREE"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 13 Feb 2018 19:29:38 GMT\r\n"
-> "Server: Apache\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "Content-Type: text/html;charset=ISO-8859-1\r\n"
-> "Content-Length: 414\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 414 bytes...
-> "<html><body><plaintext>\r\nDeclined=DECLINED:1103180001:Invalid Bank:\r\nhistoryid=919060608\r\norderid=722196666\r\nACCOUNTNUMBER=****8535\r\nDeclined=DECLINED:1103180001:Invalid Bank:\r\nENTRYMETHOD=KEYED\r\nhistoryid=919060608\r\nMERCHANTORDERNUMBER=5ec80ff8210dc9d24248ac2777d6b4f3\r\norderid=722196666\r\nPAYTYPE=Check\r\nrcode=1103180001\r\nReason=DECLINED:1103180001:Invalid Bank:\r\nrecurid=0\r\nresult=0\r\nStatus=Declined\r\ntransid=0\r\n"
read 414 bytes
Conn close
    EOS
  end
end
