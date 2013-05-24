require 'test_helper'

class MercuryTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.gateway_mode = :test

    @gateway = MercuryGateway.new(fixtures(:mercury))

    @amount = 100
    @credit_card = credit_card("5499990123456781", :brand => "master")
    @declined_card = credit_card('4000300011112220')

    @options = {
      :credit_card => @credit_card,
      :order_id => '1',
    }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/InvoiceNo>1</, data)
    end.respond_with(successful_purchase_response)

    assert_instance_of Response, response
    assert_success response

    assert_equal '1;0194;000011;KbMCC0742510421  ;|17|410100700000', response.authorization
    assert response.test?
  end

  def test_order_id_must_be_numeric
    e = assert_raise(ArgumentError) do
      @gateway.purchase(@amount, @credit_card, :order_id => "a")
    end
    assert_match(/not numeric/, e.message)
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)

    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert refund_response = @gateway.refund(@amount, response.authorization, :credit_card => @credit_card)

    assert_instance_of Response, refund_response
    assert_success refund_response
    assert refund_response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_success response
    assert_equal "1;;000077;KbMCC1054050524  e00;|14|410100701000", response.authorization
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)

    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, response.authorization, @options)

    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end

  def test_successful_batch_clear
    @gateway.expects(:ssl_post).returns(successful_clear_response)

    assert response = @gateway.batch_clear()

    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end

  def test_successful_batch_summary
    @gateway.expects(:ssl_post).returns(successful_summary_response)
    assert response = @gateway.batch_summary()

    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end

  def test_successful_batch_close
    assert response = @gateway.expects(:ssl_post).returns(successful_summary_response)

    assert response = @gateway.batch_summary()

    @gateway.expects(:ssl_post).returns(successful_close_response)

    assert response = @gateway.batch_close(response.params.symbolize_keys)

    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end

  private

  def successful_purchase_response
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><CreditTransactionResponse xmlns="http://www.mercurypay.com"><CreditTransactionResult>&lt;?xml version="1.0"?&gt;
&lt;RStream&gt;
  &lt;CmdResponse&gt;
    &lt;ResponseOrigin&gt;Processor&lt;/ResponseOrigin&gt;
    &lt;DSIXReturnCode&gt;000000&lt;/DSIXReturnCode&gt;
    &lt;CmdStatus&gt;Approved&lt;/CmdStatus&gt;
    &lt;TextResponse&gt;AP*&lt;/TextResponse&gt;
    &lt;UserTraceData&gt;&lt;/UserTraceData&gt;
  &lt;/CmdResponse&gt;
  &lt;TranResponse&gt;
    &lt;MerchantID&gt;595901&lt;/MerchantID&gt;
    &lt;AcctNo&gt;5499990123456781&lt;/AcctNo&gt;
    &lt;ExpDate&gt;0813&lt;/ExpDate&gt;
    &lt;CardType&gt;M/C&lt;/CardType&gt;
    &lt;TranCode&gt;Sale&lt;/TranCode&gt;
    &lt;AuthCode&gt;000011&lt;/AuthCode&gt;
    &lt;CaptureStatus&gt;Captured&lt;/CaptureStatus&gt;
    &lt;RefNo&gt;0194&lt;/RefNo&gt;
    &lt;InvoiceNo&gt;1&lt;/InvoiceNo&gt;
    &lt;AVSResult&gt;Y&lt;/AVSResult&gt;
    &lt;CVVResult&gt;M&lt;/CVVResult&gt;
    &lt;OperatorID&gt;999&lt;/OperatorID&gt;
    &lt;Memo&gt;LM Integration (Ruby)&lt;/Memo&gt;
    &lt;Amount&gt;
      &lt;Purchase&gt;1.00&lt;/Purchase&gt;
      &lt;Authorize&gt;1.00&lt;/Authorize&gt;
    &lt;/Amount&gt;
    &lt;AcqRefData&gt;KbMCC0742510421  &lt;/AcqRefData&gt;
    &lt;ProcessData&gt;|17|410100700000&lt;/ProcessData&gt;
  &lt;/TranResponse&gt;
&lt;/RStream&gt;
</CreditTransactionResult></CreditTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><CreditTransactionResponse xmlns="http://www.mercurypay.com"><CreditTransactionResult>&lt;?xml version="1.0"?&gt;
&lt;RStream&gt;
  &lt;CmdResponse&gt;
    &lt;ResponseOrigin&gt;Server&lt;/ResponseOrigin&gt;
    &lt;DSIXReturnCode&gt;004101&lt;/DSIXReturnCode&gt;
    &lt;CmdStatus&gt;Error&lt;/CmdStatus&gt;
    &lt;TextResponse&gt;No Live Cards on Test Merchant ID Allowed.&lt;/TextResponse&gt;
    &lt;UserTraceData&gt;&lt;/UserTraceData&gt;
  &lt;/CmdResponse&gt;
