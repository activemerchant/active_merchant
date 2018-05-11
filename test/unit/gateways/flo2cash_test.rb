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
    end.check_request do |endpoint, data, headers|
      assert_match(%r{<Reference>boom</Reference>}, data)
    end.respond_with(successful_authorize_response, successful_capture_response)

    assert_success response

    assert_equal "P150100005006789", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal "Transaction Declined - Bank Error", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.responses.first.error_code
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
    end.respond_with(successful_authorize_response, successful_capture_response)

    assert_success response
    assert_equal "P150100005006789", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/P150100005006789/, data)
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
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessRefundResponse xmlns=\"http://www.flo2cash.co.nz/webservices/paymentwebservice\"><transactionresult><TransactionId>P150100005006770</TransactionId><OriginalTransactionId>P150100005006769</OriginalTransactionId><Type>REFUND</Type><AccountId>621366</AccountId><Status>SUCCESSFUL</Status><ReceiptNumber>25001352</ReceiptNumber><AuthCode>039241</AuthCode><Amount>100</Amount><Reference /><Particular /><Message>Transaction Successful</Message><BlockedReason /><CardStored>false</CardStored><CardToken /></transactionresult></ProcessRefundResponse></soap:Body></soap:Envelope>
    )
  end

  def empty_purchase_response
    %(
    )
  end
end
