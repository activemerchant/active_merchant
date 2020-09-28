require 'test_helper'

class QuantumTest < Test::Unit::TestCase
  def setup
    @gateway = QuantumGateway.new(
                 :login => '',
                 :password => ''
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal '2983691;2224', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end
  
  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
    %(<QGWRequest>
    <ResponseSummary>
      <RequestType>ProcessSingleTransaction</RequestType>
      <Status>Success</Status>
      <StatusDescription>Request was successful.</StatusDescription>
      <ResultCount>1</ResultCount>
      <TimeStamp>2011-01-14 16:41:38</TimeStamp>
    </ResponseSummary>
    <Result>
      <TransactionID>2983691</TransactionID>
      <Status>APPROVED</Status>
      <StatusDescription>Transaction is APPROVED</StatusDescription>
      <CustomerID></CustomerID>
      <TransactionType>CREDIT</TransactionType>
      <FirstName>Longbob</FirstName>
      <LastName>Longsen</LastName>
      <Address>1234 My Street</Address>
      <ZipCode>K1C2N6</ZipCode>
      <City>Ottawa</City>
      <State>ON</State>
      <EmailAddress></EmailAddress>
      <CreditCardNumber>2224</CreditCardNumber>
      <ExpireMonth>09</ExpireMonth>
      <ExpireYear>12</ExpireYear>
      <Memo>Store Purchase</Memo>
      <Amount>1.00</Amount>
      <TransactionDate>2011-01-14</TransactionDate>
      <PaymentType>CC</PaymentType>
      <CardType>VI</CardType>
      <AVSResponseCode>A</AVSResponseCode>
      <AuthorizationCode>099557</AuthorizationCode>
      <CVV2ResponseCode>N</CVV2ResponseCode>
    </Result>
    </QGWRequest>)
  end
  
  # Place raw failed response from gateway here
  def failed_purchase_response
    %(<QGWRequest>
    <ResponseSummary>
      <RequestType>ProcessSingleTransaction</RequestType>
      <Status>Success</Status>
      <StatusDescription>Request was successful.</StatusDescription>
      <ResultCount>1</ResultCount>
      <TimeStamp>2011-01-14 16:41:40</TimeStamp>
    </ResponseSummary>
    <Result>
      <TransactionID>2983692</TransactionID>
      <Status>DECLINED</Status>
      <StatusDescription>Transaction is DECLINED</StatusDescription>
      <CustomerID></CustomerID>
      <TransactionType>CREDIT</TransactionType>
      <FirstName>Longbob</FirstName>
      <LastName>Longsen</LastName>
      <Address>1234 My Street</Address>
      <ZipCode>K1C2N6</ZipCode>
      <EmailAddress></EmailAddress>
      <CreditCardNumber>2224</CreditCardNumber>
      <ExpireMonth>09</ExpireMonth>
      <ExpireYear>12</ExpireYear>
      <Memo>Store Purchase</Memo>
      <Amount>0.01</Amount>
      <TransactionDate>2011-01-14</TransactionDate>
      <FailReason>AUTH DECLINED 200</FailReason>
      <ErrorCode>200</ErrorCode>
      <PaymentType>CC</PaymentType>
      <CardType>VI</CardType>
      <AVSResponseCode>Y</AVSResponseCode>
      <CVV2ResponseCode>N</CVV2ResponseCode>
    </Result>
    </QGWRequest>)
  end
end