&lt;/RStream&gt;
</CreditTransactionResult></CreditTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><CreditTransactionResponse xmlns="http://www.mercurypay.com"><CreditTransactionResult>&lt;?xml version="1.0"?&gt;
&lt;RStream&gt;
  &lt;CmdResponse&gt;
    &lt;ResponseOrigin&gt;Processor&lt;/ResponseOrigin&gt;
    &lt;DSIXReturnCode&gt;000000&lt;/DSIXReturnCode&gt;
    &lt;CmdStatus&gt;Approved&lt;/CmdStatus&gt;
    &lt;TextResponse&gt;AP&lt;/TextResponse&gt;
    &lt;UserTraceData&gt;&lt;/UserTraceData&gt;
  &lt;/CmdResponse&gt;
  &lt;TranResponse&gt;
    &lt;MerchantID&gt;595901&lt;/MerchantID&gt;
    &lt;AcctNo&gt;5499990123456781&lt;/AcctNo&gt;
    &lt;ExpDate&gt;0813&lt;/ExpDate&gt;
    &lt;CardType&gt;M/C&lt;/CardType&gt;
    &lt;TranCode&gt;VoidSale&lt;/TranCode&gt;
    &lt;AuthCode&gt;VOIDED&lt;/AuthCode&gt;
    &lt;CaptureStatus&gt;Captured&lt;/CaptureStatus&gt;
    &lt;RefNo&gt;0568&lt;/RefNo&gt;
    &lt;InvoiceNo&gt;123&lt;/InvoiceNo&gt;
    &lt;OperatorID&gt;999&lt;/OperatorID&gt;
    &lt;Amount&gt;
      &lt;Purchase&gt;1.00&lt;/Purchase&gt;
      &lt;Authorize&gt;1.00&lt;/Authorize&gt;
    &lt;/Amount&gt;
    &lt;AcqRefData&gt;K&lt;/AcqRefData&gt;
  &lt;/TranResponse&gt;
&lt;/RStream&gt;
</CreditTransactionResult></CreditTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end

  def successful_clear_response
    <<-RESPONSE
<?xml version=1.0 encoding=utf-8?><soap:Envelope xmlns:soap=http://schemas.xmlsoap.org/soap/envelope/ xmlns:xsi=http://www.w3.org/2001/XMLSchema-instance xmlns:xsd=http://www.w3.org/2001/XMLSchema><soap:Body><CreditTransactionResponse xmlns=http://www.mercurypay.com><CreditTransactionResult>&lt;?xml version=1.0?&gt;^M
&lt;RStream&gt;^M
  &lt;CmdResponse&gt;^M
    &lt;ResponseOrigin&gt;Processor&lt;/ResponseOrigin&gt;^M
    &lt;DSIXReturnCode&gt;000000&lt;/DSIXReturnCode&gt;^M
    &lt;CmdStatus&gt;Success&lt;/CmdStatus&gt;^M
    &lt;TextResponse&gt;OK&lt;/TextResponse&gt;^M
    &lt;UserTraceData&gt;&lt;/UserTraceData&gt;^M
  &lt;/CmdResponse&gt;^M
  &lt;BatchClear&gt;^M
    &lt;MerchantID&gt;595901&lt;/MerchantID&gt;^M
    &lt;NetBatchTotal&gt;0.00&lt;/NetBatchTotal&gt;^M
  &lt;/BatchClear&gt;^M
&lt;/RStream&gt;^M
</CreditTransactionResult></CreditTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end

  def successful_summary_response
    <<-RESPONSE
<?xml version=1.0 encoding=utf-8?><soap:Envelope xmlns:soap=http://schemas.xmlsoap.org/soap/envelope/ xmlns:xsi=http://www.w3.org/2001/XMLSchema-instance xmlns:xsd=http://www.w3.org/2001/XMLSchema><soap:Body><CreditTransactionResponse xmlns=http://www.mercurypay.com><CreditTransactionResult><?xml version=1.0?>^M
<RStream>^M
  <CmdResponse>^M
    <ResponseOrigin>Processor</ResponseOrigin>^M
    <DSIXReturnCode>000000</DSIXReturnCode>^M
    <CmdStatus>Success</CmdStatus>^M
    <TextResponse>OK</TextResponse>^M
    <UserTraceData></UserTraceData>^M
  </CmdResponse>^M
  <BatchSummary>^M
    <MerchantID>595901</MerchantID>^M
    <BatchNo>4182</BatchNo>^M
    <BatchItemCount>8</BatchItemCount>^M
    <NetBatchTotal>15.16</NetBatchTotal>^M
    <CreditPurchaseCount>8</CreditPurchaseCount>^M
    <CreditPurchaseAmount>15.16</CreditPurchaseAmount>^M
    <CreditReturnCount>0</CreditReturnCount>^M
    <CreditReturnAmount>0.00</CreditReturnAmount>^M
    <DebitPurchaseCount>0</DebitPurchaseCount>^M
    <DebitPurchaseAmount>0.00</DebitPurchaseAmount>^M
    <DebitReturnCount>0</DebitReturnCount>^M
    <DebitReturnAmount>0.00</DebitReturnAmount>^M
  </BatchSummary>^M
</RStream>^M
</CreditTransactionResult></CreditTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end

  def successful_close_response
    <<-RESPONSE
