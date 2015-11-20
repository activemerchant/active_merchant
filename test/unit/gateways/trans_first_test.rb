require 'test_helper'

class TransFirstTest < Test::Unit::TestCase

  def setup
    @gateway = TransFirstGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @credit_card = credit_card('4242424242424242')
    @check = check
    @options = {
      :billing_address => address
    }
    @amount = 100
  end

  def test_missing_field_response
    @gateway.stubs(:ssl_post).returns(missing_field_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert response.test?
    assert_equal 'Missing parameter: UserId.', response.message
  end

  def test_successful_purchase
    @gateway.stubs(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'test transaction', response.message
    assert_equal '355|creditcard', response.authorization
  end

  def test_failed_purchase
    @gateway.stubs(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert response.test?
    assert_equal '29005716|creditcard', response.authorization
    assert_equal 'Invalid cardholder number', response.message
  end

  def test_successful_purchase_with_echeck
    @gateway.stubs(:ssl_post).returns(successful_purchase_echeck_response)
    response = @gateway.purchase(@amount, @check, @options)

    assert_success response
  end

  def test_failed_purchase_with_echeck
    @gateway.stubs(:ssl_post).returns(failed_purchase_echeck_response)
    response = @gateway.purchase(@amount, @check, @options)

    assert_failure response
  end

  def test_successful_refund
    @gateway.stubs(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, "TransID")
    assert_success response
    assert_equal '207686608|creditcard', response.authorization
  end

  def test_failed_refund
    @gateway.stubs(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, "TransID")
    assert_failure response
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'X', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  private
  def missing_field_response
    "Missing parameter: UserId.\r\n"
  end

  def successful_purchase_response
    <<-XML
    <?xml version="1.0" encoding="utf-8"?>
    <CCSaleDebitResponse xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.paymentresources.com/webservices/">
      <TransID>355</TransID>
      <RefID>c2535abbf0bb38005a14fd575553df65</RefID>
      <Amount>1.00</Amount>
      <AuthCode>Test00</AuthCode>
      <Status>Authorized</Status>
      <AVSCode>X</AVSCode>
      <Message>test transaction</Message>
      <CVV2Code>M</CVV2Code>
      <ACI />
      <AuthSource />
      <TransactionIdentifier />
      <ValidationCode />
      <CAVVResultCode />
    </CCSaleDebitResponse>
    XML
  end

  def failed_purchase_response
    <<-XML
    <?xml version="1.0" encoding="utf-8" ?>
    <CCSaleDebitResponse xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.paymentresources.com/webservices/">
      <TransID>29005716</TransID>
      <RefID>0610</RefID>
      <PostedDate>2005-09-29T15:16:23.7297658-07:00</PostedDate>
      <SettledDate>2005-09-29T15:16:23.9641468-07:00</SettledDate>
      <Amount>0.02</Amount>
      <AuthCode />
      <Status>Declined</Status>
      <AVSCode />
      <Message>Invalid cardholder number</Message>
      <CVV2Code />
      <ACI />
      <AuthSource />
      <TransactionIdentifier />
      <ValidationCode />
      <CAVVResultCode />
    </CCSaleDebitResponse>
    XML
  end

  def successful_purchase_echeck_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <CheckStatus>
      xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema- instance" xmlns="http://www.paymentresources.com/webservices/">
        <Success>1</Success>
        <TransID>11996</TransID>
        <RefID>PRICreditTest</RefID>
        <PostedDate>004-02-04T08:23:02.9467720-08:00</PostedDate>
        <AuthCode> CHECK IS NOT VERIFIED </AuthCode>
        <Status>APPROVED</Status>
        <Message />
        <Amount>1.01</Amount>
      </CheckStatus>
    XML
  end

  def failed_purchase_echeck_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <CheckStatus>
      xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema- instance" xmlns="http://www.paymentresources.com/webservices/">
        <Success>0</Success>
        <TransID>0</TransID>
        <RefID>PRICreditTest</RefID>
        <PostedDate>2004-02-04T08:23:02.9467720-08:00</PostedDate>
        <AuthCode> CHECK IS NOT VERIFIED </AuthCode>
        <Status>DENIED</Status>
        <Message> Error Message </Message>
        <Amount>1.01</Amount>
      </CheckStatus>
    XML
  end

  def successful_refund_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <BankCardRefundStatus xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.paymentresources.com/webservices/">
        <TransID>207686608</TransID>
        <CreditID>5681409</CreditID>
        <RefID />
        <PostedDate>2010-08-09T15:20:50.9740575-06:00</PostedDate> <SettledDate>0001-01-01T00:00:00</SettledDate>
        <Amount>1.0000</Amount>
        <Status>Authorized</Status>
      </BankCardRefundStatus>
    XML
  end

  def failed_refund_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <BankCardRefundStatus xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.paymentresources.com/webservices/">
        <TransID>0</TransID>
        <CreditID>0</CreditID>
        <PostedDate>0001-01-01T00:00:00</PostedDate> <SettledDate>0001-01-01T00:00:00</SettledDate>
        <Amount>0</Amount>
        <Status>Canceled</Status>
        <Message>Transaction Is Not Allowed To Void or Refund</Message>
      </BankCardRefundStatus>
    XML
  end
end
