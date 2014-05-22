require 'test_helper'

class AuthorizenetTest < Test::Unit::TestCase
  def setup
    @gateway = AuthorizenetGateway.new(
      some_credential: 'login',
      another_credential: 'password'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'REPLACE', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize
  end

  def test_failed_authorize
  end

  def test_successful_capture
  end

  def test_failed_capture
  end

  def test_successful_refund
  end

  def test_failed_refund
  end

  def test_successful_void
  end

  def test_failed_void
  end

  private

  def successful_purchase_response
=begin
    %(
      Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      to "true" when running remote tests:

      $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
        test/remote/gateways/remote_authorizenet_test.rb \
        -n test_successful_purchase
    )
=end
    <<-eos
    <?xml version="1.0" encoding="utf-8"?>
    <createTransactionResponse
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
    <refId>1</refId>
    <messages>
      <resultCode>Ok</resultCode>
        <message>
        <code>I00001</code>
        <text>Successful.</text>
        </message>
    </messages>
    <transactionResponse>
      <responseCode>1</responseCode>
      <authCode>GSOFTZ</authCode>
      <avsResultCode>Y</avsResultCode>
      <cvvResultCode>P</cvvResultCode>
      <cavvResultCode>2</cavvResultCode>
      <transId>2213698343</transId>
        <refTransID/>
        <transHash>655D049EE60E1766C9C28EB47CFAA389</transHash>
      <testRequest>0</testRequest>
      <accountNumber>XXXX2224</accountNumber>
      <accountType>Visa</accountType>
      <messages>
        <message>
          <code>1</code>
          <description>This transaction has been approved.</description>
        </message>
      </messages>
    </transactionResponse>
    </createTransactionResponse>
    eos
  end

  def failed_purchase_response
  end

  def successful_authorize_response
  end

  def failed_authorize_response
  end

  def successful_capture_response
  end

  def failed_capture_response
  end

  def successful_refund_response
  end

  def failed_refund_response
  end

  def successful_void_response
  end

  def failed_void_response
  end
end
