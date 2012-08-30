require 'test_helper'

class MercuryTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    
    @gateway = MercuryPrepaidGateway.new(fixtures(:mercury))

    @amount = 500
    
    @prepaid_card = CreditCard.new(:number => "6050110000006083333")
    
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
  
  def test_successful_issue
    @gateway.expects(:ssl_post).returns(successful_issue_response)

    assert response = @gateway.issue(@amount, @prepaid_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    assert_equal "390913", response.authorization
    assert response.test?
  end
  
  def test_successful_void_issue
    @gateway.expects(:ssl_post).returns(successful_issue_response)

    assert response = @gateway.issue(@amount, @prepaid_card, @options)
    
    @gateway.expects(:ssl_post).returns(successful_void_issue_response)

    assert void_response = @gateway.void(@amount, response.authorization, @prepaid_card,
      @options.merge(:order_id => response.params['ref_no'], :invoice => response.params['invoice_no']))
    assert_instance_of Response, void_response
    assert_success void_response
    
    assert void_response.test?
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response_with_leftover)
    
    assert response = @gateway.purchase(@amount - 100, @prepaid_card, @options)
    assert_success response
    assert_equal "390924", response.authorization
    assert_equal "4.00", response.params["authorize"]
    assert_equal "1.00", response.params["balance"]
    
    @gateway.expects(:ssl_post).returns(successful_purchase_response_exact)
    assert response = @gateway.purchase(@amount, @prepaid_card, @options)
    assert_success response
    assert_equal "390926", response.authorization
    assert_equal "5.00", response.params["authorize"]
    assert_equal "0.00", response.params["balance"]
    
    @gateway.expects(:ssl_post).returns(successful_purchase_response_over)
    assert response = @gateway.purchase(@amount + 100, @prepaid_card, @options)
    assert_success response
    assert_equal "390929", response.authorization
    assert_equal "5.00", response.params["authorize"]
    assert_equal "0.00", response.params["balance"]
  end
  
  def test_successful_return
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    
    assert response = @gateway.credit(@amount, @prepaid_card, @options)
    assert_success response
    
    assert_equal "391041", response.authorization
    assert_equal "8.00", response.params["authorize"]
  end
  
  private
  
  def successful_issue_response
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><GiftTransactionResponse xmlns="http://www.mercurypay.com"><GiftTransactionResult>&lt;?xml version="1.0"?&gt;
&lt;RStream&gt;
	&lt;CmdResponse&gt;
		&lt;ResponseOrigin&gt;Processor&lt;/ResponseOrigin&gt;
		&lt;DSIXReturnCode&gt;000000&lt;/DSIXReturnCode&gt;
		&lt;CmdStatus&gt;Approved&lt;/CmdStatus&gt;
		&lt;TextResponse&gt;Approved&lt;/TextResponse&gt;
		&lt;UserTraceData&gt;&lt;/UserTraceData&gt;
	&lt;/CmdResponse&gt;
	&lt;TranResponse&gt;
		&lt;MerchantID&gt;595901&lt;/MerchantID&gt;
		&lt;TranType&gt;PrePaid&lt;/TranType&gt;
		&lt;TranCode&gt;Issue&lt;/TranCode&gt;
		&lt;InvoiceNo&gt;123&lt;/InvoiceNo&gt;
		&lt;OperatorID&gt;999&lt;/OperatorID&gt;
		&lt;AcctNo&gt;6050110000006083330&lt;/AcctNo&gt;
		&lt;RefNo&gt;390913&lt;/RefNo&gt;
		&lt;AuthCode&gt;390913&lt;/AuthCode&gt;
		&lt;Amount&gt;
			&lt;Authorize&gt;5.00&lt;/Authorize&gt;
			&lt;Purchase&gt;5.00&lt;/Purchase&gt;
			&lt;Balance&gt;5.00&lt;/Balance&gt;
		&lt;/Amount&gt;
	&lt;/TranResponse&gt;
