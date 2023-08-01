require 'test_helper'

class FourCsOnlineTest < Test::Unit::TestCase
  def setup
    @gateway = FourCsOnlineGateway.new(merchant_key: 'some_key')
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
    assert_equal '000025', response.authorization
    assert_equal 'Approved', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '000093', response.authorization
    assert_equal 'Approved', response.message
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal nil, response.authorization
    assert_equal 'Declined', response.message
    assert response.test?
  end

  def test_expired_card
    @gateway.expects(:ssl_post).returns(expired_card_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal nil, response.authorization
    assert_equal 'ParameterError', response.params['result_code']
    assert_equal 'Bad Parameter: ExpiryMMYY', response.error_code
    assert response.test?
  end

  private

  def successful_purchase_response
    %(
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <soap:Body>
              <SSISProcessTransactionResponse xmlns="http://equament.com/Schemas/Fmx/ssis">
                  <SSISProcessTransactionResult>OK</SSISProcessTransactionResult>
                  <response>
                      <Invoice>12345</Invoice>
                      <TranId>202109251234</TranId>
                      <ResultCode>OK</ResultCode>
                      <FinancialResultCode>Approved</FinancialResultCode>
                      <Amount>10.00</Amount>
                      <Currency>USD</Currency>
                      <ApprovalCode>000025</ApprovalCode>
                      <HostReference>2123219664647905</HostReference>
                      <BatchId>2123210300203853</BatchId>
                      <AVSResult />
                  </response>
              </SSISProcessTransactionResponse>
          </soap:Body>
      </soap:Envelope>
    )
  end

  def failed_purchase_response
    %(
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <soap:Body>
              <SSISProcessTransactionResponse xmlns="http://equament.com/Schemas/Fmx/ssis">
                  <SSISProcessTransactionResult>OK</SSISProcessTransactionResult>
                  <response>
                      <Invoice>12345</Invoice>
                      <TranId>202109251357</TranId>
                      <ResultCode>OK</ResultCode>
                      <FinancialResultCode>Declined</FinancialResultCode>
                      <Amount>10.00</Amount>
                      <Currency>USD</Currency>
                      <ApprovalCode />
                      <HostReference>2123219856480907</HostReference>
                      <BatchId>2123210300203853</BatchId>
                      <AVSResult />
                  </response>
              </SSISProcessTransactionResponse>
          </soap:Body>
      </soap:Envelope>
    )
  end

  def successful_authorize_response
    %(
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <soap:Body>
              <SSISProcessTransactionResponse xmlns="http://equament.com/Schemas/Fmx/ssis">
                  <SSISProcessTransactionResult>OK</SSISProcessTransactionResult>
                  <response>
                      <Invoice>12345</Invoice>
                      <TranId>202109251401</TranId>
                      <ResultCode>OK</ResultCode>
                      <FinancialResultCode>Approved</FinancialResultCode>
                      <Amount>10.00</Amount>
                      <Currency>USD</Currency>
                      <ApprovalCode>000093</ApprovalCode>
                      <HostReference>2123220080160908</HostReference>
                      <AVSResult />
                  </response>
              </SSISProcessTransactionResponse>
          </soap:Body>
      </soap:Envelope>
    )
  end

  def failed_authorize_response
    %(
    <?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
            <SSISProcessTransactionResponse xmlns="http://equament.com/Schemas/Fmx/ssis">
                <SSISProcessTransactionResult>OK</SSISProcessTransactionResult>
                <response>
                    <Invoice>12345</Invoice>
                    <TranId>202109251403</TranId>
                    <ResultCode>OK</ResultCode>
                    <FinancialResultCode>Declined</FinancialResultCode>
                    <Amount>10.00</Amount>
                    <Currency>USD</Currency>
                    <ApprovalCode />
                    <HostReference>2123220186990909</HostReference>
                    <AVSResult />
                </response>
            </SSISProcessTransactionResponse>
        </soap:Body>
    </soap:Envelope>
    )
  end

  def expired_card_response
    %(
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <soap:Body>
              <SSISProcessTransactionResponse xmlns="http://equament.com/Schemas/Fmx/ssis">
                  <SSISProcessTransactionResult>OK</SSISProcessTransactionResult>
                  <response>
                      <ErrorMessage>Bad Parameter: ExpiryMMYY</ErrorMessage>
                      <ResultCode>ParameterError</ResultCode>
                      <FinancialResultCode>Incomplete</FinancialResultCode>
                      <Amount>0</Amount>
                  </response>
              </SSISProcessTransactionResponse>
          </soap:Body>
      </soap:Envelope>
    )
  end
end
