require 'test_helper'

class QbmsTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = QbmsGateway.new(
      :login  => "test",
      :ticket => "abc123",
      :pem    => 'PEM')

    @amount = 100
    @card = credit_card('4111111111111111')

    @options = {}
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(authorization_response)

    assert response = @gateway.authorize(@amount, @card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1000', response.authorization
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(capture_response)

    assert response = @gateway.capture(@amount, @card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1000', response.authorization
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(charge_response)

    assert response = @gateway.purchase(@amount, @card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1000', response.authorization
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(void_response)

    assert response = @gateway.void("x", @options)
    assert_instance_of Response, response
    assert_success response
  end

  def test_successful_deprecated_credit
    @gateway.expects(:ssl_post).returns(credit_response)

    assert response = @gateway.credit(@amount, "x", @options)
    assert_instance_of Response, response
    assert_success response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(credit_response)

    assert response = @gateway.refund(@amount, "x", @options)
    assert_instance_of Response, response
    assert_success response
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(authorization_response)
    assert response = @gateway.authorize(@amount, @card, @options)
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']

    @gateway.expects(:ssl_post).returns(authorization_response(:avs_street => "Fail"))
    assert response = @gateway.authorize(@amount, @card, @options)
    assert_equal 'N', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']

    @gateway.expects(:ssl_post).returns(authorization_response(:avs_zip => "Fail"))
    assert response = @gateway.authorize(@amount, @card, @options)
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'N', response.avs_result['postal_match']

    @gateway.expects(:ssl_post).returns(authorization_response(:avs_street => "Fail", :avs_zip => "Fail"))
    assert response = @gateway.authorize(@amount, @card, @options)
    assert_equal 'N', response.avs_result['street_match']
    assert_equal 'N', response.avs_result['postal_match']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(authorization_response)
    assert response = @gateway.authorize(@amount, @card, @options)
    assert_equal 'M', response.cvv_result['code']

    @gateway.expects(:ssl_post).returns(authorization_response(:card_security_code_match => "Fail"))
    assert response = @gateway.authorize(@amount, @card, @options)
    assert_equal 'N', response.cvv_result['code']

    @gateway.expects(:ssl_post).returns(authorization_response(:card_security_code_match => "NotAvailable"))
    assert response = @gateway.authorize(@amount, @card, @options)
    assert_equal 'P', response.cvv_result['code']
  end

  def test_successful_query
    @gateway.expects(:ssl_post).returns(query_response)

    assert response = @gateway.query()
    assert_instance_of Response, response
    assert_success response
  end

  def test_failed_signon
    @gateway.expects(:ssl_post).returns(query_response(:signon_status_code => 2000))

    assert response = @gateway.query()
    assert_instance_of Response, response
    assert_failure response
  end

  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(authorization_response(:status_code => 10301))

    assert response = @gateway.authorize(@amount, @card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  # helper methods start here

  def query_response(opts = {})
    wrap "MerchantAccountQuery", opts, <<-"XML"
      <ConvenienceFees>0.0</ConvenienceFees>
      <CreditCardType>Visa</CreditCardType>
      <CreditCardType>MasterCard</CreditCardType>
      <IsCheckAccepted>true</IsCheckAccepted>
    XML
  end

  def authorization_response(opts = {})
    opts = {
      :avs_street               => "Pass",
      :avs_zip                  => "Pass",
      :card_security_code_match => "Pass",
    }.merge(opts)

    wrap "CustomerCreditCardAuth", opts, <<-"XML"
      <CreditCardTransID>1000</CreditCardTransID>
      <AuthorizationCode>STRTYPE</AuthorizationCode>
      <AVSStreet>#{opts[:avs_street]}</AVSStreet>
      <AVSZip>#{opts[:avs_zip]}</AVSZip>
      <CardSecurityCodeMatch>#{opts[:card_security_code_match]}</CardSecurityCodeMatch>
      <ClientTransID>STRTYPE</ClientTransID>
    XML
  end

  def capture_response(opts = {})
    wrap "CustomerCreditCardCapture", opts, <<-"XML"
      <CreditCardTransID>1000</CreditCardTransID>
      <AuthorizationCode>STRTYPE</AuthorizationCode>
      <MerchantAccountNumber>STRTYPE</MerchantAccountNumber>
      <ReconBatchID>STRTYPE</ReconBatchID>
      <ClientTransID>STRTYPE</ClientTransID>
    XML
  end

  def charge_response(opts = {})
    opts = {
      :avs_street               => "Pass",
      :avs_zip                  => "Pass",
      :card_security_code_match => "Pass",
    }.merge(opts)

    wrap "CustomerCreditCardCharge", opts, <<-"XML"
      <CreditCardTransID>1000</CreditCardTransID>
      <AuthorizationCode>STRTYPE</AuthorizationCode>
      <AVSStreet>#{opts[:avs_street]}</AVSStreet>
      <AVSZip>#{opts[:avs_zip]}</AVSZip>
      <CardSecurityCodeMatch>#{opts[:card_security_code_match]}</CardSecurityCodeMatch>
      <MerchantAccountNumber>STRTYPE</MerchantAccountNumber>
      <ReconBatchID>STRTYPE</ReconBatchID>
      <ClientTransID>STRTYPE</ClientTransID>
    XML
  end

  def void_response(opts = {})
    wrap "CustomerCreditCardTxnVoid", opts, <<-"XML"
      <CreditCardTransID>1000</CreditCardTransID>
      <ClientTransID>STRTYPE</ClientTransID>
    XML
  end

  def credit_response(opts = {})
    wrap "CustomerCreditCardTxnVoidOrRefund", opts, <<-"XML"
      <CreditCardTransID>1000</CreditCardTransID>
      <VoidOrRefundTxnType>STRTYPE</VoidOrRefundTxnType>
      <MerchantAccountNumber>STRTYPE</MerchantAccountNumber>
      <ReconBatchID>STRTYPE</ReconBatchID>
      <ClientTransID>STRTYPE</ClientTransID>
    XML
  end

  def wrap(type, opts, xml)
    opts = {
      :signon_status_code => 0,
      :request_id         => "x",
      :status_code        => 0,
    }.merge(opts)

    <<-"XML"
     <?xml version="1.0" encoding="utf-8"?>
     <?qbmsxml version="4.0"?>
     <QBMSXML>
       <SignonMsgsRs>
         <SignonAppCertRs statusSeverity='INFO' statusCode='#{opts[:signon_status_code]}' statusMessage="Status OK">
           <ServerDateTime>2010-02-25T01:49:29</ServerDateTime>
           <SessionTicket>abc123</SessionTicket>
         </SignonAppCertRs>
       </SignonMsgsRs>
       <QBMSXMLMsgsRs>
         <#{type}Rs statusCode="#{opts[:status_code]}">
           #{xml}
         </#{type}Rs>
       </QBMSXMLMsgsRs>
     </QBMSXML>
     XML
  end
end
