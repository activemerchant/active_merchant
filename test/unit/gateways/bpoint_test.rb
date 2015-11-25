require 'test_helper'

class BpointTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = BpointGateway.new(
      username: '',
      password: '',
      merchant_number: ''
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)
    response = @gateway.store(@credit_card)
    assert_success response
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)
    response = @gateway.store(@credit_card)
    assert_failure response
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '218990188', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Declined", response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '219388558', response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    response = @gateway.capture(@amount, '')
    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    response = @gateway.capture(@amount, '')
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.capture(@amount, '')
    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    response = @gateway.refund(@amount, '')
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    response = @gateway.void(@amount, '')
    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    response = @gateway.void(@amount, '')
    assert_failure response
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_verify_response)
    response = @gateway.verify(@credit_card)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)
    response = @gateway.verify(@credit_card)
    assert_failure response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_passing_biller_code
    stub_comms do
      @gateway.authorize(@amount, @credit_card, { biller_code: '1234' })
    end.check_request do |endpoint, data, headers|
      assert_match(%r(<BillerCode>1234</BillerCode>)m, data)
    end.respond_with(successful_authorize_response)
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      <- "POST /evolve/service_1_4_4.asmx HTTP/1.1\r\nContent-Type: application/soap+xml; charset=utf-8\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: www.bpoint.com.au\r\nContent-Length: 843\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<soap12:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap12=\"http://www.w3.org/2003/05/soap-envelope\">\n  <soap12:Body>\n    <ProcessPayment xmlns=\"urn:Eve_1_4_4\">\n      <username>waysact</username>\n      <password>O5dIyDv148</password>\n      <merchantNumber>DEMONSTRATION731</merchantNumber>\n      <txnReq>\n        <PaymentType>PAYMENT</PaymentType>\n        <TxnType>WEB_SHOP</TxnType>\n        <BillerCode/>\n        <MerchantReference/>\n        <CRN1/>\n        <CRN2/>\n        <CRN3/>\n        <Amount>100</Amount>\n        <CardNumber>4987654321098769</CardNumber>\n        <ExpiryDate>9900</ExpiryDate>\n        <CVC>123</CVC>\n        <OriginalTransactionNumber/>\n      </txnReq>\n    </ProcessPayment>\n  </soap12:Body>\n</soap12:Envelope>\n"
      -> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessPaymentResponse xmlns=\"urn:Eve_1_4_4\"><ProcessPaymentResult><ResponseCode>0</ResponseCode><AcquirerResponseCode>00</AcquirerResponseCode><AuthorisationResult>Approved</AuthorisationResult><TransactionNumber>219617445</TransactionNumber><ReceiptNumber>53559987445</ReceiptNumber><AuthoriseId>122025580862</AuthoriseId><SettlementDate>20150513</SettlementDate><MaskedCardNumber>498765...769</MaskedCardNumber><CardType>VC</CardType></ProcessPaymentResult><response><ResponseCode>SUCCESS</ResponseCode></response></ProcessPaymentResponse></soap:Body></soap:Envelope>"
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      <- "POST /evolve/service_1_4_4.asmx HTTP/1.1\r\nContent-Type: application/soap+xml; charset=utf-8\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: www.bpoint.com.au\r\nContent-Length: 843\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<soap12:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap12=\"http://www.w3.org/2003/05/soap-envelope\">\n  <soap12:Body>\n    <ProcessPayment xmlns=\"urn:Eve_1_4_4\">\n      <username>waysact</username>\n      <password>[FILTERED]</password>\n      <merchantNumber>DEMONSTRATION731</merchantNumber>\n      <txnReq>\n        <PaymentType>PAYMENT</PaymentType>\n        <TxnType>WEB_SHOP</TxnType>\n        <BillerCode/>\n        <MerchantReference/>\n        <CRN1/>\n        <CRN2/>\n        <CRN3/>\n        <Amount>100</Amount>\n        <CardNumber>[FILTERED]</CardNumber>\n        <ExpiryDate>9900</ExpiryDate>\n        <CVC>[FILTERED]</CVC>\n        <OriginalTransactionNumber/>\n      </txnReq>\n    </ProcessPayment>\n  </soap12:Body>\n</soap12:Envelope>\n"
      -> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessPaymentResponse xmlns=\"urn:Eve_1_4_4\"><ProcessPaymentResult><ResponseCode>0</ResponseCode><AcquirerResponseCode>00</AcquirerResponseCode><AuthorisationResult>Approved</AuthorisationResult><TransactionNumber>219617445</TransactionNumber><ReceiptNumber>53559987445</ReceiptNumber><AuthoriseId>122025580862</AuthoriseId><SettlementDate>20150513</SettlementDate><MaskedCardNumber>498765...769</MaskedCardNumber><CardType>VC</CardType></ProcessPaymentResult><response><ResponseCode>SUCCESS</ResponseCode></response></ProcessPaymentResponse></soap:Body></soap:Envelope>"
    POST_SCRUBBED
  end

  def successful_purchase_response
    %(
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <soap:Body>
        <ProcessPaymentResponse xmlns="urn:Eve_1_4_4">
          <ProcessPaymentResult>
            <ResponseCode>0</ResponseCode>
            <AcquirerResponseCode>00</AcquirerResponseCode>
            <AuthorisationResult>Approved</AuthorisationResult>
            <TransactionNumber>218990188</TransactionNumber>
            <ReceiptNumber>53440560188</ReceiptNumber>
            <AuthoriseId>081017039863</AuthoriseId>
            <SettlementDate>20150509</SettlementDate>
            <MaskedCardNumber>498765...769</MaskedCardNumber>
            <CardType>VC</CardType>
          </ProcessPaymentResult>
          <response>
            <ResponseCode>SUCCESS</ResponseCode>
          </response>
        </ProcessPaymentResponse>
      </soap:Body>
    </soap:Envelope>
    )
  end

  def failed_purchase_response
    %(
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <soap:Body>
        <ProcessPaymentResponse xmlns="urn:Eve_1_4_4">
          <ProcessPaymentResult>
            <ResponseCode>2</ResponseCode>
            <AcquirerResponseCode>01</AcquirerResponseCode>
            <AuthorisationResult>Declined</AuthorisationResult>
            <TransactionNumber>219013928</TransactionNumber>
            <ReceiptNumber>53452203928</ReceiptNumber>
            <AuthoriseId />
            <SettlementDate>20150509</SettlementDate>
            <MaskedCardNumber>498765...769</MaskedCardNumber>
            <CardType>VC</CardType>
          </ProcessPaymentResult>
          <response>
            <ResponseCode>SUCCESS</ResponseCode>
          </response>
        </ProcessPaymentResponse>
      </soap:Body>
    </soap:Envelope>
    )
  end

  def successful_authorize_response
    %(
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <soap:Body>
        <ProcessPaymentResponse xmlns="urn:Eve_1_4_4">
          <ProcessPaymentResult>
            <ResponseCode>0</ResponseCode>
            <AcquirerResponseCode>00</AcquirerResponseCode>
            <AuthorisationResult>Approved</AuthorisationResult>
            <TransactionNumber>219388558</TransactionNumber>
            <ReceiptNumber>53530098558</ReceiptNumber>
            <AuthoriseId>111751554356</AuthoriseId>
            <SettlementDate>20150512</SettlementDate>
            <MaskedCardNumber>498765...769</MaskedCardNumber>
            <CardType>VC</CardType>
          </ProcessPaymentResult>
          <response>
            <ResponseCode>SUCCESS</ResponseCode>
          </response>
        </ProcessPaymentResponse>
      </soap:Body>
    </soap:Envelope>
    )
  end
  alias_method :successful_verify_response, :successful_authorize_response

  def failed_authorize_response
    %(
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <soap:Body>
        <ProcessPaymentResponse xmlns="urn:Eve_1_4_4">
          <ProcessPaymentResult>
            <ResponseCode>2</ResponseCode>
            <AcquirerResponseCode>01</AcquirerResponseCode>
            <AuthorisationResult>Declined</AuthorisationResult>
            <TransactionNumber>219389176</TransactionNumber>
            <ReceiptNumber>53530629176</ReceiptNumber>
            <AuthoriseId />
            <SettlementDate>20150512</SettlementDate>
            <MaskedCardNumber>498765...769</MaskedCardNumber>
            <CardType>VC</CardType>
          </ProcessPaymentResult>
          <response>
            <ResponseCode>SUCCESS</ResponseCode>
          </response>
        </ProcessPaymentResponse>
      </soap:Body>
    </soap:Envelope>
    )
  end
  alias_method :failed_verify_response, :failed_authorize_response

  def successful_capture_response
    %(
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <soap:Body>
        <ProcessPaymentResponse xmlns="urn:Eve_1_4_4">
          <ProcessPaymentResult>
            <ResponseCode>0</ResponseCode>
            <AcquirerResponseCode>00</AcquirerResponseCode>
            <AuthorisationResult>Approved</AuthorisationResult>
            <TransactionNumber>219389381</TransactionNumber>
            <ReceiptNumber>53530769381</ReceiptNumber>
            <AuthoriseId>111827122671</AuthoriseId>
            <SettlementDate>20150512</SettlementDate>
            <MaskedCardNumber>498765...769</MaskedCardNumber>
            <CardType>VC</CardType>
          </ProcessPaymentResult>
          <response>
            <ResponseCode>SUCCESS</ResponseCode>
          </response>
        </ProcessPaymentResponse>
      </soap:Body>
    </soap:Envelope>
    )
  end

  def failed_capture_response
    %(
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <soap:Body>
        <ProcessPaymentResponse xmlns="urn:Eve_1_4_4">
          <ProcessPaymentResult>
            <ResponseCode>PT_R1</ResponseCode>
            <AuthorisationResult>Original transaction not found</AuthorisationResult>
            <TransactionNumber>219389566</TransactionNumber>
            <ReceiptNumber>53530899566</ReceiptNumber>
            <CardType />
          </ProcessPaymentResult>
          <response>
            <ResponseCode>SUCCESS</ResponseCode>
          </response>
        </ProcessPaymentResponse>
      </soap:Body>
    </soap:Envelope>
    )
  end

  def successful_refund_response
    %(
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <soap:Body>
        <ProcessPaymentResponse xmlns="urn:Eve_1_4_4">
          <ProcessPaymentResult>
            <ResponseCode>0</ResponseCode>
            <AcquirerResponseCode>00</AcquirerResponseCode>
            <AuthorisationResult>Approved</AuthorisationResult>
            <TransactionNumber>219391527</TransactionNumber>
            <ReceiptNumber>53532101527</ReceiptNumber>
            <AuthoriseId>111939009260</AuthoriseId>
            <SettlementDate>20150512</SettlementDate>
            <MaskedCardNumber>498765...769</MaskedCardNumber>
            <CardType>VC</CardType>
          </ProcessPaymentResult>
          <response>
            <ResponseCode>SUCCESS</ResponseCode>
          </response>
        </ProcessPaymentResponse>
      </soap:Body>
    </soap:Envelope>
    )
  end

  def failed_refund_response
    %(
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <soap:Body>
        <ProcessPaymentResponse xmlns="urn:Eve_1_4_4">
          <ProcessPaymentResult>
            <ResponseCode>PT_R1</ResponseCode>
            <AuthorisationResult>Original transaction not found</AuthorisationResult>
            <TransactionNumber>219395831</TransactionNumber>
            <ReceiptNumber>53533405831</ReceiptNumber>
            <CardType />
          </ProcessPaymentResult>
          <response>
            <ResponseCode>SUCCESS</ResponseCode>
          </response>
        </ProcessPaymentResponse>
      </soap:Body>
    </soap:Envelope>
    )
  end

  def successful_void_response
    %(
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <soap:Body>
        <ProcessPaymentResponse xmlns="urn:Eve_1_4_4">
          <ProcessPaymentResult>
            <ResponseCode>0</ResponseCode>
            <AcquirerResponseCode>00</AcquirerResponseCode>
            <AuthorisationResult>Approved</AuthorisationResult>
            <TransactionNumber>219397643</TransactionNumber>
            <ReceiptNumber>53533757643</ReceiptNumber>
            <AuthoriseId>112107050623</AuthoriseId>
            <SettlementDate>20150512</SettlementDate>
            <MaskedCardNumber>498765...769</MaskedCardNumber>
            <CardType>VC</CardType>
          </ProcessPaymentResult>
          <response>
            <ResponseCode>SUCCESS</ResponseCode>
          </response>
        </ProcessPaymentResponse>
      </soap:Body>
    </soap:Envelope>
    )
  end

  def failed_void_response
    %(
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <soap:Body>
        <ProcessPaymentResponse xmlns="urn:Eve_1_4_4">
          <ProcessPaymentResult>
            <ResponseCode>PT_R1</ResponseCode>
            <AuthorisationResult>Original transaction not found</AuthorisationResult>
            <TransactionNumber>219397820</TransactionNumber>
            <ReceiptNumber>53533887820</ReceiptNumber>
            <CardType />
          </ProcessPaymentResult>
          <response>
            <ResponseCode>SUCCESS</ResponseCode>
          </response>
        </ProcessPaymentResponse>
      </soap:Body>
    </soap:Envelope>
    )
  end

  def successful_store_response
   %(
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <soap:Body>
        <AddTokenResponse xmlns="urn:Eve_1_4_4">
          <AddTokenResult>
            <Token>5999992142370790</Token>
            <MaskedCardNumber>498765...769</MaskedCardNumber>
            <CardType>VC</CardType>
          </AddTokenResult>
          <response>
            <ResponseCode>SUCCESS</ResponseCode>
          </response>
        </AddTokenResponse>
      </soap:Body>
    </soap:Envelope>
   )
  end

  def failed_store_response
    %(
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <soap:Body>
        <AddTokenResponse xmlns="urn:Eve_1_4_4">
          <AddTokenResult />
          <response>
            <ResponseCode>ERROR</ResponseCode>
            <ResponseMessage>invalid card number: invalid length</ResponseMessage>
          </response>
        </AddTokenResponse>
      </soap:Body>
    </soap:Envelope>
    )
  end
end
