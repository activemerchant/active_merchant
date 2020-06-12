require 'test_helper'

class AafesTest < Test::Unit::TestCase
  def setup
    @gateway = AafesGateway.new(identity_uuid: 'identity_uuid')

    # Amount field must be passed in as a decimal
    @amount = '%.2f' % 100
    @metadata = {
      zip: 75236,
      expiration: 2210
    }

    @milstar_card = ActiveMerchant::Billing::PaymentToken.new(
      '900PRPYIGCWDS4O2615',
      @metadata
    )

    # TODO: The RRN needs to be unique everytime - the RRN needs to be a base-64 12 character long string
    @options = {
      order_id: 'ONP3951033',
      billing_address: address,
      description: 'SALE',
      plan_number: 10001,
      transaction_id: 6750,
      rrn: 'RRNPG1685262',
      term_id: 20,
      customer_id: 45017632990
    }

    @bad_options = {
      order_id: 'ONP3951033',
      billing_address: address,
      description: 'Store Purchase',
      plan_number: 10001,
      transaction_id: 6750,
      rrn: 'lengthofrrnmustbe12char',
      term_id: 20,
      customer_id: 45017632990
    }
  end

  def test_successful_purchase_with_milstar_card
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @milstar_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @milstar_card, @options)
    assert_failure response
    assert_equal 'Decline', response.message
    assert response.test?
  end

  # def test_successful_authorize
  # end

  # def test_failed_authorize
  # end

  # def test_successful_capture
  # end

  # def test_failed_capture
  # end

  # def test_successful_refund
  # end

  # def test_failed_refund
  # end

  # def test_successful_void
  # end

  # def test_failed_void
  # end

  # def test_successful_verify
  # end

  # def test_successful_verify_with_failed_void
  # end

  # def test_failed_verify
  # end

  # def test_scrub
  #   # assert @gateway.supports_scrubbing?
  #   # assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  # end

  private

  def pre_scrubbed
    <<-TRANSCRIPT
      opening connection to uat-stargate.aafes.com:1009...
      opened
      starting SSL for uat-stargate.aafes.com:1009...
      SSL established
      <- "POST /stargate/1/creditmessage HTTP/1.1\r\nContent-Type: application/xml\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: uat-stargate.aafes.com:1009\r\nContent-Length: 1184\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<cm:Message xmlns:cm=\"http://www.aafes.com/credit\" TypeCode=\"Request\" MajorVersion=\"3\" MinorVersion=\"4\" FixVersion=\"0\">\n  <cm:Header>\n    <cm:IdentityUUID>9765830b-38ec-4154-b349-15ef4a302489</cm:IdentityUUID>\n    <cm:LocalDateTime>2019-09-04T22:26:02</cm:LocalDateTime>\n    <cm:SettleIndicator>false</cm:SettleIndicator>\n    <cm:OrderNumber>ONP3951033</cm:OrderNumber>\n    <cm:transactionId>6750</cm:transactionId>\n    <cm:termId>20</cm:termId>\n    <cm:Comment>Test</cm:Comment>\n    <cm:CustomerID>45017632990</cm:CustomerID>\n  </cm:Header>\n  <cm:Request RRN=\"RRNPGtwi5361\">\n    <cm:Media>Milstar</cm:Media>\n    <cm:RequestType>Sale</cm:RequestType>\n    <cm:InputType>Keyed</cm:InputType>\n    <cm:Token>Token</cm:Token>\n    <cm:Account>900PRPYIGCWDS4O2615</cm:Account>\n    <cm:Expiration>2210</cm:Expiration>\n    <cm:AmountField>50.00</cm:AmountField>\n    <cm:PlanNumbers>\n      <cm:PlanNumber>10001</cm:PlanNumber>\n    </cm:PlanNumbers>\n    <cm:DescriptionField>SALE</cm:DescriptionField>\n    <cm:AddressVerificationService>\n      <cm:BillingZipCode>75236</cm:BillingZipCode>\n    </cm:AddressVerificationService>\n  </cm:Request>\n</cm:Message>\n"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Connection: close\r\n"
      -> "X-Powered-By: Undertow/1\r\n"
      -> "Server: WildFly/10\r\n"
      -> "Content-Type: application/xml;charset=UTF-8\r\n"
      -> "Content-Length: 925\r\n"
      -> "Date: Thu, 11 Jun 2020 12:33:42 GMT\r\n"
      -> "\r\n"
      reading 925 bytes...
      -> "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Message TypeCode=\"Response\" MajorVersion=\"3\" MinorVersion=\"4\" FixVersion=\"0\" xmlns=\"http://www.aafes.com/credit\">\n    <Header>\n        <IdentityUUID>9765830b-38ec-4154-b349-15ef4a302489</IdentityUUID>\n        <LocalDateTime>2019-09-04T22:26:02</LocalDateTime>\n        <SettleIndicator>false</SettleIndicator>\n        <OrderNumber>ONP3951033</OrderNumber>\n        <transactionId>6750</transactionId>\n        <termId>20</termId>\n        <Comment>Test</Comment>\n        <CustomerID>45017632990</CustomerID>\n    </Header>\n    <Response RRN=\"RRNPGtwi5361\">\n        <Media>Milstar</Media>\n        <ResponseType>Approved</ResponseType>\n        <AuthNumber>020503</AuthNumber>\n        <ReasonCode>000</ReasonCode>\n        <PlanNumber>10001</PlanNumber>\n        <DescriptionField>APPROVED  </DescriptionField>\n        <origReqType>Sale</origReqType>\n    </Response>\n</Message>\n"
      read 925 bytes
      Conn close
    TRANSCRIPT
  end

  # def post_scrubbed
  # end

  def successful_purchase_response
    <<-XML
    <Message TypeCode="Response" MajorVersion="3" MinorVersion="4" FixVersion="0" xmlns="http://www.aafes.com/credit">
      <Header>
          <IdentityUUID>9765830b-38ec-4154-b349-15ef4a302489</IdentityUUID>
          <LocalDateTime>2020-06-11T19:20:10Z</LocalDateTime>
          <SettleIndicator>false</SettleIndicator>
          <OrderNumber>ONP3951033</OrderNumber>
          <transactionId>6750</transactionId>
          <termId>20</termId>
          <Comment>Test</Comment>
          <CustomerID>45017632990</CustomerID>
      </Header>
      <Response RRN="RRNP45805353">
          <Media>Milstar</Media>
          <ResponseType>Approved</ResponseType>
          <AuthNumber>020588</AuthNumber>
          <ReasonCode>000</ReasonCode>
          <PlanNumber>10001</PlanNumber>
          <DescriptionField>APPROVED  </DescriptionField>
          <origReqType>Sale</origReqType>
      </Response>
    </Message>
    XML
  end

  def failed_purchase_response
    <<-XML
    <Message TypeCode="Response" MajorVersion="3" MinorVersion="4" FixVersion="0" xmlns="http://www.aafes.com/credit">
      <Header>
          <IdentityUUID>9765830b-38ec-4154-b349-15ef4a302489</IdentityUUID>
          <LocalDateTime>2020-06-11T19:13:34Z</LocalDateTime>
          <SettleIndicator>false</SettleIndicator>
          <OrderNumber>ONP3951033</OrderNumber>
          <transactionId>6750</transactionId>
          <termId>20</termId>
          <Comment>Test</Comment>
          <CustomerID>45017632990</CustomerID>
      </Header>
      <Response RRN="RRNP45805363">
          <ResponseType>Decline</ResponseType>
          <ReasonCode>951</ReasonCode>
          <DescriptionField>INVALID_REQUEST</DescriptionField>
      </Response>
    </Message>
    XML
  end

  # def successful_capture_response
  # end

  # def failed_capture_response
  # end

  # def successful_refund_response
  # end

  # def failed_refund_response
  # end

  # def successful_void_response
  # end

  # def failed_void_response
  # end
end
