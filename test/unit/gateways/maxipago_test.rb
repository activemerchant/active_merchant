require 'test_helper'

class MaxipagoTest < Test::Unit::TestCase
  def setup
    @gateway = MaxipagoGateway.new(
      :login => 'login',
      :password => 'password'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
      :installments => 3
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '123456789', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'C0A8013F:014455FCC857:91A0:01A7243E', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(nil, "authorization", @options)
    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(nil, "bogus", @options)
    assert_failure response
  end

  private

  def successful_purchase_response
    %(
      <transaction-response>
        <authCode>555555</authCode>
        <orderID>123456789</orderID>
        <referenceNum>123456789</referenceNum>
        <transactionID>123456789</transactionID>
        <transactionTimestamp>123456789</transactionTimestamp>
        <responseCode>0</responseCode>
        <responseMessage>CAPTURED</responseMessage>
        <avsResponseCode/>
        <cvvResponseCode/>
        <processorCode>0</processorCode>
        <processorMessage>APPROVED</processorMessage>
        <errorMessage/>
        <processorTransactionID>123456789</processorTransactionID>
        <processorReferenceNumber>123456789</processorReferenceNumber>
        <fraudScore>29</fraudScore>
      </transaction-response>
    )
  end

  def failed_purchase_response
    %(
      <transaction-response>
        <authCode/>
        <orderID>123456789</orderID>
        <referenceNum>123456789</referenceNum>
        <transactionID>123456789</transactionID>
        <transactionTimestamp>123456789</transactionTimestamp>
        <responseCode>1</responseCode>
        <responseMessage>DECLINED</responseMessage>
        <avsResponseCode>NNN</avsResponseCode>
        <cvvResponseCode>N</cvvResponseCode>
        <processorCode>D</processorCode>
        <processorMessage>DECLINED</processorMessage>
        <errorMessage/>
      </transaction-response>
    )
  end

  def successful_authorize_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <transaction-response>
        <authCode>123456</authCode>
        <orderID>C0A8013F:014455FCC857:91A0:01A7243E</orderID>
        <referenceNum>12345</referenceNum>
        <transactionID>663921</transactionID>
        <transactionTimestamp>1393012206</transactionTimestamp>
        <responseCode>0</responseCode>
        <responseMessage>AUTHORIZED</responseMessage>
        <avsResponseCode>YYY</avsResponseCode>
        <cvvResponseCode>M</cvvResponseCode>
        <processorCode>A</processorCode>
        <processorMessage>APPROVED</processorMessage>
        <errorMessage/>
      </transaction-response>
    )
  end

  def failed_authorize_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <transaction-response>
        <authCode/>
        <orderID/>
        <referenceNum/>
        <transactionID/>
        <transactionTimestamp>1393012170003</transactionTimestamp>
        <responseCode>1024</responseCode>
        <responseMessage>INVALID REQUEST</responseMessage>
        <avsResponseCode/>
        <cvvResponseCode/>
        <processorCode/>
        <processorMessage/>
        <errorMessage>The transaction has an expired credit card.</errorMessage>
      </transaction-response>
    )
  end

  def successful_capture_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <transaction-response>
        <authCode/>
        <orderID>C0A8013F:014455FF974D:82CA:01C7717B</orderID>
        <referenceNum>12345</referenceNum>
        <transactionID>663924</transactionID>
        <transactionTimestamp>1393012391</transactionTimestamp>
        <responseCode>0</responseCode>
        <responseMessage>CAPTURED</responseMessage>
        <avsResponseCode/>
        <cvvResponseCode/>
        <processorCode>A</processorCode>
        <processorMessage>APPROVED</processorMessage>
        <errorMessage/>
      </transaction-response>
    )
  end

  def failed_capture_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <transaction-response>
        <authCode/>
        <orderID/>
        <referenceNum/>
        <transactionID/>
        <transactionTimestamp>1393012277035</transactionTimestamp>
        <responseCode>1024</responseCode>
        <responseMessage>INVALID REQUEST</responseMessage>
        <avsResponseCode/>
        <cvvResponseCode/>
        <processorCode/>
        <processorMessage/>
        <errorMessage>Reference Number is a required field.</errorMessage>
      </transaction-response>
    )
  end
end
