require 'test_helper'
require 'active_support/core_ext/string/strip'

class AmazonPaymentsTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = AmazonPaymentsGateway.new(fixtures(:amazon_payments))
    @amount = 100
    @order_reference_id = 'ORDER_REFERENCE_ID'
    @authorization_reference_id = 'AUTHORIZATION_REFERENCE_ID'
    @capture_reference_id = 'CAPTURE_REFERENCE_ID'
    @authorization_id = 'P01-1234567-1234567-0000001'
    @capture_id = 'P01-1234567-1234567-0000002'
  end

  def test_successful_get_order_reference_details
    @gateway.expects(:ssl_post).returns(successful_get_order_reference_details_response)

    response = @gateway.get_order_reference_details(@order_reference_id)
    assert_success response
    assert_instance_of Response, response
    assert response.test?
  end

  def test_failed_get_order_reference_details
    @gateway.expects(:ssl_post).returns(failed_get_order_reference_details_response)

    response = @gateway.get_order_reference_details(@order_reference_id)
    assert_failure response
    assert_instance_of Response, response
    assert response.test?
  end

  def test_successful_set_order_reference_details
    @gateway.expects(:ssl_post).returns(successful_set_order_reference_details_response)

    options = {}
    response = @gateway.set_order_reference_details(@order_reference_id, @amount, options)
    assert_success response
    assert_instance_of Response, response
    assert response.test?
  end

  def test_set_order_reference_details_commit
    options = {
      platform_id: 'platform id',
      seller_note: 'seller note',
      seller_order_id: 'seller order id',
      store_name: 'store name',
    }
    @gateway.expects(:commit).with('SetOrderReferenceDetails', {
      'AmazonOrderReferenceId' => @order_reference_id,
      'OrderReferenceAttributes.OrderTotal.Amount' => @amount.to_s,
      'OrderReferenceAttributes.OrderTotal.CurrencyCode' => 'USD',
      'OrderReferenceAttributes.PlatformId' => options[:platform_id],
      'OrderReferenceAttributes.SellerNote' => options[:seller_note],
      'OrderReferenceAttributes.SellerOrderAttributes.SellerOrderId' => options[:seller_order_id],
      'OrderReferenceAttributes.SellerOrderAttributes.StoreName' => options[:store_name]
    })
    @gateway.set_order_reference_details(@order_reference_id, @amount, options)
  end

  def test_successful_confirm_order_reference
    @gateway.expects(:ssl_post).returns(successful_confirm_order_reference_response)

    response = @gateway.confirm_order_reference(@order_reference_id)
    assert_success response
    assert_instance_of Response, response
    assert response.test?
  end

  def test_successful_purchase
    options = {
      authorization_reference_id: @authorization_reference_id,
      capture_reference_id: @capture_reference_id
    }
    response = stub_comms do
      @gateway.purchase(@amount, @order_reference_id, options)
    end.respond_with(successful_authorize_response, successful_capture_response)

    assert_success response
    assert_instance_of MultiResponse, response
    assert response.test?
  end

  def test_failed_purchase
    options = {
      authorization_reference_id: @authorization_reference_id,
      capture_reference_id: @capture_reference_id
    }
    response = stub_comms do
      @gateway.purchase(@amount, @order_reference_id, options)
    end.respond_with(failed_authorize_response, failed_capture_response)

    assert_failure response
    assert_instance_of MultiResponse, response
    assert_equal 'TransactionAmountExceeded', response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    options = {
      authorization_reference_id: @authorization_reference_id
    }
    response = @gateway.authorize(@amount, @order_reference_id, options)

    assert_success response
    assert_instance_of Response, response
    assert_equal @authorization_id, response.authorization
    assert response.test?
  end

  def test_failed_authorize
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    options = {
      capture_reference_id: @capture_reference_id
    }
    response = @gateway.capture(@amount, @authorization_id, options)

    assert_success response
    assert_instance_of Response, response
    assert response.test?
  end

  def test_failed_capture
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    options = {
      refund_reference_id: 'refund_reference_id'
    }
    response = @gateway.refund(@amount, @capture_id, options)

    assert_success response
    assert_instance_of Response, response
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    options = {
      refund_reference_id: 'refund_reference_id'
    }
    response = @gateway.refund(@amount, @capture_id, options)

    assert_failure response
    assert_instance_of Response, response
    assert response.test?
  end

  def test_successful_close_authorization
    @gateway.expects(:ssl_post).returns(successful_close_authorization_response)

    response = @gateway.close_authorization(@authorization_id)

    assert_success response
    assert_instance_of Response, response
    assert response.test?
  end

  def test_failed_close_authorization
    @gateway.expects(:ssl_post).returns(failed_close_authorization_response)

    response = @gateway.close_authorization(@authorization_id)

    assert_failure response
    assert_instance_of Response, response
    assert response.test?
  end

  def test_successful_close_order_reference
    @gateway.expects(:ssl_post).returns(successful_close_order_reference_response)

    response = @gateway.close_order_reference(@order_reference_id)

    assert_success response
    assert_instance_of Response, response
    assert response.test?
  end

  def test_failed_close_order_reference
    @gateway.expects(:ssl_post).returns(failed_close_order_reference_response)

    response = @gateway.close_order_reference(@order_reference_id)

    assert_failure response
    assert_instance_of Response, response
    assert response.test?
  end

  def test_successful_cancel_order_reference
    @gateway.expects(:ssl_post).returns(successful_cancel_order_reference_response)

    response = @gateway.cancel_order_reference(@order_reference_id)

    assert_success response
    assert_instance_of Response, response
    assert response.test?
  end

  def test_failed_cancel_order_reference
    @gateway.expects(:ssl_post).returns(failed_cancel_order_reference_response)

    response = @gateway.cancel_order_reference(@order_reference_id)

    assert_failure response
    assert_instance_of Response, response
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_parse_successful_response
    action = 'SetOrderReferenceDetails'
    response = @gateway.send(:parse, successful_set_order_reference_details_response, action)
    assert_equal({
      'SetOrderReferenceDetailsResponse' => {
        'ResponseMetadata' => {
          'RequestId' => 'f42df4b1-8047-11df-8d5c-bf56a38ef3b4'
        },
        'SetOrderReferenceDetailsResult' => {
          'OrderReferenceDetails' => {
            'AmazonOrderReferenceId' => 'P01-1234567-1234567',
            'CreationTimestamp' => '2012-11-05T20:21:19Z',
            'Destination' => {
              'DestinationType' => 'Physical',
              'PhysicalDestination' => {
                'City' => 'New York',
                'CountryCode' => 'US',
                'PostalCode' => '10101-9876',
                'StateOrRegion' => 'NY'
              }
            },
            'ExpirationTimestamp' => '2013-05-07T23:21:19Z',
            'OrderReferenceStatus' => {
              'State' => 'Draft'
            },
            'OrderTotal' => {
              'Amount' => '106',
              'CurrencyCode' => 'USD'
            },
            'ReleaseEnvironment' => 'Live',
            'SellerNote' => 'Lorem ipsum',
            'SellerOrderAttributes' => {
              'SellerOrderId' => '5678-23'
            }
          }
        }
      }
    }, response)
  end

  def test_parse_failure_response
    action = 'Authorize'
    response = @gateway.send(:parse, failed_authorize_response, action)
    assert_equal({
      'ErrorResponse' => {
        'Error' => {
          'Type' => 'Sender',
          'Code' => 'TransactionAmountExceeded',
          'Message' => 'A Authorize request with amount 1000000.00 JPY cannot be accepted.',
        },
        'RequestId' => '4281dc31-5863-4d1a-b98f-de7e3c35c054',
      }
    }, response)
  end

  def test_commit_retries
    gateway = AmazonPaymentsGateway.new(
      fixtures(:amazon_payments).merge(
        max_retries: 3,
        retry_intervals: [0, 0, 0]
      )
    )
    gateway.expects(:raw_ssl_request).returns(retriable_net_httpresponse).times(4)

    response = gateway.send(:commit, 'Action', {})

    assert_failure response
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      <- "AWSAccessKeyId=AKIAJKYFSJU7PEXAMPLE&Action=GetOrderReferenceDetails&AddressConsentToken=YOUR_ACCESS_TOKEN&AmazonOrderReferenceId=P01-1234567-1234567&SellerId=YOUR_SELLER_ID_HERE&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=2012-11-05T19%3A01%3A11Z&Version=2013-01-01&Signature=CLZOdtJGjAo81IxaLoE7af6HqK0EXAMPLE
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      <- "AWSAccessKeyId=[FILTERED]&Action=GetOrderReferenceDetails&AddressConsentToken=YOUR_ACCESS_TOKEN&AmazonOrderReferenceId=P01-1234567-1234567&SellerId=YOUR_SELLER_ID_HERE&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=2012-11-05T19%3A01%3A11Z&Version=2013-01-01&Signature=CLZOdtJGjAo81IxaLoE7af6HqK0EXAMPLE
    POST_SCRUBBED
  end

  def successful_get_order_reference_details_response
    <<-XML
