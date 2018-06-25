require 'test_helper'

class Flo2cashTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = Flo2cashGateway.new(
      :username => 'username',
      :password => 'password',
      :account_id => 'account_id'
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, order_id: "boom")
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal "P1610W0005138048", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal "Transaction Declined - Bank Error", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
    assert response.test?
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "P150100005006789", response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/P150100005006789/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal "Transaction Declined - Bank Error", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
    assert response.test?
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "P1610W0005138048", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/P1610W0005138048/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_empty_response_fails
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(empty_purchase_response)

    assert_failure response
    assert_equal "Unable to read error message", response.message
  end

  def test_transcript_scrubbing
    transcript =  @gateway.scrub(successful_authorize_response)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(successful_store_response)

    assert_success response
    assert_equal '25223239884', response.authorization
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(failed_store_response)

    assert_failure response
    assert_equal 'Card number must be a valid credit card number', response.message
  end

  def test_successful_unstore
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(successful_store_response)

    assert_success response
    assert_equal '25223239884', response.authorization

    unstore = stub_comms do
      @gateway.unstore(response.authorization)
    end.respond_with(successful_unstore_response)

    assert_success unstore
  end

  def test_failed_unstore
    response = stub_comms do
      @gateway.unstore('12345')
    end.respond_with(failed_unstore_response)

    assert_failure response
    assert_equal 'Card token not found', response.message
  end

  def test_successful_purchase_with_token
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(successful_store_response)

    assert_success response
    assert_equal '25223239884', response.authorization

    purchase = stub_comms do
      @gateway.purchase(@amount, response.authorization)
    end.respond_with(successful_purchase_with_token_response)

    assert_success purchase
    assert_equal 'P1610W0005138055', purchase.authorization
  end

  def test_failed_purchase_with_token
    purchase = stub_comms do
      @gateway.purchase(@amount, '12345')
    end.respond_with(failed_purchased_with_token_response)

    assert_failure purchase
    assert_equal 'Card token not found', purchase.message
  end

  private

  def successful_authorize_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessAuthoriseResponse xmlns=\"http://www.flo2cash.co.nz/webservices/paymentwebservice\"><transactionresult><TransactionId>P150100005006789</TransactionId><OriginalTransactionId /><Type>AUTHORISATION</Type><AccountId>621409</AccountId><Status>SUCCESSFUL</Status><ReceiptNumber>25001371</ReceiptNumber><AuthCode>017265</AuthCode><Amount>100</Amount><Reference /><Particular>Store Purchase</Particular><Message>Transaction Successful</Message><BlockedReason /><CardStored>false</CardStored><CardToken /></transactionresult></ProcessAuthoriseResponse></soap:Body></soap:Envelope>
    )
  end

  def failed_authorize_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessAuthoriseResponse xmlns=\"http://www.flo2cash.co.nz/webservices/paymentwebservice\"><transactionresult><TransactionId>P150100005006794</TransactionId><OriginalTransactionId /><Type>AUTHORISATION</Type><AccountId>621409</AccountId><Status>FAILED</Status><ReceiptNumber>0</ReceiptNumber><AuthCode /><Amount>100</Amount><Reference /><Particular>Store Purchase</Particular><Message>Transaction Declined - Bank Error</Message><BlockedReason /><CardStored>false</CardStored><CardToken /></transactionresult></ProcessAuthoriseResponse></soap:Body></soap:Envelope>
    )
  end

  def successful_capture_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessCaptureResponse xmlns=\"http://www.flo2cash.co.nz/webservices/paymentwebservice\"><transactionresult><TransactionId>P150100005006790</TransactionId><OriginalTransactionId>P150100005006789</OriginalTransactionId><Type>CAPTURE</Type><AccountId>621409</AccountId><Status>SUCCESSFUL</Status><ReceiptNumber>25001372</ReceiptNumber><AuthCode>007524</AuthCode><Amount>100</Amount><Reference /><Particular /><Message>Transaction Successful</Message><BlockedReason /><CardStored>false</CardStored><CardToken /></transactionresult></ProcessCaptureResponse></soap:Body></soap:Envelope>
    )
  end

  def successful_refund_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessRefundResponse xmlns=\"http://www.flo2cash.co.nz/webservices/paymentwebservice\"><transactionresult><TransactionId>P1610W0005138053</TransactionId><OriginalTransactionId>P1610W0005138052</OriginalTransactionId><Type>REFUND</Type><AccountId>621462</AccountId><Status>SUCCESSFUL</Status><ReceiptNumber>25162085</ReceiptNumber><AuthCode>425730</AuthCode><Amount>1.00</Amount><Reference /><Particular /><Message>Transaction Successful</Message><BlockedReason /><CardStored>false</CardStored><CardToken /></transactionresult></ProcessRefundResponse></soap:Body></soap:Envelope>
    )
  end

  def empty_purchase_response
    %(
    )
  end

  def successful_purchase_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessPurchaseResponse xmlns=\"http://www.flo2cash.co.nz/webservices/paymentwebservice\"><transactionresult><TransactionId>P1610W0005138048</TransactionId><OriginalTransactionId /><Type>PURCHASE</Type><AccountId>621462</AccountId><Status>SUCCESSFUL</Status><ReceiptNumber>25162080</ReceiptNumber><AuthCode>915933</AuthCode><Amount>1.00</Amount><Reference>4dad48e7ca579b597963bab9635761c0</Reference><Particular>Store Purchase</Particular><Message>Transaction Successful</Message><BlockedReason /><CardStored>false</CardStored><CardToken /></transactionresult></ProcessPurchaseResponse></soap:Body></soap:Envelope>
    )
  end

  def failed_purchase_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessPurchaseResponse xmlns=\"http://www.flo2cash.co.nz/webservices/paymentwebservice\"><transactionresult><TransactionId>P1610W0005138051</TransactionId><OriginalTransactionId /><Type>PURCHASE</Type><AccountId>621462</AccountId><Status>FAILED</Status><ReceiptNumber>0</ReceiptNumber><AuthCode /><Amount>1.10</Amount><Reference>591f9a1e8fbe4fb8ff82ea628e7ae3ea</Reference><Particular>Store Purchase</Particular><Message>Transaction Declined - Bank Error</Message><BlockedReason /><CardStored>false</CardStored><CardToken /></transactionresult></ProcessPurchaseResponse></soap:Body></soap:Envelope>
    )
  end

  def successful_store_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><AddCardResponse xmlns=\"http://www.flo2cash.co.nz/webservices/creditcardwebservice\"><AddCardResult>25223239884</AddCardResult></AddCardResponse></soap:Body></soap:Envelope>
    )
  end

  def failed_store_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><soap:Fault><soap:Code><soap:Value>soap:Sender</soap:Value></soap:Code><soap:Reason><soap:Text xml:lang=\"en\">Card number must be a valid credit card number</soap:Text></soap:Reason><soap:Node>AddCard</soap:Node><detail><error><errortype>Parameter</errortype><errornumber>1002</errornumber><errormessage>Card number must be a valid credit card number</errormessage></error></detail></soap:Fault></soap:Body></soap:Envelope>
    )
  end

  def successful_unstore_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><RemoveCardResponse xmlns=\"http://www.flo2cash.co.nz/webservices/creditcardwebservice\"><RemoveCardResult>true</RemoveCardResult></RemoveCardResponse></soap:Body></soap:Envelope>
    )
  end

  def failed_unstore_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><soap:Fault><soap:Code><soap:Value>soap:Sender</soap:Value></soap:Code><soap:Reason><soap:Text xml:lang=\"en\">Card token not found</soap:Text></soap:Reason><soap:Node>RemoveCard</soap:Node><detail><error><errortype>Parameter</errortype><errornumber>2000</errornumber><errormessage>Card token not found</errormessage></error></detail></soap:Fault></soap:Body></soap:Envelope>
    )
  end

  def successful_purchase_with_token_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessPurchaseByTokenResponse xmlns=\"http://www.flo2cash.co.nz/webservices/paymentwebservice\"><transactionresult><TransactionId>P1610W0005138055</TransactionId><OriginalTransactionId /><Type>PURCHASE</Type><AccountId>621462</AccountId><Status>SUCCESSFUL</Status><ReceiptNumber>25162087</ReceiptNumber><AuthCode>943672</AuthCode><Amount>1.00</Amount><Reference>4a669b0e31206b57b7088e4f9433025a</Reference><Particular>Store Purchase</Particular><Message>Transaction Successful</Message><BlockedReason /><CardStored>false</CardStored><CardToken /></transactionresult></ProcessPurchaseByTokenResponse></soap:Body></soap:Envelope>
    )
  end

  def failed_purchased_with_token_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><soap:Fault><soap:Code><soap:Value>soap:Sender</soap:Value></soap:Code><soap:Reason><soap:Text xml:lang=\"en\">Card token not found</soap:Text></soap:Reason><soap:Node>ProcessTokenPayment</soap:Node><detail><error><errortype>Parameter</errortype><errornumber>2000</errornumber><errormessage>Card token not found</errormessage></error></detail></soap:Fault></soap:Body></soap:Envelope>
    )
  end
end
