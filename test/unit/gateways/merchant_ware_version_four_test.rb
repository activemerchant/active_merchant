require 'test_helper'

class MerchantWareVersionFourTest < Test::Unit::TestCase
  def setup
    @gateway = MerchantWareVersionFourGateway.new(
                 :login => 'login',
                 :password => 'password',
                 :name => 'name'
               )

    @credit_card = credit_card
    @authorization = '1236564'
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address
    }
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '1236564', response.authorization
    assert_equal "APPROVED", response.message
    assert response.test?
  end

  def test_soap_fault_during_authorization
    response_400 = stub(:code => "400", :message => "Bad Request", :body => fault_authorization_response)
    @gateway.expects(:ssl_post).raises(ActiveMerchant::ResponseError.new(response_400))

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?

    assert_nil response.authorization
    assert_equal "amount cannot be null. Parameter name: amount", response.message
    assert_equal response_400.code, response.params["http_code"]
    assert_equal response_400.message, response.params["http_message"]
  end

  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?

    assert_nil response.authorization
    assert_equal "invalid exp date", response.message
    assert_equal "DECLINED", response.params["status"]
    assert_equal "1024", response.params["failure_code"]
  end

  def test_failed_authorization_due_to_invalid_credit_card_number
    @gateway.expects(:ssl_post).returns(invalid_credit_card_number_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?

    assert_nil response.authorization
    assert_equal "Invalid card number.", response.message
    assert_nil response.params["status"]
    assert_nil response.params["failure_code"]
  end

  def test_refund
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/<token>transaction_id<\//), anything).returns("")
    @gateway.expects(:parse).returns({})
    @gateway.refund(@amount, "transaction_id", @options)
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert response = @gateway.void("1")
    assert_instance_of Response, response
    assert_failure response
    assert response.test?

    assert_nil response.authorization
    assert_equal "original transaction id not found", response.message
    assert_equal "DECLINED", response.params["status"]
    assert_equal "1019", response.params["failure_code"]
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'N', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_successful_purchase_using_prior_transaction
    @gateway.expects(:ssl_post).returns(successful_purchase_using_prior_transaction_response)

    response = @gateway.purchase(@amount, @authorization, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '1236564', response.authorization
    assert_equal "APPROVED", response.message
    assert response.test?
  end

  private

  def successful_authorization_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
 xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <PreAuthorizationKeyedResponse xmlns="http://schemas.merchantwarehouse.com/merchantware/40/Credit/">
      <PreAuthorizationKeyedResult>
        <Amount>1.00</Amount>
        <ApprovalStatus>APPROVED</ApprovalStatus>
        <AuthorizationCode>MC0110</AuthorizationCode>
        <AvsResponse>N</AvsResponse>
        <Cardholder></Cardholder>
        <CardNumber></CardNumber>
        <CardType>0</CardType>
        <CvResponse>M</CvResponse>
        <EntryMode>0</EntryMode>
        <ErrorMessage></ErrorMessage>
        <ExtraData></ExtraData>
        <InvoiceNumber></InvoiceNumber>
        <Token>1236564</Token>
        <TransactionDate>10/10/2008 1:13:55 PM</TransactionDate>
        <TransactionType>7</TransactionType>
      </PreAuthorizationKeyedResult>
    </PreAuthorizationKeyedResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def fault_authorization_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <PreAuthorizationKeyedResponse xmlns="http://schemas.merchantwarehouse.com/merchantware/40/Credit/">
      <PreAuthorizationKeyedResult>
        <Amount />
        <ApprovalStatus />
        <AuthorizationCode />
        <AvsResponse />
        <Cardholder />
        <CardNumber />
        <CardType>0</CardType>
        <CvResponse />
        <EntryMode>0</EntryMode>
        <ErrorMessage>amount cannot be null. Parameter name: amount</ErrorMessage>
        <ExtraData />
        <InvoiceNumber />
        <Token />
        <TransactionDate />
        <TransactionType>0</TransactionType>
      </PreAuthorizationKeyedResult>
    </PreAuthorizationKeyedResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def failed_authorization_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <PreAuthorizationKeyedResponse xmlns="http://schemas.merchantwarehouse.com/merchantware/40/Credit/">
      <PreAuthorizationKeyedResult>
        <Amount>1.00</Amount>
        <ApprovalStatus>DECLINED;1024;invalid exp date</ApprovalStatus>
        <AuthorizationCode />
        <AvsResponse />
        <Cardholder>Visa Test Card</Cardholder>
        <CardNumber>************0019</CardNumber>
        <CardType>4</CardType>
        <CvResponse />
        <EntryMode>1</EntryMode>
        <ErrorMessage />
        <ExtraData />
        <InvoiceNumber>TT0017</InvoiceNumber>
        <Token />
        <TransactionDate>5/15/2013 8:47:14 AM</TransactionDate>
        <TransactionType>5</TransactionType>
      </PreAuthorizationKeyedResult>
    </PreAuthorizationKeyedResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def failed_void_response
    <<-XML
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <VoidPreAuthorizationResponse xmlns="http://schemas.merchantwarehouse.com/merchantware/40/Credit/">
      <VoidPreAuthorizationResult>
        <Amount />
        <ApprovalStatus>DECLINED;1019;original transaction id not found</ApprovalStatus>
        <AuthorizationCode />
        <AvsResponse />
        <Cardholder />
        <CardNumber />
        <CardType>0</CardType>
        <CvResponse />
        <EntryMode>0</EntryMode>
        <ErrorMessage />
        <ExtraData />
        <InvoiceNumber />
        <Token />
        <TransactionDate>5/15/2013 9:37:04 AM</TransactionDate>
        <TransactionType>3</TransactionType>
      </VoidPreAuthorizationResult>
    </VoidPreAuthorizationResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def successful_purchase_using_prior_transaction_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
 xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <RepeatSaleResponse xmlns="http://schemas.merchantwarehouse.com/merchantware/40/Credit/">
      <RepeatSaleResult>
        <Amount>5.00</Amount>
        <ApprovalStatus>APPROVED</ApprovalStatus>
        <AuthorizationCode>MC0110</AuthorizationCode>
        <AvsResponse></AvsResponse>
        <Cardholder></Cardholder>
        <CardNumber></CardNumber>
        <CardType>0</CardType>
        <CvResponse></CvResponse>
        <EntryMode>0</EntryMode>
        <ErrorMessage></ErrorMessage>
        <ExtraData></ExtraData>
        <InvoiceNumber></InvoiceNumber>
        <Token>1236564</Token>
        <TransactionDate>10/10/2008 1:13:55 PM</TransactionDate>
        <TransactionType>7</TransactionType>
      </RepeatSaleResult>
    </RepeatSaleResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def invalid_credit_card_number_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <PreAuthorizationKeyedResponse xmlns="http://schemas.merchantwarehouse.com/merchantware/40/Credit/">
      <PreAuthorizationKeyedResult>
        <Amount />
        <ApprovalStatus />
        <AuthorizationCode />
        <AvsResponse />
        <Cardholder />
        <CardNumber />
        <CardType>0</CardType>
        <CvResponse />
        <EntryMode>0</EntryMode>
        <ErrorMessage>Invalid card number.</ErrorMessage>
        <ExtraData />
        <InvoiceNumber />
        <Token />
        <TransactionDate />
        <TransactionType>0</TransactionType>
      </PreAuthorizationKeyedResult>
    </PreAuthorizationKeyedResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end
end