<GetOrderReferenceDetailsResponse xmlns="http://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
<GetOrderReferenceDetailsResult>
  <OrderReferenceDetails>
    <AmazonOrderReferenceId>P01-1234567-1234567</AmazonOrderReferenceId>
    <CreationTimestamp>2012-11-05T20:21:19Z</CreationTimestamp>
    <ExpirationTimestamp>2013-05-07T23:21:19Z</ExpirationTimestamp>
    <OrderReferenceStatus>
      <State>Draft</State>
    </OrderReferenceStatus>
    <Destination>
      <DestinationType>Physical</DestinationType>
      <PhysicalDestination>
        <City>New York</City>
        <StateOrRegion>NY</StateOrRegion>
        <PostalCode>10101-9876</PostalCode>
        <CountryCode>US</CountryCode>
      </PhysicalDestination>
    </Destination>
    <ReleaseEnvironment>Live</ReleaseEnvironment>
  </OrderReferenceDetails>
</GetOrderReferenceDetailsResult>
<ResponseMetadata>
  <RequestId>5f20169b-7ab2-11df-bcef-d35615e2b044</RequestId>
</ResponseMetadata>
</GetOrderReferenceDetailsResponse>
    XML
  end

  def failed_get_order_reference_details_response
    <<-XML
      <ErrorResponse xmlns="http://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <Error>
          <Type>Sender</Type>
          <Code>TransactionAmountExceeded</Code>
          <Message>A Refund request with amount 646.00 JPY cannot be accepted. Capture S03-4986860-2335791-C014008 has already been refunded for amount 646.00 JPY. The total Refund amount against this Capture cannot exceed 743.00 JPY.</Message>
        </Error>
        <RequestId>4281dc31-5863-4d1a-b98f-de7e3c35c054</RequestId>
      </ErrorResponse>
    XML
  end

  def successful_set_order_reference_details_response
    <<-XML
      <SetOrderReferenceDetailsResponse xmlns="https://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <SetOrderReferenceDetailsResult>
          <OrderReferenceDetails>
            <AmazonOrderReferenceId>P01-1234567-1234567</AmazonOrderReferenceId>
            <OrderTotal>
              <Amount>106</Amount>
              <CurrencyCode>USD</CurrencyCode>
            </OrderTotal>
            <SellerOrderAttributes>
              <SellerOrderId>5678-23</SellerOrderId>
            </SellerOrderAttributes>
            <SellerNote>Lorem ipsum</SellerNote>
            <CreationTimestamp>2012-11-05T20:21:19Z</CreationTimestamp>
            <ExpirationTimestamp>2013-05-07T23:21:19Z</ExpirationTimestamp>
            <OrderReferenceStatus>
              <State>Draft</State>
            </OrderReferenceStatus>
            <Destination>
              <DestinationType>Physical</DestinationType>
              <PhysicalDestination>
                <City>New York</City>
                <StateOrRegion>NY</StateOrRegion>
                <PostalCode>10101-9876</PostalCode>
                <CountryCode>US</CountryCode>
              </PhysicalDestination>
            </Destination>
            <ReleaseEnvironment>Live</ReleaseEnvironment>
          </OrderReferenceDetails>
        </SetOrderReferenceDetailsResult>
        <ResponseMetadata>
          <RequestId>f42df4b1-8047-11df-8d5c-bf56a38ef3b4</RequestId>
        </ResponseMetadata>
      </SetOrderReferenceDetailsResponse>
    XML
  end

  def successful_confirm_order_reference_response
    <<-XML
      <ConfirmOrderReferenceResponse xmlns="https://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <ResponseMetadata>
          <RequestId>f42df4b1-8047-11df-8d5c-bf56a38ef3b4</RequestId>
        </ResponseMetadata>
      </ConfirmOrderReferenceResponse>
    XML
  end

  def successful_purchase_response
    %(
      Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      to "true" when running remote tests:

      $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
        test/remote/gateways/remote_amazon_payments_test.rb \
        -n test_successful_purchase
    )
  end

  def failed_purchase_response
  end

  def successful_authorize_response
    <<-XML
      <AuthorizeResponse xmlns="https://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <AuthorizeResult>
          <AuthorizationDetails>
            <AmazonAuthorizationId>#{@authorization_id}</AmazonAuthorizationId>
            <AuthorizationReferenceId>test_authorize_1</AuthorizationReferenceId>
            <SellerAuthorizationNote>Lorem ipsum</SellerAuthorizationNote>
            <AuthorizationAmount>
              <CurrencyCode>USD</CurrencyCode>
              <Amount>94.50</Amount>
            </AuthorizationAmount>
            <AuthorizationFee>
              <CurrencyCode>USD</CurrencyCode>
              <Amount>0</Amount>
            </AuthorizationFee>
            <SoftDecline>true</SoftDecline>
            <AuthorizationStatus>
              <State>Pending</State>
              <LastUpdateTimestamp>2012-11-03T19:10:16Z</LastUpdateTimestamp>
            </AuthorizationStatus>
            <CreationTimestamp>2012-11-02T19:10:16Z</CreationTimestamp>
            <ExpirationTimestamp>2012-12-02T19:10:16Z</ExpirationTimestamp>
          </AuthorizationDetails>
        </AuthorizeResult>
        <ResponseMetadata>
          <RequestId>b4ab4bc3-c9ea-44f0-9a3d-67cccef565c6</RequestId>
        </ResponseMetadata>
      </AuthorizeResponse>
    XML
  end

  def failed_authorize_response
    <<-XML
      <ErrorResponse xmlns="http://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <Error>
          <Type>Sender</Type>
          <Code>TransactionAmountExceeded</Code>
          <Message>A Authorize request with amount 1000000.00 JPY cannot be accepted.</Message>
        </Error>
        <RequestId>4281dc31-5863-4d1a-b98f-de7e3c35c054</RequestId>
      </ErrorResponse>
    XML
  end

  def successful_capture_response
    <<-XML
      <CaptureResponse xmlns="https://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <CaptureResult>
          <CaptureDetails>
            <AmazonCaptureId>P01-1234567-1234567-0000002</AmazonCaptureId>
            <CaptureReferenceId>test_capture_1</CaptureReferenceId>
            <SellerCaptureNote>Lorem ipsum</SellerCaptureNote>
            <CaptureAmount>
              <CurrencyCode>USD</CurrencyCode>
              <Amount>94.50</Amount>
            </CaptureAmount>
            <CaptureStatus>
              <State>Completed</State>
              <LastUpdateTimestamp>2012-11-03T19:10:16Z</LastUpdateTimestamp>
            </CaptureStatus>
            <CreationTimestamp>2012-11-03T19:10:16Z</CreationTimestamp>
          </CaptureDetails>
        </CaptureResult>
        <ResponseMetadata>
          <RequestId>b4ab4bc3-c9ea-44f0-9a3d-67cccef565c6</RequestId>
        </ResponseMetadata>
      </CaptureResponse>
    XML
  end

  def failed_capture_response
  end

  def successful_refund_response
    <<-XML
      <RefundResponse xmlns="https://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <RefundResult>
          <RefundDetails>
            <AmazonRefundId>P01-1234567-1234567-0000003</AmazonRefundId>
            <RefundReferenceId>test_refund_1</RefundReferenceId>
            <SellerRefundNote>Lorem ipsum</SellerRefundNote>
            <RefundType>SellerInitiated</RefundType>
            <RefundedAmount>
              <CurrencyCode>USD</CurrencyCode>
              <Amount>94.50</Amount>
            </RefundedAmount>
            <FeeRefunded>
              <CurrencyCode>USD</CurrencyCode>
              <Amount>0</Amount>
            </FeeRefunded>
            <RefundStatus>
              <State>Pending</State>
              <LastUpdateTimestamp>2012-11-07T19:10:16Z</LastUpdateTimestamp>
            </RefundStatus>
            <CreationTimestamp>2012-11-05T19:10:16Z</CreationTimestamp>
          </RefundDetails>
        </RefundResult>
        <ResponseMetadata>
          <RequestId>b4ab4bc3-c9ea-44f0-9a3d-67cccef565c6</RequestId>
        </ResponseMetadata>
      </RefundResponse>
    XML
  end

  def failed_refund_response
  end

  def successful_close_authorization_response
    <<-XML
      <CloseAuthorizationResponse xmlns="https://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <ResponseMetadata>
          <RequestId>a9aedsd6-a10y-11t8-9a3d-67gggwd565c6</RequestId>
        </ResponseMetadata>
      </CloseAuthorizationResponse>
    XML
  end

  def failed_close_authorization_response
  end

  def successful_close_order_reference_response
    <<-XML
      <CloseOrderReferenceResponse xmlns="http://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <ResponseMetadata>
          <RequestId>5f20169b-7ab2-11df-bcef-d35615e2b044</RequestId>
        </ResponseMetadata>
      </CloseOrderReferenceResponse>
    XML
  end

  def failed_close_order_reference_response
  end

  def successful_cancel_order_reference_response
    <<-XML
      <CancelOrderReferenceResponse xmlns="https://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <ResponseMetadata>
          <RequestId>5f20169b-7ab2-11df-bcef-d35615e2b044</RequestId>
        </ResponseMetadata>
      </CancelOrderReferenceResponse>
    XML
  end

  def failed_cancel_order_reference_response
  end

  def retriable_net_httpresponse
    str = raw_request_throttled_response.gsub(/\n/, "\r\n")
    io = Net::BufferedIO.new(StringIO.new(str))
    res = Net::HTTPResponse.read_new(io)
    res.reading_body(io, true) { res.read_body }
    res
  end

  def raw_request_throttled_response
    body = request_throttled_response.tr("\n", '')
    <<-RAW_RESPONSE.strip_heredoc
      HTTP/1.1 503 RequestThrottled
      Connection: close
      Content-Length: #{body.length}

      #{body}
    RAW_RESPONSE
  end

  def request_throttled_response
    <<-XML
      <ErrorResponse xmlns="http://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <Error>
          <Type>Server</Type>
          <Code>RequestThrottled</Code>
          <Message>The frequency of requests was greater than allowed.</Message>
        </Error>
        <RequestId>3a6f041f-2f93-4cc0-b1e5-1e12876b6695</RequestId>
      </ErrorResponse>
    XML
  end
end