&lt;/RStream&gt;
</GiftTransactionResult></GiftTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end
  
  def successful_void_issue_response
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><GiftTransactionResponse xmlns="http://www.mercurypay.com"><GiftTransactionResult>&lt;?xml version="1.0"?&gt;
&lt;RStream&gt;
	&lt;CmdResponse&gt;
		&lt;ResponseOrigin&gt;Processor&lt;/ResponseOrigin&gt;
		&lt;DSIXReturnCode&gt;000000&lt;/DSIXReturnCode&gt;
		&lt;CmdStatus&gt;Approved&lt;/CmdStatus&gt;
		&lt;TextResponse&gt;Voided&lt;/TextResponse&gt;
		&lt;UserTraceData&gt;&lt;/UserTraceData&gt;
	&lt;/CmdResponse&gt;
	&lt;TranResponse&gt;
		&lt;MerchantID&gt;595901&lt;/MerchantID&gt;
		&lt;TranType&gt;PrePaid&lt;/TranType&gt;
		&lt;TranCode&gt;VoidIssue&lt;/TranCode&gt;
		&lt;InvoiceNo&gt;123&lt;/InvoiceNo&gt;
		&lt;OperatorID&gt;999&lt;/OperatorID&gt;
		&lt;AcctNo&gt;6050110000006083330&lt;/AcctNo&gt;
		&lt;RefNo&gt;390914&lt;/RefNo&gt;
		&lt;Amount&gt;
			&lt;Authorize&gt;5.00&lt;/Authorize&gt;
			&lt;Purchase&gt;5.00&lt;/Purchase&gt;
			&lt;Balance&gt;0.00&lt;/Balance&gt;
		&lt;/Amount&gt;
	&lt;/TranResponse&gt;
&lt;/RStream&gt;
</GiftTransactionResult></GiftTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end
  
  def successful_purchase_response_with_leftover
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><GiftTransactionResponse xmlns="http://www.mercurypay.com"><GiftTransactionResult>&lt;?xml version="1.0"?&gt;
&lt;RStream&gt;
	&lt;CmdResponse&gt;
		&lt;ResponseOrigin&gt;Processor&lt;/ResponseOrigin&gt;
		&lt;DSIXReturnCode&gt;000000&lt;/DSIXReturnCode&gt;
		&lt;CmdStatus&gt;Approved&lt;/CmdStatus&gt;
		&lt;TextResponse&gt;Approved&lt;/TextResponse&gt;
		&lt;UserTraceData&gt;&lt;/UserTraceData&gt;
	&lt;/CmdResponse&gt;
	&lt;TranResponse&gt;
		&lt;MerchantID&gt;595901&lt;/MerchantID&gt;
		&lt;TranType&gt;PrePaid&lt;/TranType&gt;
		&lt;TranCode&gt;NoNSFSale&lt;/TranCode&gt;
		&lt;InvoiceNo&gt;123&lt;/InvoiceNo&gt;
		&lt;OperatorID&gt;999&lt;/OperatorID&gt;
		&lt;AcctNo&gt;6050110000006083332&lt;/AcctNo&gt;
		&lt;RefNo&gt;390924&lt;/RefNo&gt;
		&lt;AuthCode&gt;390924&lt;/AuthCode&gt;
		&lt;Amount&gt;
			&lt;Authorize&gt;4.00&lt;/Authorize&gt;
			&lt;Purchase&gt;4.00&lt;/Purchase&gt;
			&lt;Balance&gt;1.00&lt;/Balance&gt;
		&lt;/Amount&gt;
	&lt;/TranResponse&gt;
&lt;/RStream&gt;
</GiftTransactionResult></GiftTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end

  def successful_purchase_response_exact
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><GiftTransactionResponse xmlns="http://www.mercurypay.com"><GiftTransactionResult>&lt;?xml version="1.0"?&gt;
&lt;RStream&gt;
	&lt;CmdResponse&gt;
		&lt;ResponseOrigin&gt;Processor&lt;/ResponseOrigin&gt;
		&lt;DSIXReturnCode&gt;000000&lt;/DSIXReturnCode&gt;
		&lt;CmdStatus&gt;Approved&lt;/CmdStatus&gt;
		&lt;TextResponse&gt;Approved&lt;/TextResponse&gt;
		&lt;UserTraceData&gt;&lt;/UserTraceData&gt;
	&lt;/CmdResponse&gt;
	&lt;TranResponse&gt;
		&lt;MerchantID&gt;595901&lt;/MerchantID&gt;
		&lt;TranType&gt;PrePaid&lt;/TranType&gt;
		&lt;TranCode&gt;NoNSFSale&lt;/TranCode&gt;
		&lt;InvoiceNo&gt;123&lt;/InvoiceNo&gt;
		&lt;OperatorID&gt;999&lt;/OperatorID&gt;
		&lt;AcctNo&gt;6050110000006083333&lt;/AcctNo&gt;
		&lt;RefNo&gt;390926&lt;/RefNo&gt;
		&lt;AuthCode&gt;390926&lt;/AuthCode&gt;
		&lt;Amount&gt;
			&lt;Authorize&gt;5.00&lt;/Authorize&gt;
			&lt;Purchase&gt;5.00&lt;/Purchase&gt;
			&lt;Balance&gt;0.00&lt;/Balance&gt;
		&lt;/Amount&gt;
	&lt;/TranResponse&gt;
