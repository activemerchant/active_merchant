require 'test_helper'

class MercuryTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = MercuryGateway.new(fixtures(:mercury))

    @amount = 100
    @credit_card = CreditCard.new(
      :brand               => "master",
      :number              => "5499990123456781", # Use a generated CC from the paypal Sandbox
      :verification_value  => "123",
      :month               => 8,
      :year                => 2013,
      :first_name          => 'Fred',
      :last_name           => 'Brooks'
    )
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => '1',
      :invoice => '123',
      :merchant => '999',
      :billing_address => {
        :address1 => '4 Corporate Square',
        :zip => '30329'
      }
    }

  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '000011', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_voidsale
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)

    @gateway.expects(:ssl_post).returns(successful_voidsale_response)

    assert void_response = @gateway.void(@amount, response.authorization, @credit_card,
      @options.merge(:order_id => response.params['ref_no'], :invoice => response.params['invoice_no']))

    assert_instance_of Response, void_response
    assert_success void_response
    assert void_response.test?
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

  def successful_voidsale_response
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
end
