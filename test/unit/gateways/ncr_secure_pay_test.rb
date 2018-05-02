require 'test_helper'

class NcrSecurePayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = NcrSecurePayGateway.new(username: 'login', password: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/\<username\>login\<\/username\>/, data)
      assert_match(/\<password\>password\<\/password\>/, data)
      assert_match(/\<action\>sale\<\/action\>/, data)
      assert_match(/\<amount\>1.00\<\/amount\>/, data)
      assert_match(/\<account\>#{@credit_card.number}\<\/account\>/, data)
      assert_match(/\<cv\>#{@credit_card.verification_value}\<\/cv\>/, data)
      assert_match(/\<comments\>Store Purchase\<\/comments\>/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '506897', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/\<username\>login\<\/username\>/, data)
      assert_match(/\<password\>password\<\/password\>/, data)
      assert_match(/\<action\>preauth\<\/action\>/, data)
      assert_match(/\<amount\>1.00\<\/amount\>/, data)
      assert_match(/\<account\>#{@credit_card.number}\<\/account\>/, data)
      assert_match(/\<cv\>#{@credit_card.verification_value}\<\/cv\>/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal '506899', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_capture

    response = stub_comms do
      @gateway.capture(@amount, '12345', @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/\<username\>login\<\/username\>/, data)
      assert_match(/\<password\>password\<\/password\>/, data)
      assert_match(/\<action\>preauthcomplete\<\/action\>/, data)
      assert_match(/\<amount\>1.00\<\/amount\>/, data)
      assert_match(/\<ttid\>12345\<\/ttid\>/, data)
    end.respond_with(successful_capture_response)

    assert_success response
    assert_equal '506901', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, 'ref123', @options)
    assert_failure response
  end

  def test_successful_refund

    response = stub_comms do
      @gateway.refund(@amount, '12345', @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/\<username\>login\<\/username\>/, data)
      assert_match(/\<password\>password\<\/password\>/, data)
      assert_match(/\<action\>credit\<\/action\>/, data)
      assert_match(/\<amount\>1.00\<\/amount\>/, data)
      assert_match(/\<ttid\>12345\<\/ttid\>/, data)
    end.respond_with(successful_refund_response)

    assert_success response
    assert_equal '506901', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_void

    response = stub_comms do
      @gateway.void('12345', @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/\<username\>login\<\/username\>/, data)
      assert_match(/\<password\>password\<\/password\>/, data)
      assert_match(/\<action\>void\<\/action\>/, data)
      assert_match(/\<ttid\>12345\<\/ttid\>/, data)
    end.respond_with(successful_void_response)

    assert_success response
    assert_equal '506905', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void(@credit_card, @options)
    assert_failure response
  end

  def test_successful_verify

    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, successful_void_response)

    assert_success response
    assert response.test?
  end

  def test_successful_verify_with_failed_void

    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)

    assert_success response
    assert response.test?
  end

  def test_failed_verify

    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response, failed_void_response)

    assert_failure response
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
    opening connection to testbox.monetra.com:8665...
    opened
    starting SSL for testbox.monetra.com:8665...
    SSL established
    <- "POST / HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: testbox.monetra.com:8665\r\nContent-Length: 461\r\n\r\n"
    <- "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<MonetraTrans>\n  <Trans identifier=\"1\">\n    <username>test_ecomm:public</username>\n    <password>publ1ct3st</password>\n    <action>sale</action>\n    <amount>1.00</amount>\n    <currency>USD</currency>\n    <cardholdername>Longbob Longsen</cardholdername>\n    <account>4111111111111111</account>\n    <cv>123</cv>\n    <expdate>0917</expdate>\n    <zip>K1C2N6</zip>\n    <street>456 My Street</street>\n  </Trans>\n</MonetraTrans>\n"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Server: MHTTP v1.1.0\r\n"
    -> "Content-Length: 641\r\n"
    -> "Content-Type: application/x-www-form-urlencoded\r\n"
    -> "Connection: Close\r\n"
    -> "\r\n"
    reading 641 bytes...
    -> "<MonetraResp>\n\t<DataTransferStatus code=\"SUCCESS\"/>\n\t<Resp identifier=\"1\">\n\t\t<cardholdername>Longbob Longsen</cardholdername>\n\t\t<phard_code>SUCCESS</phard_code>\n\t\t<item>805</item>\n\t\t<account>XXXXXXXXXXXX1111</account>\n\t\t<verbiage>APPROVED</verbiage>\n\t\t<code>AUTH</code>\n\t\t<rcpt_entry_mode>M</rcpt_entry_mode>\n\t\t<cardlevel>VISA_TRADITIONAL</cardlevel>\n\t\t<cardtype>VISA</cardtype>\n\t\t<ttid>506855</ttid>\n\t\t<rcpt_host_ts>010716144811</rcpt_host_ts>\n\t\t<avs>BAD</avs>\n\t\t<msoft_code>INT_SUCCESS</msoft_code>\n\t\t<cv>BAD</cv>\n\t\t<pclevel>0</pclevel>\n\t\t<auth>166322</auth>\n\t\t<timestamp>1452196091</timestamp>\n\t\t<batch>909</batch>\n\t</Resp>\n</MonetraResp>"
    read 641 bytes
    Conn close
    )
  end

  def post_scrubbed
    %q(
    opening connection to testbox.monetra.com:8665...
    opened
    starting SSL for testbox.monetra.com:8665...
    SSL established
    <- "POST / HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: testbox.monetra.com:8665\r\nContent-Length: 461\r\n\r\n"
    <- "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<MonetraTrans>\n  <Trans identifier=\"1\">\n    <username>test_ecomm:public</username>\n    <password>[FILTERED]</password>\n    <action>sale</action>\n    <amount>1.00</amount>\n    <currency>USD</currency>\n    <cardholdername>Longbob Longsen</cardholdername>\n    <account>[FILTERED]</account>\n    <cv>[FILTERED]</cv>\n    <expdate>0917</expdate>\n    <zip>K1C2N6</zip>\n    <street>456 My Street</street>\n  </Trans>\n</MonetraTrans>\n"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Server: MHTTP v1.1.0\r\n"
    -> "Content-Length: 641\r\n"
    -> "Content-Type: application/x-www-form-urlencoded\r\n"
    -> "Connection: Close\r\n"
    -> "\r\n"
    reading 641 bytes...
    -> "<MonetraResp>\n\t<DataTransferStatus code=\"SUCCESS\"/>\n\t<Resp identifier=\"1\">\n\t\t<cardholdername>Longbob Longsen</cardholdername>\n\t\t<phard_code>SUCCESS</phard_code>\n\t\t<item>805</item>\n\t\t<account>[FILTERED]</account>\n\t\t<verbiage>APPROVED</verbiage>\n\t\t<code>AUTH</code>\n\t\t<rcpt_entry_mode>M</rcpt_entry_mode>\n\t\t<cardlevel>VISA_TRADITIONAL</cardlevel>\n\t\t<cardtype>VISA</cardtype>\n\t\t<ttid>506855</ttid>\n\t\t<rcpt_host_ts>010716144811</rcpt_host_ts>\n\t\t<avs>BAD</avs>\n\t\t<msoft_code>INT_SUCCESS</msoft_code>\n\t\t<cv>[FILTERED]</cv>\n\t\t<pclevel>0</pclevel>\n\t\t<auth>166322</auth>\n\t\t<timestamp>1452196091</timestamp>\n\t\t<batch>909</batch>\n\t</Resp>\n</MonetraResp>"
    read 641 bytes
    Conn close
    )
  end

  def successful_purchase_response
    %(
      <MonetraResp>
        <DataTransferStatus code="SUCCESS"/>
        <Resp identifier="1">
          <pclevel>0</pclevel>
          <auth>612997</auth>
          <timestamp>1452204696</timestamp>
          <batch>909</batch>
          <cardholdername>Longbob Longsen</cardholdername>
          <phard_code>SUCCESS</phard_code>
          <item>833</item>
          <account>XXXXXXXXXXXX1111</account>
          <verbiage>APPROVED</verbiage>
          <code>AUTH</code>
          <rcpt_entry_mode>M</rcpt_entry_mode>
          <cardlevel>VISA_TRADITIONAL</cardlevel>
          <cardtype>VISA</cardtype>
          <ttid>506897</ttid>
          <rcpt_host_ts>010716171136</rcpt_host_ts>
          <avs>BAD</avs>
          <msoft_code>INT_SUCCESS</msoft_code>
          <cv>BAD</cv>
        </Resp>
      </MonetraResp>
    )
  end

  def failed_purchase_response
    %(
      <MonetraResp>
      	<DataTransferStatus code="SUCCESS"/>
      	<Resp identifier="1">
      		<phard_code>GENERICFAIL</phard_code>
      		<cv>BAD</cv>
      		<cardholdername>Longbob Longsen</cardholdername>
      		<rcpt_host_ts>010716171332</rcpt_host_ts>
      		<code>DENY</code>
      		<sequenceid>834</sequenceid>
      		<msoft_code>INT_SUCCESS</msoft_code>
      		<rcpt_entry_mode>M</rcpt_entry_mode>
      		<cardtype>VISA</cardtype>
      		<account>XXXXXXXXXXXX1111</account>
      		<timestamp>1452204812</timestamp>
      		<avs>BAD</avs>
      		<ttid>506898</ttid>
      		<verbiage>DECLINE</verbiage>
      	</Resp>
      </MonetraResp>
    )
  end

  def successful_authorize_response
    %(
      <MonetraResp>
      	<DataTransferStatus code="SUCCESS"/>
      	<Resp identifier="1">
      		<rcpt_host_ts>010716171552</rcpt_host_ts>
      		<avs>BAD</avs>
      		<code>AUTH</code>
      		<rcpt_entry_mode>M</rcpt_entry_mode>
      		<cardholdername>Longbob Longsen</cardholdername>
      		<pclevel>0</pclevel>
      		<auth>538752</auth>
      		<cardtype>VISA</cardtype>
      		<ttid>506899</ttid>
      		<verbiage>APPROVED</verbiage>
      		<account>XXXXXXXXXXXX1111</account>
      		<msoft_code>INT_SUCCESS</msoft_code>
      		<cardlevel>VISA_TRADITIONAL</cardlevel>
      		<timestamp>1452204952</timestamp>
      		<cv>BAD</cv>
      		<phard_code>SUCCESS</phard_code>
      		<item>835</item>
      	</Resp>
      </MonetraResp>
    )
  end

  def failed_authorize_response
    %(
      <MonetraResp>
        <DataTransferStatus code="SUCCESS"/>
        <Resp identifier="1">
          <timestamp>1452205008</timestamp>
          <rcpt_host_ts>010716171648</rcpt_host_ts>
          <cardtype>VISA</cardtype>
          <avs>BAD</avs>
          <cardholdername>Longbob Longsen</cardholdername>
          <msoft_code>INT_SUCCESS</msoft_code>
          <cv>BAD</cv>
          <phard_code>GENERICFAIL</phard_code>
          <ttid>506900</ttid>
          <code>DENY</code>
          <rcpt_entry_mode>M</rcpt_entry_mode>
          <sequenceid>836</sequenceid>
          <verbiage>DECLINE</verbiage>
          <account>XXXXXXXXXXXX1111</account>
        </Resp>
      </MonetraResp>
    )
  end

  def successful_capture_response
    %(
      <MonetraResp>
        <DataTransferStatus code="SUCCESS"/>
        <Resp identifier="1">
          <verbiage>SUCCESS</verbiage>
          <account>XXXXXXXXXXXX1111</account>
          <msoft_code>INT_SUCCESS</msoft_code>
          <code>AUTH</code>
          <timestamp>1452205042</timestamp>
          <pclevel>0</pclevel>
          <rcpt_entry_mode>M</rcpt_entry_mode>
          <cardtype>VISA</cardtype>
          <batch>909</batch>
          <ttid>506901</ttid>
          <cardholdername>Longbob Longsen</cardholdername>
          <rcpt_host_ts>010716171722</rcpt_host_ts>
          <phard_code>UNKNOWN</phard_code>
        </Resp>
      </MonetraResp>
    )
  end

  def failed_capture_response
    %(
      <MonetraResp>
        <DataTransferStatus code="SUCCESS"/>
        <Resp identifier="1">
          <verbiage>This transaction requires an apprcode ttid or unique ptrannum</verbiage>
          <timestamp>1452205210</timestamp>
          <phard_code>UNKNOWN</phard_code>
          <rcpt_host_ts>010716172010</rcpt_host_ts>
          <code>DENY</code>
          <msoft_code>DATA_BADTRANS</msoft_code>
          <rcpt_entry_mode>M</rcpt_entry_mode>
          <cardtype>UNKNOWN</cardtype>
          <ttid>506902</ttid>
        </Resp>
      </MonetraResp>
    )
  end

  def successful_refund_response
    %(
      <MonetraResp>
        <DataTransferStatus code="SUCCESS"/>
        <Resp identifier="1">
          <verbiage>SUCCESS</verbiage>
          <msoft_code>INT_SUCCESS</msoft_code>
          <code>AUTH</code>
          <timestamp>1452205042</timestamp>
          <pclevel>0</pclevel>
          <rcpt_entry_mode>M</rcpt_entry_mode>
          <batch>909</batch>
          <ttid>506901</ttid>
          <rcpt_host_ts>010716171722</rcpt_host_ts>
          <phard_code>UNKNOWN</phard_code>
        </Resp>
      </MonetraResp>
    )
  end

  def failed_refund_response
    %(
      <MonetraResp>
        <DataTransferStatus code="SUCCESS"/>
        <Resp identifier="1">
          <cardtype>VISA</cardtype>
          <verbiage>USE VOID OR REVERSAL TO REFUND UNSETTLED TRANSACTIONS</verbiage>
          <account>XXXXXXXXXXXX1111</account>
          <msoft_code>DATA_INVALIDMOD</msoft_code>
          <ttid>506904</ttid>
          <code>DENY</code>
          <cardholdername>Longbob Longsen</cardholdername>
          <timestamp>1452205437</timestamp>
          <rcpt_host_ts>010716172357</rcpt_host_ts>
          <rcpt_entry_mode>M</rcpt_entry_mode>
          <phard_code>UNKNOWN</phard_code>
        </Resp>
      </MonetraResp>
    )
  end

  def successful_void_response
    %(
      <MonetraResp>
        <DataTransferStatus code="SUCCESS"/>
        <Resp identifier="1">
          <rcpt_host_ts>010716172453</rcpt_host_ts>
          <ttid>506905</ttid>
          <verbiage>SUCCESS</verbiage>
          <msoft_code>INT_SUCCESS</msoft_code>
          <phard_code>UNKNOWN</phard_code>
          <cardholdername>Longbob Longsen</cardholdername>
          <timestamp>1452205493</timestamp>
          <code>AUTH</code>
          <batch>909</batch>
          <rcpt_entry_mode>M</rcpt_entry_mode>
          <cardtype>VISA</cardtype>
          <account>XXXXXXXXXXXX1111</account>
        </Resp>
      </MonetraResp>
    )
  end

  def failed_void_response
    %(
      <MonetraResp>
        <DataTransferStatus code="SUCCESS"/>
        <Resp identifier="1">
          <rcpt_host_ts>010716172604</rcpt_host_ts>
          <verbiage>Must specify ttid or ptrannum</verbiage>
          <timestamp>1452205564</timestamp>
          <msoft_code>UNKNOWN</msoft_code>
          <rcpt_entry_mode>M</rcpt_entry_mode>
          <phard_code>UNKNOWN</phard_code>
          <ttid>506906</ttid>
          <code>DENY</code>
          <cardtype>UNKNOWN</cardtype>
        </Resp>
      </MonetraResp>
    )
  end
end