&lt;/RStream&gt;
</GiftTransactionResult></GiftTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end

  def successful_purchase_response_over
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><GiftTransactionResponse xmlns="http://www.mercurypay.com"><GiftTransactionResult>&lt;?xml version="1.0"?&gt;
&lt;RStream&gt;
	&lt;CmdResponse&gt;
		&lt;ResponseOrigin&gt;Processor&lt;/ResponseOrigin&gt;
		&lt;DSIXReturnCode&gt;000000&lt;/DSIXReturnCode&gt;
		&lt;CmdStatus&gt;Approved&lt;/CmdStatus&gt;
		&lt;TextResponse&gt;Approved&lt;/TextResponse&gt;
		&lt;UserTraceData&gt;&lt;/UserTraceData&gt;
	&lt;/CmdResponse&gt;
	&lt;TranResponse&gt;
		&lt;MerchantID&gt;595901&lt;/MerchantID&gt;
		&lt;TranType&gt;PrePaid&lt;/TranType&gt;
		&lt;TranCode&gt;NoNSFSale&lt;/TranCode&gt;
		&lt;InvoiceNo&gt;123&lt;/InvoiceNo&gt;
		&lt;OperatorID&gt;999&lt;/OperatorID&gt;
		&lt;AcctNo&gt;6050110000006083334&lt;/AcctNo&gt;
		&lt;RefNo&gt;390929&lt;/RefNo&gt;
		&lt;AuthCode&gt;390929&lt;/AuthCode&gt;
		&lt;Amount&gt;
			&lt;Authorize&gt;5.00&lt;/Authorize&gt;
			&lt;Purchase&gt;5.00&lt;/Purchase&gt;
			&lt;Balance&gt;0.00&lt;/Balance&gt;
		&lt;/Amount&gt;
	&lt;/TranResponse&gt;
&lt;/RStream&gt;
</GiftTransactionResult></GiftTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end
  
  def successful_credit_response
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><GiftTransactionResponse xmlns="http://www.mercurypay.com"><GiftTransactionResult>&lt;?xml version="1.0"?&gt;
&lt;RStream&gt;
	&lt;CmdResponse&gt;
		&lt;ResponseOrigin&gt;Processor&lt;/ResponseOrigin&gt;
		&lt;DSIXReturnCode&gt;000000&lt;/DSIXReturnCode&gt;
		&lt;CmdStatus&gt;Approved&lt;/CmdStatus&gt;
		&lt;TextResponse&gt;Approved&lt;/TextResponse&gt;
		&lt;UserTraceData&gt;&lt;/UserTraceData&gt;
	&lt;/CmdResponse&gt;
	&lt;TranResponse&gt;
		&lt;MerchantID&gt;595901&lt;/MerchantID&gt;
		&lt;TranType&gt;PrePaid&lt;/TranType&gt;
		&lt;TranCode&gt;Return&lt;/TranCode&gt;
		&lt;InvoiceNo&gt;123&lt;/InvoiceNo&gt;
		&lt;OperatorID&gt;999&lt;/OperatorID&gt;
		&lt;AcctNo&gt;6050110000006083335&lt;/AcctNo&gt;
		&lt;RefNo&gt;391041&lt;/RefNo&gt;
		&lt;AuthCode&gt;391041&lt;/AuthCode&gt;
		&lt;Amount&gt;
			&lt;Authorize&gt;8.00&lt;/Authorize&gt;
			&lt;Purchase&gt;8.00&lt;/Purchase&gt;
			&lt;Balance&gt;8.00&lt;/Balance&gt;
		&lt;/Amount&gt;
	&lt;/TranResponse&gt;
&lt;/RStream&gt;
</GiftTransactionResult></GiftTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end
  
end