require 'test_helper'

class IatsTransactionTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @gateway = IatsTransactionGateway.new(fixtures(:iats_transaction))
    @card = ActiveMerchant::Billing::CreditCard.new(
      month: '03',
      year: Time.now.year + 1,
      brand: 'visa',
      number: '4111111111111111'
    )
  end

  def test_expiration_validation
    @card.year = 2010
    assert_raises(ArgumentError) do
      @gateway.purchase(100, @card, { zip_code: 'ww' })
    end
  end

  def test_zip_require_field
    assert_raises(ArgumentError) do
      @gateway.purchase(100, @card)
    end
  end

  def test_region_and_host
    assert @gateway.current_host ==
      ActiveMerchant::Billing::IatsTransactionGateway::UK_HOST
    @gateway = IatsTransactionGateway.new(fixtures(:iats_transaction_us))
    assert @gateway.current_host ==
      ActiveMerchant::Billing::IatsTransactionGateway::NA_HOST
  end

  def test_success_purchase
    @gateway.expects(:process_credit_card_v1).returns(Nokogiri::XML(success_purchase_xml))
    assert response = @gateway.purchase(100, @card, { zip_code: 234 })
    assert_instance_of Response, response
    assert_success response
    assert_equal ' OK: 678594:Z', response.message
  end

  def test_reject_purchase
    @gateway.expects(:process_credit_card_v1).returns(
      Nokogiri::XML(reject_purchase_xml))
    assert response = @gateway.purchase(100, @card, { zip_code: 234 })
    assert_instance_of Response, response
    assert_failure response
    assert_equal  ActiveMerchant::Billing::IatsTransactionGateway::REJECT_MESSAGES['15'],
                  response.message
  end

  def test_success_refund
    @gateway.expects(:process_credit_card_refund_with_transaction_id_v1).
      returns(Nokogiri::XML(success_refund_xml))
    assert response = @gateway.refund(100, {total: 123 })
    assert_instance_of Response, response
    assert_success response
    assert_equal ' OK: 1234', response.message
  end

  def test_reject_refund
    @gateway.expects(:process_credit_card_refund_with_transaction_id_v1).
      returns(Nokogiri::XML(reject_refund_xml))
    assert response = @gateway.refund(100, {total: 123 })
    assert_instance_of Response, response
    assert_failure response
    assert_equal ActiveMerchant::Billing::IatsTransactionGateway::REJECT_MESSAGES['39'],
      response.message
  end

  def success_purchase_xml
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <ProcessCreditCardV1Response xmlns="https://www.iatspayments.com/NetGate/">
      <ProcessCreditCardV1Result>
        <IATSRESPONSE xmlns="">
          <STATUS>Success</STATUS>
          <ERRORS/>
          <PROCESSRESULT>
            <AUTHORIZATIONRESULT> OK: 678594:Z
</AUTHORIZATIONRESULT>
            <CUSTOMERCODE/>
            <TRANSACTIONID>A12CFF0
</TRANSACTIONID>
          </PROCESSRESULT>
        </IATSRESPONSE>
      </ProcessCreditCardV1Result>
    </ProcessCreditCardV1Response>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def reject_purchase_xml
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <ProcessCreditCardV1Response xmlns="https://www.iatspayments.com/NetGate/">
      <ProcessCreditCardV1Result>
        <IATSRESPONSE xmlns="">
          <STATUS>Success</STATUS>
          <ERRORS/>
          <PROCESSRESULT>
            <AUTHORIZATIONRESULT> REJECT: 15
</AUTHORIZATIONRESULT>
            <CUSTOMERCODE/>
            <TRANSACTIONID>A12CFF2
</TRANSACTIONID>
          </PROCESSRESULT>
        </IATSRESPONSE>
      </ProcessCreditCardV1Result>
    </ProcessCreditCardV1Response>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def success_refund_xml
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <ProcessCreditCardRefundWithTransactionIdV1Response xmlns="https://www.iatspayments.com/NetGate/">
      <ProcessCreditCardRefundWithTransactionIdV1Result>
        <IATSRESPONSE xmlns="">
          <STATUS>Success</STATUS>
          <ERRORS/>
          <PROCESSRESULT>
            <AUTHORIZATIONRESULT> OK: 1234
</AUTHORIZATIONRESULT>
            <CUSTOMERCODE/>
            <TRANSACTIONID/>
          </PROCESSRESULT>
        </IATSRESPONSE>
      </ProcessCreditCardRefundWithTransactionIdV1Result>
    </ProcessCreditCardRefundWithTransactionIdV1Response>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def reject_refund_xml
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <ProcessCreditCardRefundWithTransactionIdV1Response xmlns="https://www.iatspayments.com/NetGate/">
      <ProcessCreditCardRefundWithTransactionIdV1Result>
        <IATSRESPONSE xmlns="">
          <STATUS>Success</STATUS>
          <ERRORS/>
          <PROCESSRESULT>
            <AUTHORIZATIONRESULT> REJECT: 39
</AUTHORIZATIONRESULT>
            <CUSTOMERCODE/>
            <TRANSACTIONID/>
          </PROCESSRESULT>
        </IATSRESPONSE>
      </ProcessCreditCardRefundWithTransactionIdV1Result>
    </ProcessCreditCardRefundWithTransactionIdV1Response>
  </soap:Body>
</soap:Envelope>
    XML
  end
end
