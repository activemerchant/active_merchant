require 'test_helper'

class Flo2cashSimpleTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = Flo2cashSimpleGateway.new(
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
    end.check_request do |endpoint, data, headers|
      assert_match(%r{<Reference>boom</Reference>}, data)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal "P150200005007600", response.authorization
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

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "P150200005007600", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/P150200005007600/, data)
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
    transcript =  @gateway.scrub(successful_purchase_response)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  private

  def successful_purchase_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessPurchaseResponse xmlns=\"http://www.flo2cash.co.nz/webservices/paymentwebservice\"><transactionresult><TransactionId>P150200005007600</TransactionId><OriginalTransactionId /><Type>PURCHASE</Type><AccountId>621366</AccountId><Status>SUCCESSFUL</Status><ReceiptNumber>25002185</ReceiptNumber><AuthCode>088682</AuthCode><Amount>1.00</Amount><Reference /><Particular>Store Purchase</Particular><Message>Transaction Successful</Message><BlockedReason /><CardStored>false</CardStored><CardToken /></transactionresult></ProcessPurchaseResponse></soap:Body></soap:Envelope>
    )
  end

  def failed_purchase_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessPurchaseResponse xmlns=\"http://www.flo2cash.co.nz/webservices/paymentwebservice\"><transactionresult><TransactionId>P150200005007599</TransactionId><OriginalTransactionId /><Type>PURCHASE</Type><AccountId>621366</AccountId><Status>FAILED</Status><ReceiptNumber>0</ReceiptNumber><AuthCode /><Amount>1.00</Amount><Reference /><Particular>Store Purchase</Particular><Message>Transaction Declined - Bank Error</Message><BlockedReason /><CardStored>false</CardStored><CardToken /></transactionresult></ProcessPurchaseResponse></soap:Body></soap:Envelope>
    )
  end

  def successful_refund_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessRefundResponse xmlns=\"http://www.flo2cash.co.nz/webservices/paymentwebservice\"><transactionresult><TransactionId>P150200005007602</TransactionId><OriginalTransactionId>P150200005007601</OriginalTransactionId><Type>REFUND</Type><AccountId>621366</AccountId><Status>SUCCESSFUL</Status><ReceiptNumber>25002187</ReceiptNumber><AuthCode>039335</AuthCode><Amount>1.00</Amount><Reference /><Particular /><Message>Transaction Successful</Message><BlockedReason /><CardStored>false</CardStored><CardToken /></transactionresult></ProcessRefundResponse></soap:Body></soap:Envelope>
    )
  end

  def empty_purchase_response
    %(
    )
  end
end
