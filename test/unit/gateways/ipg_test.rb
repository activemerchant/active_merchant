require 'test_helper'

class IpgTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = IpgGateway.new(fixtures(:ipg))
    @credit_card = credit_card
    @amount = 100

    @options = {
      currency: 'ARS'
    }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      doc = REXML::Document.new(data)
      assert_match('sale', REXML::XPath.first(doc, '//v1:CreditCardTxType//v1:Type').text)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_stored_credentials
    stored_credential = {
      initial_transaction: true,
      reason_type: '',
      initiator: 'merchant',
      network_transaction_id: nil
    }

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({ stored_credential: stored_credential, order_id: '123' }))
    end.check_request do |_endpoint, data, _headers|
      doc = REXML::Document.new(data)
      assert_match('FIRST', REXML::XPath.first(doc, '//v1:recurringType').text)
    end.respond_with(successful_purchase_response)

    stored_credential = {
      initial_transaction: false,
      reason_type: '',
      initiator: 'merchant',
      network_transaction_id: response.params['IpgTransactionId']
    }

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({ stored_credential: stored_credential, order_id: '123' }))
    end.check_request do |_endpoint, data, _headers|
      doc = REXML::Document.new(data)
      assert_match('REPEAT', REXML::XPath.first(doc, '//v1:recurringType').text)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'DECLINED', response.message
  end

  def test_successful_authorize
    order_id = generate_unique_id
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge!({ order_id: order_id }))
    end.check_request do |_endpoint, data, _headers|
      doc = REXML::Document.new(data)
      assert_match('preAuth', REXML::XPath.first(doc, '//v1:CreditCardTxType//v1:Type').text)
      assert_match(order_id, REXML::XPath.first(doc, '//v1:TransactionDetails//v1:OrderId').text)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options.merge!({ order_id: 'ORD03' }))
    assert_failure response
    assert_equal 'FAILED', response.message
  end

  def test_successful_capture
    order_id = generate_unique_id
    response = stub_comms do
      @gateway.capture(@amount, { order_id: order_id }, @options)
    end.check_request do |_endpoint, data, _headers|
      doc = REXML::Document.new(data)
      assert_match('postAuth', REXML::XPath.first(doc, '//v1:CreditCardTxType//v1:Type').text)
      assert_match(order_id, REXML::XPath.first(doc, '//v1:TransactionDetails//v1:OrderId').text)
    end.respond_with(successful_capture_response)

    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, { order_id: '123' }, @options)
    assert_failure response
    assert_equal 'FAILED', response.message
  end

  def test_successful_refund
    order_id = generate_unique_id
    response = stub_comms do
      @gateway.refund(@amount, { order_id: order_id }, @options)
    end.check_request do |_endpoint, data, _headers|
      doc = REXML::Document.new(data)
      assert_match('return', REXML::XPath.first(doc, '//v1:CreditCardTxType//v1:Type').text)
      assert_match(order_id, REXML::XPath.first(doc, '//v1:TransactionDetails//v1:OrderId').text)
    end.respond_with(successful_refund_response)

    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, { order_id: '123' }, @options)
    assert_failure response
    assert_equal 'FAILED', response.message
  end

  def test_successful_void
    order_id = generate_unique_id
    response = stub_comms do
      @gateway.void({ order_id: order_id }, @options)
    end.check_request do |_endpoint, data, _headers|
      doc = REXML::Document.new(data)
      assert_match('void', REXML::XPath.first(doc, '//v1:CreditCardTxType//v1:Type').text)
      assert_match(order_id, REXML::XPath.first(doc, '//v1:TransactionDetails//v1:OrderId').text)
    end.respond_with(successful_void_response)

    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void({}, @options)
    assert_failure response
    assert_equal 'FAILED', response.message
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
  end

  def test_successful_store
    payment_token = generate_unique_id
    response = stub_comms do
      @gateway.store(@credit_card, @options.merge!({ hosted_data_id: payment_token }))
    end.check_request do |_endpoint, data, _headers|
      doc = REXML::Document.new(data)
      assert_match(payment_token, REXML::XPath.first(doc, '//ns2:HostedDataID').text)
    end.respond_with(successful_store_response)

    assert_success response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def successful_purchase_response
    <<~RESPONSE
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
      <SOAP-ENV:Header/>
      <SOAP-ENV:Body>
          <ipgapi:IPGApiOrderResponse xmlns:a1="http://ipg-online.com/ipgapi/schemas/a1" xmlns:ipgapi="http://ipg-online.com/ipgapi/schemas/ipgapi" xmlns:v1="http://ipg-online.com/ipgapi/schemas/v1">
              <ipgapi:ApprovalCode>Y:019349:4578600880:PPXX:0193497665</ipgapi:ApprovalCode>
              <ipgapi:AVSResponse>PPX</ipgapi:AVSResponse>
              <ipgapi:Brand>MASTERCARD</ipgapi:Brand>
              <ipgapi:Country>ARG</ipgapi:Country>
              <ipgapi:CommercialServiceProvider>FDCS</ipgapi:CommercialServiceProvider>
              <ipgapi:ExternalMerchantID>5921102002</ipgapi:ExternalMerchantID>
              <ipgapi:OrderId>A-5e3d7dc2-0454-4d60-aae8-7edf35eb28c7</ipgapi:OrderId>
              <ipgapi:IpgTransactionId>84578600880</ipgapi:IpgTransactionId>
              <ipgapi:PaymentType>CREDITCARD</ipgapi:PaymentType>
              <ipgapi:ProcessorApprovalCode>019349</ipgapi:ProcessorApprovalCode>
              <ipgapi:ProcessorReceiptNumber>7665</ipgapi:ProcessorReceiptNumber>
              <ipgapi:ProcessorBatchNumber>090</ipgapi:ProcessorBatchNumber>
              <ipgapi:ProcessorEndpointID>TXSP ARGENTINA VIA CAFEX VISA</ipgapi:ProcessorEndpointID>
              <ipgapi:ProcessorCCVResponse>X</ipgapi:ProcessorCCVResponse>
              <ipgapi:ProcessorReferenceNumber>019349019349</ipgapi:ProcessorReferenceNumber>
              <ipgapi:ProcessorResponseCode>00</ipgapi:ProcessorResponseCode>
              <ipgapi:ProcessorResponseMessage>Function performed error-free</ipgapi:ProcessorResponseMessage>
              <ipgapi:ProcessorTraceNumber>019349</ipgapi:ProcessorTraceNumber>
              <ipgapi:TDate>1635149370</ipgapi:TDate>
              <ipgapi:TDateFormatted>2021.10.25 10:09:30 (CEST)</ipgapi:TDateFormatted>
              <ipgapi:TerminalID>98000000</ipgapi:TerminalID>
              <ipgapi:TransactionResult>APPROVED</ipgapi:TransactionResult>
              <ipgapi:TransactionTime>1635149370</ipgapi:TransactionTime>
          </ipgapi:IPGApiOrderResponse>
      </SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    RESPONSE
  end

  def failed_purchase_response
    <<~RESPONSE
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
      <SOAP-ENV:Header/>
      <SOAP-ENV:Body>
          <SOAP-ENV:Fault>
              <faultcode>SOAP-ENV:Client</faultcode>
              <faultstring xml:lang="en">ProcessingException</faultstring>
              <detail>
                  <ipgapi:IPGApiOrderResponse xmlns:a1="http://ipg-online.com/ipgapi/schemas/a1" xmlns:ipgapi="http://ipg-online.com/ipgapi/schemas/ipgapi" xmlns:v1="http://ipg-online.com/ipgapi/schemas/v1">
                      <ipgapi:ApprovalCode>N:05:Do not honour</ipgapi:ApprovalCode>
                      <ipgapi:AVSResponse>PPX</ipgapi:AVSResponse>
                      <ipgapi:Brand>VISA</ipgapi:Brand>
                      <ipgapi:CommercialServiceProvider>FDCS</ipgapi:CommercialServiceProvider>
                      <ipgapi:ErrorMessage>SGS-050005: Do not honour</ipgapi:ErrorMessage>
                      <ipgapi:ExternalMerchantID>5921102002</ipgapi:ExternalMerchantID>
                      <ipgapi:OrderId>A-5c70b8fc-43d8-40f4-93de-46590dbf6d01</ipgapi:OrderId>
                      <ipgapi:IpgTransactionId>84578606308</ipgapi:IpgTransactionId>
                      <ipgapi:PaymentType>CREDITCARD</ipgapi:PaymentType>
                      <ipgapi:ProcessorReceiptNumber>7668</ipgapi:ProcessorReceiptNumber>
                      <ipgapi:ProcessorBatchNumber>090</ipgapi:ProcessorBatchNumber>
                      <ipgapi:ProcessorEndpointID>TXSP ARGENTINA VIA CAFEX VISA</ipgapi:ProcessorEndpointID>
                      <ipgapi:ProcessorCCVResponse>X</ipgapi:ProcessorCCVResponse>
                      <ipgapi:ProcessorResponseCode>05</ipgapi:ProcessorResponseCode>
                      <ipgapi:ProcessorResponseMessage>Do not honour</ipgapi:ProcessorResponseMessage>
                      <ipgapi:ProcessorTraceNumber>034209</ipgapi:ProcessorTraceNumber>
                      <ipgapi:TDate>1635152461</ipgapi:TDate>
                      <ipgapi:TDateFormatted>2021.10.25 11:01:01 (CEST)</ipgapi:TDateFormatted>
                      <ipgapi:TerminalID>98000000</ipgapi:TerminalID>
                      <ipgapi:TransactionResult>DECLINED</ipgapi:TransactionResult>
                      <ipgapi:TransactionTime>1635152461</ipgapi:TransactionTime>
                  </ipgapi:IPGApiOrderResponse>
              </detail>
          </SOAP-ENV:Fault>
      </SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    RESPONSE
  end

  def successful_authorize_response
    <<~RESPONSE
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
      <SOAP-ENV:Header/>
      <SOAP-ENV:Body>
          <ipgapi:IPGApiOrderResponse xmlns:a1="http://ipg-online.com/ipgapi/schemas/a1" xmlns:ipgapi="http://ipg-online.com/ipgapi/schemas/ipgapi" xmlns:v1="http://ipg-online.com/ipgapi/schemas/v1">
              <ipgapi:ApprovalCode>Y:014593:4578595466:PPXX:0145937641</ipgapi:ApprovalCode>
              <ipgapi:AVSResponse>PPX</ipgapi:AVSResponse>
              <ipgapi:Brand>MASTERCARD</ipgapi:Brand>
              <ipgapi:Country>ARG</ipgapi:Country>
              <ipgapi:CommercialServiceProvider>FDCS</ipgapi:CommercialServiceProvider>
              <ipgapi:ExternalMerchantID>5921102002</ipgapi:ExternalMerchantID>
              <ipgapi:OrderId>ORD02</ipgapi:OrderId>
              <ipgapi:IpgTransactionId>84578595466</ipgapi:IpgTransactionId>
              <ipgapi:PaymentType>CREDITCARD</ipgapi:PaymentType>
              <ipgapi:ProcessorApprovalCode>014593</ipgapi:ProcessorApprovalCode>
              <ipgapi:ProcessorReceiptNumber>7641</ipgapi:ProcessorReceiptNumber>
              <ipgapi:ProcessorBatchNumber>090</ipgapi:ProcessorBatchNumber>
              <ipgapi:ProcessorEndpointID>TXSP ARGENTINA VIA CAFEX VISA</ipgapi:ProcessorEndpointID>
              <ipgapi:ProcessorCCVResponse>X</ipgapi:ProcessorCCVResponse>
              <ipgapi:ProcessorReferenceNumber>014593014593</ipgapi:ProcessorReferenceNumber>
              <ipgapi:ProcessorResponseCode>00</ipgapi:ProcessorResponseCode>
              <ipgapi:ProcessorResponseMessage>Function performed error-free</ipgapi:ProcessorResponseMessage>
              <ipgapi:ProcessorTraceNumber>014593</ipgapi:ProcessorTraceNumber>
              <ipgapi:TDate>1635146125</ipgapi:TDate>
              <ipgapi:TDateFormatted>2021.10.25 09:15:25 (CEST)</ipgapi:TDateFormatted>
              <ipgapi:TerminalID>98000000</ipgapi:TerminalID>
              <ipgapi:TransactionResult>APPROVED</ipgapi:TransactionResult>
              <ipgapi:TransactionTime>1635146125</ipgapi:TransactionTime>
          </ipgapi:IPGApiOrderResponse>
      </SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    RESPONSE
  end

  def failed_authorize_response
    <<~RESPONSE
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
      <SOAP-ENV:Header/>
      <SOAP-ENV:Body>
          <SOAP-ENV:Fault>
              <faultcode>SOAP-ENV:Client</faultcode>
              <faultstring xml:lang="en">ProcessingException</faultstring>
              <detail>
                  <ipgapi:IPGApiOrderResponse xmlns:a1="http://ipg-online.com/ipgapi/schemas/a1" xmlns:ipgapi="http://ipg-online.com/ipgapi/schemas/ipgapi" xmlns:v1="http://ipg-online.com/ipgapi/schemas/v1">
                      <ipgapi:ApprovalCode>N:-5003:The order already exists in the database.</ipgapi:ApprovalCode>
                      <ipgapi:ErrorMessage>SGS-005003: The order already exists in the database.</ipgapi:ErrorMessage>
                      <ipgapi:OrderId>ORD03</ipgapi:OrderId>
                      <ipgapi:TDate>1635156782</ipgapi:TDate>
                      <ipgapi:TDateFormatted>2021.10.25 12:13:02 (CEST)</ipgapi:TDateFormatted>
                      <ipgapi:TransactionResult>FAILED</ipgapi:TransactionResult>
                      <ipgapi:TransactionTime>1635156782</ipgapi:TransactionTime>
                      <ipgapi:Secure3DResponse/>
                  </ipgapi:IPGApiOrderResponse>
              </detail>
          </SOAP-ENV:Fault>
      </SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    RESPONSE
  end

  def successful_capture_response
    <<~RESPONSE
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
      <SOAP-ENV:Header/>
      <SOAP-ENV:Body>
          <ipgapi:IPGApiOrderResponse xmlns:a1="http://ipg-online.com/ipgapi/schemas/a1" xmlns:ipgapi="http://ipg-online.com/ipgapi/schemas/ipgapi" xmlns:v1="http://ipg-online.com/ipgapi/schemas/v1">
              <ipgapi:ApprovalCode>Y:034747:4578608047:PPXX:0347477672</ipgapi:ApprovalCode>
              <ipgapi:AVSResponse>PPX</ipgapi:AVSResponse>
              <ipgapi:Brand>MASTERCARD</ipgapi:Brand>
              <ipgapi:Country>ARG</ipgapi:Country>
              <ipgapi:CommercialServiceProvider>FDCS</ipgapi:CommercialServiceProvider>
              <ipgapi:ExternalMerchantID>5921102002</ipgapi:ExternalMerchantID>
              <ipgapi:OrderId>ORD04</ipgapi:OrderId>
              <ipgapi:IpgTransactionId>84578608047</ipgapi:IpgTransactionId>
              <ipgapi:PaymentType>CREDITCARD</ipgapi:PaymentType>
              <ipgapi:ProcessorApprovalCode>034747</ipgapi:ProcessorApprovalCode>
              <ipgapi:ProcessorReceiptNumber>7672</ipgapi:ProcessorReceiptNumber>
              <ipgapi:ProcessorBatchNumber>090</ipgapi:ProcessorBatchNumber>
              <ipgapi:ProcessorEndpointID>TXSP ARGENTINA VIA CAFEX VISA</ipgapi:ProcessorEndpointID>
              <ipgapi:ProcessorCCVResponse>X</ipgapi:ProcessorCCVResponse>
              <ipgapi:ProcessorReferenceNumber>034747034747</ipgapi:ProcessorReferenceNumber>
              <ipgapi:ProcessorResponseCode>00</ipgapi:ProcessorResponseCode>
              <ipgapi:ProcessorResponseMessage>Function performed error-free</ipgapi:ProcessorResponseMessage>
              <ipgapi:ProcessorTraceNumber>034747</ipgapi:ProcessorTraceNumber>
              <ipgapi:ReferencedTDate>1635157266</ipgapi:ReferencedTDate>
              <ipgapi:TDate>1635157275</ipgapi:TDate>
              <ipgapi:TDateFormatted>2021.10.25 12:21:15 (CEST)</ipgapi:TDateFormatted>
              <ipgapi:TerminalID>98000000</ipgapi:TerminalID>
              <ipgapi:TransactionResult>APPROVED</ipgapi:TransactionResult>
              <ipgapi:TransactionTime>1635157275</ipgapi:TransactionTime>
          </ipgapi:IPGApiOrderResponse>
      </SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    RESPONSE
  end

  def failed_capture_response
    <<~RESPONSE
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
      <SOAP-ENV:Header/>
      <SOAP-ENV:Body>
          <SOAP-ENV:Fault>
              <faultcode>SOAP-ENV:Client</faultcode>
              <faultstring xml:lang="en">ProcessingException</faultstring>
              <detail>
                  <ipgapi:IPGApiOrderResponse xmlns:a1="http://ipg-online.com/ipgapi/schemas/a1" xmlns:ipgapi="http://ipg-online.com/ipgapi/schemas/ipgapi" xmlns:v1="http://ipg-online.com/ipgapi/schemas/v1">
                      <ipgapi:ApprovalCode>N:-5008:Order does not exist.</ipgapi:ApprovalCode>
                      <ipgapi:CommercialServiceProvider>FDCS</ipgapi:CommercialServiceProvider>
                      <ipgapi:ErrorMessage>SGS-005008: Order does not exist.</ipgapi:ErrorMessage>
                      <ipgapi:OrderId>ORD090</ipgapi:OrderId>
                      <ipgapi:IpgTransactionId>84578608161</ipgapi:IpgTransactionId>
                      <ipgapi:PaymentType>CREDITCARD</ipgapi:PaymentType>
                      <ipgapi:TransactionResult>FAILED</ipgapi:TransactionResult>
                      <ipgapi:TransactionTime>1635157307</ipgapi:TransactionTime>
                  </ipgapi:IPGApiOrderResponse>
              </detail>
          </SOAP-ENV:Fault>
      </SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    RESPONSE
  end

  def successful_refund_response
    <<~RESPONSE
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
      <SOAP-ENV:Header/>
      <SOAP-ENV:Body>
          <ipgapi:IPGApiOrderResponse xmlns:a1="http://ipg-online.com/ipgapi/schemas/a1" xmlns:ipgapi="http://ipg-online.com/ipgapi/schemas/ipgapi" xmlns:v1="http://ipg-online.com/ipgapi/schemas/v1">
              <ipgapi:ApprovalCode>Y:034889:4578608244:PPXX:0348897676</ipgapi:ApprovalCode>
              <ipgapi:AVSResponse>PPX</ipgapi:AVSResponse>
              <ipgapi:Brand>MASTERCARD</ipgapi:Brand>
              <ipgapi:Country>ARG</ipgapi:Country>
              <ipgapi:CommercialServiceProvider>FDCS</ipgapi:CommercialServiceProvider>
              <ipgapi:ExternalMerchantID>5921102002</ipgapi:ExternalMerchantID>
              <ipgapi:OrderId>A-8b75ffc2-95dd-4861-a91b-9c3816075f82</ipgapi:OrderId>
              <ipgapi:IpgTransactionId>84578608244</ipgapi:IpgTransactionId>
              <ipgapi:PaymentType>CREDITCARD</ipgapi:PaymentType>
              <ipgapi:ProcessorApprovalCode>034889</ipgapi:ProcessorApprovalCode>
              <ipgapi:ProcessorReceiptNumber>7676</ipgapi:ProcessorReceiptNumber>
              <ipgapi:ProcessorBatchNumber>090</ipgapi:ProcessorBatchNumber>
              <ipgapi:ProcessorEndpointID>TXSP ARGENTINA VIA CAFEX VISA</ipgapi:ProcessorEndpointID>
              <ipgapi:ProcessorCCVResponse>X</ipgapi:ProcessorCCVResponse>
              <ipgapi:ProcessorReferenceNumber>034889034889</ipgapi:ProcessorReferenceNumber>
              <ipgapi:ProcessorResponseCode>00</ipgapi:ProcessorResponseCode>
              <ipgapi:ProcessorResponseMessage>Function performed error-free</ipgapi:ProcessorResponseMessage>
              <ipgapi:ProcessorTraceNumber>034889</ipgapi:ProcessorTraceNumber>
              <ipgapi:ReferencedTDate>1635157480</ipgapi:ReferencedTDate>
              <ipgapi:TDate>1635157594</ipgapi:TDate>
              <ipgapi:TDateFormatted>2021.10.25 12:26:34 (CEST)</ipgapi:TDateFormatted>
              <ipgapi:TerminalID>98000000</ipgapi:TerminalID>
              <ipgapi:TransactionResult>APPROVED</ipgapi:TransactionResult>
              <ipgapi:TransactionTime>1635157594</ipgapi:TransactionTime>
          </ipgapi:IPGApiOrderResponse>
      </SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    RESPONSE
  end

  def failed_refund_response
    <<~RESPONSE
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
      <SOAP-ENV:Header/>
      <SOAP-ENV:Body>
          <SOAP-ENV:Fault>
              <faultcode>SOAP-ENV:Client</faultcode>
              <faultstring xml:lang="en">ProcessingException</faultstring>
              <detail>
                  <ipgapi:IPGApiOrderResponse xmlns:a1="http://ipg-online.com/ipgapi/schemas/a1" xmlns:ipgapi="http://ipg-online.com/ipgapi/schemas/ipgapi" xmlns:v1="http://ipg-online.com/ipgapi/schemas/v1">
                      <ipgapi:ApprovalCode>N:-5008:Order does not exist.</ipgapi:ApprovalCode>
                      <ipgapi:CommercialServiceProvider>FDCS</ipgapi:CommercialServiceProvider>
                      <ipgapi:ErrorMessage>SGS-005008: Order does not exist.</ipgapi:ErrorMessage>
                      <ipgapi:OrderId>182</ipgapi:OrderId>
                      <ipgapi:IpgTransactionId>84578608249</ipgapi:IpgTransactionId>
                      <ipgapi:PaymentType>CREDITCARD</ipgapi:PaymentType>
                      <ipgapi:TransactionResult>FAILED</ipgapi:TransactionResult>
                      <ipgapi:TransactionTime>1635157647</ipgapi:TransactionTime>
                  </ipgapi:IPGApiOrderResponse>
              </detail>
          </SOAP-ENV:Fault>
      </SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    RESPONSE
  end

  def successful_void_response
    <<~RESPONSE
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
      <SOAP-ENV:Header/>
      <SOAP-ENV:Body>
          <ipgapi:IPGApiOrderResponse xmlns:a1="http://ipg-online.com/ipgapi/schemas/a1" xmlns:ipgapi="http://ipg-online.com/ipgapi/schemas/ipgapi" xmlns:v1="http://ipg-online.com/ipgapi/schemas/v1">
              <ipgapi:ApprovalCode>Y:035631:4578609369:PPXX:0356317745</ipgapi:ApprovalCode>
              <ipgapi:AVSResponse>PPX</ipgapi:AVSResponse>
              <ipgapi:Brand>MASTERCARD</ipgapi:Brand>
              <ipgapi:Country>ARG</ipgapi:Country>
              <ipgapi:CommercialServiceProvider>FDCS</ipgapi:CommercialServiceProvider>
              <ipgapi:ExternalMerchantID>5921102002</ipgapi:ExternalMerchantID>
              <ipgapi:OrderId>ORD07</ipgapi:OrderId>
              <ipgapi:IpgTransactionId>84578609369</ipgapi:IpgTransactionId>
              <ipgapi:PaymentType>CREDITCARD</ipgapi:PaymentType>
              <ipgapi:ProcessorApprovalCode>035631</ipgapi:ProcessorApprovalCode>
              <ipgapi:ProcessorReceiptNumber>7745</ipgapi:ProcessorReceiptNumber>
              <ipgapi:ProcessorBatchNumber>090</ipgapi:ProcessorBatchNumber>
              <ipgapi:ProcessorEndpointID>TXSP ARGENTINA VIA CAFEX VISA</ipgapi:ProcessorEndpointID>
              <ipgapi:ProcessorCCVResponse>X</ipgapi:ProcessorCCVResponse>
              <ipgapi:ProcessorReferenceNumber>035631035631</ipgapi:ProcessorReferenceNumber>
              <ipgapi:ProcessorResponseCode>00</ipgapi:ProcessorResponseCode>
              <ipgapi:ProcessorResponseMessage>Function performed error-free</ipgapi:ProcessorResponseMessage>
              <ipgapi:ProcessorTraceNumber>035631</ipgapi:ProcessorTraceNumber>
              <ipgapi:ReferencedTDate>1635158863</ipgapi:ReferencedTDate>
              <ipgapi:TDate>1635158884</ipgapi:TDate>
              <ipgapi:TDateFormatted>2021.10.25 12:48:04 (CEST)</ipgapi:TDateFormatted>
              <ipgapi:TerminalID>98000000</ipgapi:TerminalID>
              <ipgapi:TransactionResult>APPROVED</ipgapi:TransactionResult>
              <ipgapi:TransactionTime>1635158884</ipgapi:TransactionTime>
          </ipgapi:IPGApiOrderResponse>
      </SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    RESPONSE
  end

  def failed_void_response
    <<~RESPONSE
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
      <SOAP-ENV:Header/>
      <SOAP-ENV:Body>
          <SOAP-ENV:Fault>
              <faultcode>SOAP-ENV:Client</faultcode>
              <faultstring xml:lang="en">ProcessingException</faultstring>
              <detail>
                  <ipgapi:IPGApiOrderResponse xmlns:a1="http://ipg-online.com/ipgapi/schemas/a1" xmlns:ipgapi="http://ipg-online.com/ipgapi/schemas/ipgapi" xmlns:v1="http://ipg-online.com/ipgapi/schemas/v1">
                      <ipgapi:ApprovalCode>N:-5019:Transaction not voidable</ipgapi:ApprovalCode>
                      <ipgapi:CommercialServiceProvider>FDCS</ipgapi:CommercialServiceProvider>
                      <ipgapi:ErrorMessage>SGS-005019: The transaction to be voided is not voidable</ipgapi:ErrorMessage>
                      <ipgapi:OrderId>ORD07</ipgapi:OrderId>
                      <ipgapi:IpgTransactionId>84578609426</ipgapi:IpgTransactionId>
                      <ipgapi:PaymentType>CREDITCARD</ipgapi:PaymentType>
                      <ipgapi:TDate>1635158863</ipgapi:TDate>
                      <ipgapi:TDateFormatted>2021.10.25 12:47:43 (CEST)</ipgapi:TDateFormatted>
                      <ipgapi:TransactionResult>FAILED</ipgapi:TransactionResult>
                      <ipgapi:TransactionTime>1635158863</ipgapi:TransactionTime>
                  </ipgapi:IPGApiOrderResponse>
              </detail>
          </SOAP-ENV:Fault>
      </SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    RESPONSE
  end

  def successful_store_response
    <<~RESPONSE
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
      <SOAP-ENV:Header/>
      <SOAP-ENV:Body>
          <ipgapi:IPGApiActionResponse xmlns:a1="http://ipg-online.com/ipgapi/schemas/a1" xmlns:ipgapi="http://ipg-online.com/ipgapi/schemas/ipgapi" xmlns:v1="http://ipg-online.com/ipgapi/schemas/v1">
              <ipgapi:successfully>true</ipgapi:successfully>
          </ipgapi:IPGApiActionResponse>
      </SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    RESPONSE
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to test.ipg-online.com:443...
      opened
      starting SSL for test.ipg-online.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /ipgapi/services HTTP/1.1\r\nContent-Type: text/xml; charset=utf-8\r\nAuthorization: Basic V1M1OTIxMTAyMDAyLl8uMTpuOU1DXTJzO25m\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: test.ipg-online.com\r\nContent-Length: 850\r\n\r\n"
      <- "<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:ipg=\"http://ipg-online.com/ipgapi/schemas/ipgapi\" xmlns:v1=\"http://ipg-online.com/ipgapi/schemas/v1\">\n  <soapenv:Header/>\n  <soapenv:Body>\n    <ipg:IPGApiOrderRequest>\n      <v1:Transaction>\n        <v1:CreditCardTxType>\n          <v1:StoreId>5921102002</v1:StoreId>\n          <v1:Type>sale</v1:Type>\n        </v1:CreditCardTxType>\n<v1:CreditCardData>\n  <v1:CardNumber>5165850000000008</v1:CardNumber>\n  <v1:ExpMonth>12</v1:ExpMonth>\n  <v1:ExpYear>22</v1:ExpYear>\n  <v1:CardCodeValue>123</v1:CardCodeValue>\n</v1:CreditCardData>\n<v1:Payment>\n  <v1:ChargeTotal>100</v1:ChargeTotal>\n  <v1:Currency>032</v1:Currency>\n</v1:Payment>\n<v1:TransactionDetails>\n</v1:TransactionDetails>\n      </v1:Transaction>\n    </ipg:IPGApiOrderRequest>\n  </soapenv:Body>\n</soapenv:Envelope>\n"
      -> "HTTP/1.1 200 \r\n"
      -> "Date: Fri, 29 Oct 2021 19:31:23 GMT\r\n"
      -> "Strict-Transport-Security: max-age=63072000; includeSubdomains\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Cache-Control: no-cache, no-store, must-revalidate\r\n"
      -> "Pragma: no-cache\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "Content-Security-Policy: default-src 'self' *.googleapis.com *.klarna.com *.masterpass.com *.mastercard.com *.npci.org.in 'unsafe-eval' 'unsafe-inline'; frame-ancestors 'self'\r\n"
      -> "Accept: text/xml, text/html, image/gif, image/jpeg, *; q=.2, */*; q=.2\r\n"
      -> "SOAPAction: \"\"\r\n"
      -> "Expires: 0\r\n"
      -> "Content-Type: text/xml;charset=utf-8\r\n"
      -> "Content-Length: 1808\r\n"
      -> "Set-Cookie: JSESSIONID=08B9B3093F010FFB653B645616E0A258.dc; Path=/ipgapi; Secure; HttpOnly;HttpOnly;Secure;SameSite=Lax\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: TS0108ee57=0167ad6846753d9e71cb1e6ee74e68d3fd44879a5754a362817ba3e6f52bd01c4c794c29e5cd962b66ea0104c43957e17bc40d819c; Path=/\r\n"
      -> "Set-Cookie: TS01c97684=0167ad6846d1db53410992975f8e679ecc1ec0624e54a362817ba3e6f52bd01c4c794c29e5a3f3b525308fafc99af65129fab2b19ce5715c3f475bc6c349b8428ffd87beac; path=/ipgapi\r\n"
      -> "\r\n"
      reading 1808 bytes...
      -> ""
      -> "<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\"><SOAP-ENV:Header/><SOAP-ENV:Body><ipgapi:IPGApiOrderResponse xmlns:a1=\"http://ipg-online.com/ipgapi/schemas/a1\" xmlns:ipgapi=\"http://ipg-online.com/ipgapi/schemas/ipgapi\" xmlns:v1=\"http://ipg-online.com/ipgapi/schemas/v1\"><ipgapi:ApprovalCode>Y:334849:4579259603:PPXX:3348490741</ipgapi:ApprovalCode><ipgapi:AVSResponse>PPX</ipgapi:AVSResponse><ipgapi:Brand>MASTERCARD</ipgapi:Brand><ipgapi:Country>ARG</ipgapi:Country><ipgapi:CommercialServiceProvider>FDCS</ipgapi:CommercialServiceProvider><ipgapi:ExternalMerchantID>5921102002</ipgapi:ExternalMerchantID><ipgapi:OrderId>A-2e68e140-6024-41bb-b49c-a92d4984ae01</ipgapi:OrderId><ipgapi:IpgTransactionId>84579259603</ipgapi:IpgTransactionId><ipgapi:PaymentType>CREDITCARD</ipgapi:PaymentType><ipgapi:ProcessorApprovalCode>334849</ipgapi:ProcessorApprovalCode><ipgapi:ProcessorReceiptNumber>0741</ipgapi:ProcessorReceiptNumber><ipgapi:ProcessorBatchNumber>090</ipgapi:ProcessorBatchNumber><ipgapi:ProcessorEndpointID>TXSP ARGENTINA VIA CAFEX VISA</ipgapi:ProcessorEndpointID><ipgapi:ProcessorCCVResponse>X</ipgapi:ProcessorCCVResponse><ipgapi:ProcessorReferenceNumber>334849334849</ipgapi:ProcessorReferenceNumber><ipgapi:ProcessorResponseCode>00</ipgapi:ProcessorResponseCode><ipgapi:ProcessorResponseMessage>Function performed error-free</ipgapi:ProcessorResponseMessage><ipgapi:ProcessorTraceNumber>334849</ipgapi:ProcessorTraceNumber><ipgapi:TDate>1635535883</ipgapi:TDate><ipgapi:TDateFormatted>2021.10.29 21:31:23 (CEST)</ipgapi:TDateFormatted><ipgapi:TerminalID>98000000</ipgapi:TerminalID><ipgapi:TransactionResult>APPROVED</ipgapi:TransactionResult><ipgapi:TransactionTime>1635535883</ipgapi:TransactionTime></ipgapi:IPGApiOrderResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>"
      read 1808 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to test.ipg-online.com:443...
      opened
      starting SSL for test.ipg-online.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /ipgapi/services HTTP/1.1\r\nContent-Type: text/xml; charset=utf-8\r\nAuthorization: Basic [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: test.ipg-online.com\r\nContent-Length: 850\r\n\r\n"
      <- "<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:ipg=\"http://ipg-online.com/ipgapi/schemas/ipgapi\" xmlns:v1=\"http://ipg-online.com/ipgapi/schemas/v1\">\n  <soapenv:Header/>\n  <soapenv:Body>\n    <ipg:IPGApiOrderRequest>\n      <v1:Transaction>\n        <v1:CreditCardTxType>\n          <v1:StoreId>[FILTERED]</v1:StoreId>\n          <v1:Type>sale</v1:Type>\n        </v1:CreditCardTxType>\n<v1:CreditCardData>\n  <v1:CardNumber>[FILTERED]</v1:CardNumber>\n  <v1:ExpMonth>12</v1:ExpMonth>\n  <v1:ExpYear>22</v1:ExpYear>\n  <v1:CardCodeValue>[FILTERED]</v1:CardCodeValue>\n</v1:CreditCardData>\n<v1:Payment>\n  <v1:ChargeTotal>100</v1:ChargeTotal>\n  <v1:Currency>032</v1:Currency>\n</v1:Payment>\n<v1:TransactionDetails>\n</v1:TransactionDetails>\n      </v1:Transaction>\n    </ipg:IPGApiOrderRequest>\n  </soapenv:Body>\n</soapenv:Envelope>\n"
      -> "HTTP/1.1 200 \r\n"
      -> "Date: Fri, 29 Oct 2021 19:31:23 GMT\r\n"
      -> "Strict-Transport-Security: max-age=63072000; includeSubdomains\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Cache-Control: no-cache, no-store, must-revalidate\r\n"
      -> "Pragma: no-cache\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "Content-Security-Policy: default-src 'self' *.googleapis.com *.klarna.com *.masterpass.com *.mastercard.com *.npci.org.in 'unsafe-eval' 'unsafe-inline'; frame-ancestors 'self'\r\n"
      -> "Accept: text/xml, text/html, image/gif, image/jpeg, *; q=.2, */*; q=.2\r\n"
      -> "SOAPAction: \"\"\r\n"
      -> "Expires: 0\r\n"
      -> "Content-Type: text/xml;charset=utf-8\r\n"
      -> "Content-Length: 1808\r\n"
      -> "Set-Cookie: JSESSIONID=08B9B3093F010FFB653B645616E0A258.dc; Path=/ipgapi; Secure; HttpOnly;HttpOnly;Secure;SameSite=Lax\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: TS0108ee57=0167ad6846753d9e71cb1e6ee74e68d3fd44879a5754a362817ba3e6f52bd01c4c794c29e5cd962b66ea0104c43957e17bc40d819c; Path=/\r\n"
      -> "Set-Cookie: TS01c97684=0167ad6846d1db53410992975f8e679ecc1ec0624e54a362817ba3e6f52bd01c4c794c29e5a3f3b525308fafc99af65129fab2b19ce5715c3f475bc6c349b8428ffd87beac; path=/ipgapi\r\n"
      -> "\r\n"
      reading 1808 bytes...
      -> ""
      -> "<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\"><SOAP-ENV:Header/><SOAP-ENV:Body><ipgapi:IPGApiOrderResponse xmlns:a1=\"http://ipg-online.com/ipgapi/schemas/a1\" xmlns:ipgapi=\"http://ipg-online.com/ipgapi/schemas/ipgapi\" xmlns:v1=\"http://ipg-online.com/ipgapi/schemas/v1\"><ipgapi:ApprovalCode>Y:334849:4579259603:PPXX:3348490741</ipgapi:ApprovalCode><ipgapi:AVSResponse>PPX</ipgapi:AVSResponse><ipgapi:Brand>MASTERCARD</ipgapi:Brand><ipgapi:Country>ARG</ipgapi:Country><ipgapi:CommercialServiceProvider>FDCS</ipgapi:CommercialServiceProvider><ipgapi:ExternalMerchantID>5921102002</ipgapi:ExternalMerchantID><ipgapi:OrderId>A-2e68e140-6024-41bb-b49c-a92d4984ae01</ipgapi:OrderId><ipgapi:IpgTransactionId>84579259603</ipgapi:IpgTransactionId><ipgapi:PaymentType>CREDITCARD</ipgapi:PaymentType><ipgapi:ProcessorApprovalCode>334849</ipgapi:ProcessorApprovalCode><ipgapi:ProcessorReceiptNumber>0741</ipgapi:ProcessorReceiptNumber><ipgapi:ProcessorBatchNumber>090</ipgapi:ProcessorBatchNumber><ipgapi:ProcessorEndpointID>TXSP ARGENTINA VIA CAFEX VISA</ipgapi:ProcessorEndpointID><ipgapi:ProcessorCCVResponse>X</ipgapi:ProcessorCCVResponse><ipgapi:ProcessorReferenceNumber>334849334849</ipgapi:ProcessorReferenceNumber><ipgapi:ProcessorResponseCode>00</ipgapi:ProcessorResponseCode><ipgapi:ProcessorResponseMessage>Function performed error-free</ipgapi:ProcessorResponseMessage><ipgapi:ProcessorTraceNumber>334849</ipgapi:ProcessorTraceNumber><ipgapi:TDate>1635535883</ipgapi:TDate><ipgapi:TDateFormatted>2021.10.29 21:31:23 (CEST)</ipgapi:TDateFormatted><ipgapi:TerminalID>98000000</ipgapi:TerminalID><ipgapi:TransactionResult>APPROVED</ipgapi:TransactionResult><ipgapi:TransactionTime>1635535883</ipgapi:TransactionTime></ipgapi:IPGApiOrderResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>"
      read 1808 bytes
      Conn close
    POST_SCRUBBED
  end
end
