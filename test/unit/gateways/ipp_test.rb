require 'test_helper'

class IppTest < Test::Unit::TestCase
  def setup
    @gateway = IppGateway.new(
      username: 'username',
      password: 'password',
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
    }
  end

  def test_purchase_request
    @gateway.expects(:commit).with("SubmitSinglePayment", purchase_request)
    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_authorize_request
    @gateway.expects(:commit).with("SubmitSinglePayment", authorize_request)
    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_capture_request
    @gateway.expects(:commit).with("SubmitSingleCapture", capture_request)
    @gateway.capture(@amount, "10001197", @options)
  end

  def test_refund_request
    @gateway.expects(:commit).with("SubmitSingleRefund", refund_request)
    @gateway.refund(@amount, "10001197", @options)
  end

  def test_successful_commit
    @gateway.expects(:ssl_post).returns(successful_response)
    response = @gateway.send(:commit, "ACTION", "DATA")
    assert response.test?
    assert_success response
    assert_equal '10001197', response.authorization
    assert_nil response.error_code
  end

  def test_failed_commit
    @gateway.expects(:ssl_post).returns(failed_response)
    response = @gateway.send(:commit, "ACTION", "DATA")
    assert response.test?
    assert_failure response
    assert_equal 'Do Not Honour', response.message
    assert_equal "card_declined", response.error_code
  end

  private

  def purchase_request
    <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <SubmitSinglePayment xmlns="http://www.ippayments.com.au/interface/api/dts">
      <trnXML>
<![CDATA[
<Transaction>
  <CustRef>1</CustRef>
  <Amount>100</Amount>
  <TrnType>1</TrnType>
  <CreditCard Registered="False">
    <CardNumber>4242424242424242</CardNumber>
    <ExpM>09</ExpM>
    <ExpY>2015</ExpY>
    <CVN>123</CVN>
    <CardHolderName>Longbob Longsen</CardHolderName>
  </CreditCard>
  <Security>
    <UserName>username</UserName>
    <Password>password</Password>
  </Security>
  <TrnSource/>
</Transaction>
]]>
      </trnXML>
    </SubmitSinglePayment>
  </soap:Body>
</soap:Envelope>
    EOF
  end

  def authorize_request
    <<-END
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <SubmitSinglePayment xmlns="http://www.ippayments.com.au/interface/api/dts">
      <trnXML>
<![CDATA[
<Transaction>
  <CustRef>1</CustRef>
  <Amount>100</Amount>
  <TrnType>2</TrnType>
  <CreditCard Registered="False">
    <CardNumber>4242424242424242</CardNumber>
    <ExpM>09</ExpM>
    <ExpY>2015</ExpY>
    <CVN>123</CVN>
    <CardHolderName>Longbob Longsen</CardHolderName>
  </CreditCard>
  <Security>
    <UserName>username</UserName>
    <Password>password</Password>
  </Security>
  <TrnSource/>
</Transaction>
]]>
      </trnXML>
    </SubmitSinglePayment>
  </soap:Body>
</soap:Envelope>
    END
  end

  def capture_request
    <<-END
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <SubmitSingleCapture xmlns="http://www.ippayments.com.au/interface/api/dts">
      <trnXML>
<![CDATA[
<Capture>
  <Receipt>10001197</Receipt>
  <Amount>100</Amount>
  <Security>
    <UserName>username</UserName>
    <Password>password</Password>
  </Security>
</Capture>
]]>
      </trnXML>
    </SubmitSingleCapture>
  </soap:Body>
</soap:Envelope>
    END
  end

  def refund_request
    <<-END
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <SubmitSingleRefund xmlns="http://www.ippayments.com.au/interface/api/dts">
      <trnXML>
<![CDATA[
<Refund>
  <Receipt>10001197</Receipt>
  <Amount>100</Amount>
  <Security>
    <UserName>username</UserName>
    <Password>password</Password>
  </Security>
</Refund>
]]>
      </trnXML>
    </SubmitSingleRefund>
  </soap:Body>
</soap:Envelope>
    END
  end

  def successful_response
    <<-EOF
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><SubmitSinglePaymentResponse xmlns="http://www.ippayments.com.au/interface/api/dts"><SubmitSinglePaymentResult>&lt;Response&gt;
	&lt;ResponseCode&gt;0&lt;/ResponseCode&gt;
	&lt;Timestamp&gt;23-Sep-2011 15:33:25&lt;/Timestamp&gt;
	&lt;Receipt&gt;10001197&lt;/Receipt&gt;
	&lt;SettlementDate&gt;23-Sep-2011&lt;/SettlementDate&gt;
	&lt;DeclinedCode&gt;&lt;/DeclinedCode&gt;
	&lt;DeclinedMessage&gt;&lt;/DeclinedMessage&gt;
&lt;/Response&gt;
</SubmitSinglePaymentResult></SubmitSinglePaymentResponse></soap:Body></soap:Envelope>
    EOF
  end

  def failed_response
    <<-EOF
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><SubmitSinglePaymentResponse xmlns="http://www.ippayments.com.au/interface/api/dts"><SubmitSinglePaymentResult>&lt;Response&gt;
	&lt;ResponseCode&gt;1&lt;/ResponseCode&gt;
	&lt;Timestamp&gt;23-Sep-2011 15:33:25&lt;/Timestamp&gt;
	&lt;Receipt&gt;10001197&lt;/Receipt&gt;
	&lt;SettlementDate&gt;23-Sep-2011&lt;/SettlementDate&gt;
	&lt;DeclinedCode&gt;5&lt;/DeclinedCode&gt;
	&lt;DeclinedMessage&gt;Do Not Honour&lt;/DeclinedMessage&gt;
&lt;/Response&gt;
</SubmitSinglePaymentResult></SubmitSinglePaymentResponse></soap:Body></soap:Envelope>
    EOF
  end
end
