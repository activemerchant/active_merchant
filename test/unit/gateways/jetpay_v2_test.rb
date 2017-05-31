require 'test_helper'

class JetpayV2Test < Test::Unit::TestCase

  def setup
    @gateway = JetpayV2Gateway.new(:login => 'login')

    @credit_card = credit_card
    @amount = 100

    @options = {
      :device => 'spreedly',
      :application => 'spreedly',
      :developer_id => 'GenkID',
      :billing_address => address(:country => 'US'),
      :shipping_address => address(:country => 'US'),
      :email => 'test@test.com',
      :ip => '127.0.0.1',
      :order_id => '12345'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '8afa688fd002821362;TEST97;100;KKLIHOJKKNKKHJKONJHOLHOL', response.authorization
    assert_equal('TEST97', response.params["approval"])
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal('7605f7c5d6e8f74deb;;100;', response.authorization)
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal('cbf902091334a0b1aa;TEST01;100;KKLIHOJKKNKKHJKONOHCLOIO', response.authorization)
    assert_equal('TEST01', response.params["approval"])
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(1111, "010327153017T10018;502F7B;1111", @options)
    assert_success response

    assert_equal('010327153017T10018;502F6B;1111;', response.authorization)
    assert_equal('502F6B', response.params["approval"])
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    assert response = @gateway.capture(@amount, '7605f7c5d6e8f74deb', @options)
    assert_failure response
    assert_equal 'Transaction Not Found.', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void('010327153x17T10418;502F7B;500', @options)
    assert_success response

    assert_equal('010327153x17T10418;502F7B;500;', response.authorization)
    assert_equal('502F7B', response.params["approval"])
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert void = @gateway.void('bogus', @options)
    assert_failure void
  end

  def test_successful_credit
    card = credit_card('4242424242424242', :verification_value => nil)

    @gateway.expects(:ssl_post).returns(successful_credit_response)

    assert response = @gateway.credit(@amount, card, @options)
    assert_success response
  end

  def test_failed_credit
    card = credit_card('2424242424242424', :verification_value => nil)

    @gateway.expects(:ssl_post).returns(failed_credit_response)

    assert credit = @gateway.credit(@amount, card, @options)
    assert_failure credit
    assert_match %r{Invalid card format}, credit.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_credit_response)

    assert response = @gateway.refund(9900, '010327153017T10017', @options)
    assert_success response

    assert_equal('010327153017T10017;002F6B;9900;', response.authorization)
    assert_equal('002F6B', response.params['approval'])
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert refund = @gateway.refund(@amount, 'bogus', @options)
    assert_failure refund
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert verify = @gateway.verify(@credit_card, @options)
    assert_success verify
  end

  def test_failed_verify
    card = credit_card('2424242424242424', :verification_value => nil)

    @gateway.expects(:ssl_post).returns(failed_credit_response)

    assert verify = @gateway.verify(card, @options)
    assert_failure verify
    assert_match %r{Invalid card format}, verify.message
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'D', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'P', response.cvv_result['code']
  end

  def test_transcript_scrubbing
    assert @gateway.supports_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  def test_purchase_sends_additional_options
    @gateway.expects(:ssl_post).
    with(anything, regexp_matches(/<TaxAmount ExemptInd=\"false\">777<\/TaxAmount>/)).
    with(anything, regexp_matches(/<UDField1>Value1<\/UDField1>/)).
    with(anything, regexp_matches(/<UDField2>Value2<\/UDField2>/)).
    with(anything, regexp_matches(/<UDField3>Value3<\/UDField3>/)).
    returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, {:tax => '777', :ud_field_1 => 'Value1', :ud_field_2 => 'Value2', :ud_field_3 => 'Value3'})
  end

  private

  def successful_purchase_response
    <<-EOF
    <JetPayResponse Version="2.2">
      <TransactionID>8afa688fd002821362</TransactionID>
      <ActionCode>000</ActionCode>
      <Approval>TEST97</Approval>
      <CVV2>P</CVV2>
      <ResponseText>APPROVED</ResponseText>
      <Token>KKLIHOJKKNKKHJKONJHOLHOL</Token>
      <AddressMatch>Y</AddressMatch>
      <ZipMatch>Y</ZipMatch>
      <AVS>D</AVS>
    </JetPayResponse>
    EOF
  end

  def failed_purchase_response
    <<-EOF
      <JetPayResponse Version="2.2">
        <TransactionID>7605f7c5d6e8f74deb</TransactionID>
        <ActionCode>005</ActionCode>
        <ResponseText>DECLINED</ResponseText>
      </JetPayResponse>
    EOF
  end

  def successful_authorize_response
    <<-EOF
      <JetPayResponse Version="2.2">
        <TransactionID>cbf902091334a0b1aa</TransactionID>
        <ActionCode>000</ActionCode>
        <Approval>TEST01</Approval>
        <CVV2>P</CVV2>
        <ResponseText>APPROVED</ResponseText>
        <Token>KKLIHOJKKNKKHJKONOHCLOIO</Token>
        <AddressMatch>Y</AddressMatch>
        <ZipMatch>Y</ZipMatch>
        <AVS>D</AVS>
      </JetPayResponse>
    EOF
  end

  def successful_capture_response
    <<-EOF
      <JetPayResponse Version="2.2">
        <TransactionID>010327153017T10018</TransactionID>
        <ActionCode>000</ActionCode>
        <Approval>502F6B</Approval>
        <ResponseText>APPROVED</ResponseText>
      </JetPayResponse>
    EOF
  end

  def failed_capture_response
    <<-EOF
      <JetPayResponse Version="2.2">
        <TransactionID>010327153017T10018</TransactionID>
        <ActionCode>025</ActionCode>
        <Approval>REJECT</Approval>
        <ResponseText>ED</ResponseText>
      </JetPayResponse>
    EOF
  end

  def successful_void_response
    <<-EOF
      <JetPayResponse Version="2.2">
        <TransactionID>010327153x17T10418</TransactionID>
        <ActionCode>000</ActionCode>
        <Approval>502F7B</Approval>
        <ResponseText>VOID PROCESSED</ResponseText>
      </JetPayResponse>
    EOF
  end

  def failed_void_response
    <<-EOF
      <JetPayResponse Version="2.2">
        <TransactionID>010327153x17T10418</TransactionID>
        <ActionCode>900</ActionCode>
        <ResponseText>INVALID MESSAGE TYPE</ResponseText>
      </JetPayResponse>
    EOF
  end

  def successful_credit_response
    <<-EOF
      <JetPayResponse Version="2.2">
        <TransactionID>010327153017T10017</TransactionID>
        <ActionCode>000</ActionCode>
        <Approval>002F6B</Approval>
        <ResponseText>APPROVED</ResponseText>
      </JetPayResponse>
    EOF
  end

  def failed_credit_response
    <<-EOF
      <JetPayResponse Version="2.2">
        <TransactionID>010327153017T10017</TransactionID>
        <ActionCode>912</ActionCode>
        <ResponseText>INVALID CARD NUMBER</ResponseText>
      </JetPayResponse>
    EOF
  end

  def transcript
    <<-EOF
    <TerminalID>TESTMCC3136X</TerminalID>
    <TransactionType>SALE</TransactionType>
    <TransactionID>e23c963a1247fd7aad</TransactionID>
    <CardNum>4000300020001000</CardNum>
    <CardExpMonth>09</CardExpMonth>
    <CardExpYear>16</CardExpYear>
    <CardName>Longbob Longsen</CardName>
    <CVV2>123</CVV2>
    EOF
  end

  def scrubbed_transcript
    <<-EOF
    <TerminalID>TESTMCC3136X</TerminalID>
    <TransactionType>SALE</TransactionType>
    <TransactionID>e23c963a1247fd7aad</TransactionID>
    <CardNum>[FILTERED]</CardNum>
    <CardExpMonth>09</CardExpMonth>
    <CardExpYear>16</CardExpYear>
    <CardName>Longbob Longsen</CardName>
    <CVV2>[FILTERED]</CVV2>
    EOF
  end
end