<?xml version=1.0 encoding=utf-8?><soap:Envelope xmlns:soap=http://schemas.xmlsoap.org/soap/envelope/ xmlns:xsi=http://www.w3.org/2001/XMLSchema-instance xmlns:xsd=http://www.w3.org/2001/XMLSchema><soap:Body><CreditTransactionResponse xmlns=http://www.mercurypay.com><CreditTransactionResult><?xml version=1.0?>^M
<RStream>^M
<CmdResponse>^M
<ResponseOrigin>Processor</ResponseOrigin>^M
<DSIXReturnCode>000000</DSIXReturnCode>^M
<CmdStatus>Success</CmdStatus>^M
<TextResponse>OK TEST</TextResponse>^M
<UserTraceData></UserTraceData>^M
</CmdResponse>^M
<BatchClose>^M
<MerchantID>595901</MerchantID>^M
<BatchNo>4182</BatchNo>^M
<BatchItemCount>8</BatchItemCount>^M
<NetBatchTotal>15.16</NetBatchTotal>^M
<CreditPurchaseCount>8</CreditPurchaseCount>^M
<CreditPurchaseAmount>15.16</CreditPurchaseAmount>^M
<CreditReturnCount>0</CreditReturnCount>^M
<CreditReturnAmount>0.00</CreditReturnAmount>^M
<DebitPurchaseCount>0</DebitPurchaseCount>^M
<DebitPurchaseAmount>0.00</DebitPurchaseAmount>^M
<DebitReturnCount>0</DebitReturnCount>^M
<DebitReturnAmount>0.00</DebitReturnAmount>^M
<ControlNo>144105408   </ControlNo>^M
</BatchClose>^M
</RStream>^M
</CreditTransactionResult></CreditTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
<?xml version=1.0 encoding=utf-8?><soap:Envelope xmlns:soap=http://schemas.xmlsoap.org/soap/envelope/ xmlns:xsi=http://www.w3.org/2001/XMLSchema-instance xmlns:xsd=http://www.w3.org/2001/XMLSchema><soap:Body><CreditTransactionResponse xmlns=http://www.mercurypay.com><CreditTransactionResult><?xml version=1.0?>^M
<RStream>^M
  <CmdResponse>^M
    <ResponseOrigin>Processor</ResponseOrigin>^M
    <DSIXReturnCode>000000</DSIXReturnCode>^M
    <CmdStatus>Approved</CmdStatus>^M
    <TextResponse>AP</TextResponse>^M
    <UserTraceData></UserTraceData>^M
  </CmdResponse>^M
  <TranResponse>^M
    <MerchantID>595901</MerchantID>^M
    <AcctNo>5499990123456781</AcctNo>^M
    <ExpDate>0914</ExpDate>^M
    <CardType>M/C</CardType>^M
    <TranCode>PreAuth</TranCode>^M
    <AuthCode>000077</AuthCode>^M
    <InvoiceNo>1</InvoiceNo>^M
    <CVVResult>M</CVVResult>^M
    <Amount>^M
      <Purchase>1.00</Purchase>^M
      <Authorize>1.00</Authorize>^M
    </Amount>^M
    <AcqRefData>KbMCC1054050524  e00</AcqRefData>^M
    <ProcessData>|14|410100701000</ProcessData>^M
  </TranResponse>^M
</RStream>^M
</CreditTransactionResult></CreditTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
<?xml version=1.0 encoding=utf-8?><soap:Envelope xmlns:soap=http://schemas.xmlsoap.org/soap/envelope/ xmlns:xsi=http://www.w3.org/2001/XMLSchema-instance xmlns:xsd=http://www.w3.org/2001/XMLSchema><soap:Body><CreditTransactionResponse xmlns=http://www.mercurypay.com><CreditTransactionResult><?xml version=1.0?>^M
<RStream>^M
  <CmdResponse>^M
    <ResponseOrigin>Processor</ResponseOrigin>^M
    <DSIXReturnCode>000000</DSIXReturnCode>^M
    <CmdStatus>Approved</CmdStatus>^M
    <TextResponse>AP*</TextResponse>^M
    <UserTraceData></UserTraceData>^M
  </CmdResponse>^M
  <TranResponse>^M
    <MerchantID>595901</MerchantID>^M
    <AcctNo>5499990123456781</AcctNo>^M
    <ExpDate>0914</ExpDate>^M
    <CardType>M/C</CardType>^M
    <TranCode>PreAuthCapture</TranCode>^M
    <AuthCode>000077</AuthCode>^M
    <CaptureStatus>Captured</CaptureStatus>^M
    <RefNo>0008</RefNo>^M
    <InvoiceNo>1</InvoiceNo>^M
    <Amount>^M
      <Purchase>1.00</Purchase>^M
      <Authorize>1.00</Authorize>^M
    </Amount>^M
    <AcqRefData>KbMCC1051050524  c0   </AcqRefData>^M
    <ProcessData>|15|410100700000</ProcessData>^M
  </TranResponse>^M
</RStream>^M
</CreditTransactionResult></CreditTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end
end
