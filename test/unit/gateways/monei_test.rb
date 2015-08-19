require 'test_helper'

class MoneiTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = MoneiGateway.new(
      :sender_id => 'mother',
      :channel_id => 'there is no other',
      :login => 'like mother',
      :pwd => 'so treat Her right'
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

    assert_equal '8a829449488d79090148996c441551fb', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(nil, '')
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('')
    assert_failure response
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
  end

  private

  def successful_purchase_response
    return <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<Response version="1.0">
    <Transaction mode="CONNECTOR_TEST" channel="8a82941746287806014698a0e3240575" response="SYNC">
        <Identification>
            <ShortID>7621.0198.1858</ShortID>
            <UniqueID>8a829449488d79090148996c441551fb</UniqueID>
            <TransactionID>1</TransactionID>
        </Identification>
        <Payment code="CC.DB">
            <Clearing>
                <Amount>1.00</Amount>
                <Currency>EUR</Currency>
                <Descriptor>7621.0198.1858 DEFAULT Store Purchase</Descriptor>
                <FxRate>1.0</FxRate>
                <FxSource>INTERN</FxSource>
                <FxDate>2014-09-21 18:14:42</FxDate>
            </Clearing>
        </Payment>
        <Processing code="CC.DB.90.00">
            <Timestamp>2014-09-21 18:14:42</Timestamp>
            <Result>ACK</Result>
            <Status code="90">NEW</Status>
            <Reason code="00">Successful Processing</Reason>
            <Return code="000.100.112">Request successfully processed in 'Merchant in Connector Test Mode'</Return>
            <Risk score="0" />
        </Processing>
    </Transaction>
</Response>
    XML
  end

  def failed_purchase_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<Response version="1.0">
    <Transaction mode="CONNECTOR_TEST" channel="8a82943746287806014628a0e3240575" response="SYNC">
        <Identification>
            <ShortID>9086.6774.0834</ShortID>
            <UniqueID>8a82944a488d36c101489972b0ee6ace</UniqueID>
            <TransactionID>1</TransactionID>
        </Identification>
        <Payment code="CC.DB" />
        <Processing code="CC.DB.70.40">
            <Timestamp>2014-09-21 18:21:43</Timestamp>
            <Result>NOK</Result>
            <Status code="70">REJECTED_VALIDATION</Status>
            <Reason code="40">Account Validation</Reason>
            <Return code="100.100.700">invalid cc number/brand combination</Return>
        </Processing>
    </Transaction>
</Response>
    XML
  end

  def successful_authorize_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<Response version="1.0">
    <Transaction mode="CONNECTOR_TEST" channel="8a82941746487806014628a0e3240575" response="SYNC">
        <Identification>
            <ShortID>6853.2944.1442</ShortID>
            <UniqueID>8a82944a488d36c101489976f0cc6b1c</UniqueID>
            <TransactionID>1</TransactionID>
        </Identification>
        <Payment code="CC.PA">
            <Clearing>
                <Amount>1.00</Amount>
                <Currency>EUR</Currency>
                <Descriptor>6853.2944.1442 DEFAULT Store Purchase</Descriptor>
                <FxRate>1.0</FxRate>
                <FxSource>INTERN</FxSource>
                <FxDate>2014-09-21 18:26:22</FxDate>
            </Clearing>
        </Payment>
        <Processing code="CC.PA.90.00">
            <Timestamp>2014-09-21 18:26:22</Timestamp>
            <Result>ACK</Result>
            <Status code="90">NEW</Status>
            <Reason code="00">Successful Processing</Reason>
            <Return code="000.100.112">Request successfully processed in 'Merchant in Connector Test Mode'</Return>
            <Risk score="0" />
        </Processing>
    </Transaction>
</Response>
    XML
  end

  def failed_authorize_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<Response version="1.0">
    <Transaction mode="CONNECTOR_TEST" channel="8a82941746287806014628a0e3240575" response="SYNC">
        <Identification>
            <ShortID>4727.2856.0290</ShortID>
            <UniqueID>8a829449488d79090148998943a853f6</UniqueID>
            <TransactionID>1</TransactionID>
        </Identification>
        <Payment code="CC.PA" />
        <Processing code="CC.PA.70.40">
            <Timestamp>2014-09-21 18:46:22</Timestamp>
            <Result>NOK</Result>
            <Status code="70">REJECTED_VALIDATION</Status>
            <Reason code="40">Account Validation</Reason>
            <Return code="100.100.700">invalid cc number/brand combination</Return>
        </Processing>
    </Transaction>
</Response>
    XML
  end

  def successful_capture_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<Response version="1.0">
    <Transaction mode="CONNECTOR_TEST" channel="8a82941746287806014628a0e3240575" response="SYNC">
        <Identification>
            <ShortID>1269.8369.2962</ShortID>
            <UniqueID>8a82944a488d36c10148998d9b316cc6</UniqueID>
            <TransactionID />
            <ReferenceID>8a829449488d79090148998d97f05439</ReferenceID>
        </Identification>
        <Payment code="CC.CP">
            <Clearing>
                <Amount>1.00</Amount>
                <Currency>EUR</Currency>
                <Descriptor>1269.8369.2962 DEFAULT Store Purchase</Descriptor>
                <FxRate>1.0</FxRate>
                <FxSource>INTERN</FxSource>
                <FxDate>2014-09-21 18:51:07</FxDate>
            </Clearing>
        </Payment>
        <Processing code="CC.CP.90.00">
            <Timestamp>2014-09-21 18:51:07</Timestamp>
            <Result>ACK</Result>
            <Status code="90">NEW</Status>
            <Reason code="00">Successful Processing</Reason>
            <Return code="000.100.112">Request successfully processed in 'Merchant in Connector Test Mode'</Return>
            <Risk score="0" />
        </Processing>
    </Transaction>
</Response>
    XML
  end

  def failed_capture_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<Response version="1.0">
    <Transaction mode="CONNECTOR_TEST" channel="8a82941746287806014628a0e3240575" response="SYNC">
        <Identification>
            <ShortID>0239.0447.7858</ShortID>
            <UniqueID>8a82944a488d36c10148998fc4b66cfc</UniqueID>
            <TransactionID />
            <ReferenceID />
        </Identification>
        <Payment code="CC.CP" />
        <Processing code="CC.CP.70.20">
            <Timestamp>2014-09-21 18:53:29</Timestamp>
            <Result>NOK</Result>
            <Status code="70">REJECTED_VALIDATION</Status>
            <Reason code="20">Format Error</Reason>
            <Return code="200.100.302">invalid Request/Transaction/Payment/Presentation tag (not present or [partially] empty)</Return>
        </Processing>
    </Transaction>
</Response>
    XML
  end

  def successful_refund_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<Response version="1.0">
    <Transaction mode="CONNECTOR_TEST" channel="8a82941746287806014628a0e3240575" response="SYNC">
        <Identification>
            <ShortID>3009.2986.8450</ShortID>
            <UniqueID>8a829449488d790901489992a493546f</UniqueID>
            <TransactionID />
            <ReferenceID>8a82944a488d36c101489992a10f6d21</ReferenceID>
        </Identification>
        <Payment code="CC.RF">
            <Clearing>
                <Amount>1.00</Amount>
                <Currency>EUR</Currency>
                <Descriptor>3009.2986.8450 DEFAULT Store Purchase</Descriptor>
                <FxRate>1.0</FxRate>
                <FxSource>INTERN</FxSource>
                <FxDate>2014-09-21 18:56:37</FxDate>
            </Clearing>
        </Payment>
        <Processing code="CC.RF.90.00">
            <Timestamp>2014-09-21 18:56:37</Timestamp>
            <Result>ACK</Result>
            <Status code="90">NEW</Status>
            <Reason code="00">Successful Processing</Reason>
            <Return code="000.100.112">Request successfully processed in 'Merchant in Connector Test Mode'</Return>
        </Processing>
    </Transaction>
</Response>
    XML
  end

  def failed_refund_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<Response version="1.0">
    <Transaction mode="CONNECTOR_TEST" channel="8a82941746287806014628a0e3240575" response="SYNC">
        <Identification>
            <ShortID>5070.8829.8658</ShortID>
            <UniqueID>8a829449488d790901489994b2c65481</UniqueID>
            <TransactionID />
            <ReferenceID />
        </Identification>
        <Payment code="CC.RF" />
        <Processing code="CC.RF.70.20">
            <Timestamp>2014-09-21 18:58:52</Timestamp>
            <Result>NOK</Result>
            <Status code="70">REJECTED_VALIDATION</Status>
            <Reason code="20">Format Error</Reason>
            <Return code="200.100.302">invalid Request/Transaction/Payment/Presentation tag (not present or [partially] empty)</Return>
        </Processing>
    </Transaction>
</Response>
    XML
  end

  def successful_void_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<Response version="1.0">
    <Transaction mode="CONNECTOR_TEST" channel="8a82941746287806014628a0e3240575" response="SYNC">
        <Identification>
            <ShortID>4587.6991.6578</ShortID>
            <UniqueID>8a82944a488d36c1014899957fff6d49</UniqueID>
            <TransactionID />
            <ReferenceID>8a829449488d7909014899957cb45486</ReferenceID>
        </Identification>
        <Payment code="CC.RV">
            <Clearing>
                <Amount>1.00</Amount>
                <Currency>EUR</Currency>
                <Descriptor>4587.6991.6578 DEFAULT Store Purchase</Descriptor>
                <FxRate>1.0</FxRate>
                <FxSource>INTERN</FxSource>
                <FxDate>2014-09-21 18:59:44</FxDate>
            </Clearing>
        </Payment>
        <Processing code="CC.RV.90.00">
            <Timestamp>2014-09-21 18:59:44</Timestamp>
            <Result>ACK</Result>
            <Status code="90">NEW</Status>
            <Reason code="00">Successful Processing</Reason>
            <Return code="000.100.112">Request successfully processed in 'Merchant in Connector Test Mode'</Return>
            <Risk score="0" />
        </Processing>
    </Transaction>
</Response>
    XML
  end

  def failed_void_response
    <<-XML
<Response version="1.0">
    <Transaction mode="CONNECTOR_TEST" channel="8a82941746287806014628a0e3240575" response="SYNC">
        <Identification>
            <ShortID>5843.9770.9986</ShortID>
            <UniqueID>8a829449488d7909014899965cd354b6</UniqueID>
            <TransactionID />
            <ReferenceID />
        </Identification>
        <Payment code="CC.RV" />
        <Processing code="CC.RV.70.30">
            <Timestamp>2014-09-21 19:00:41</Timestamp>
            <Result>NOK</Result>
            <Status code="70">REJECTED_VALIDATION</Status>
            <Reason code="30">Reference Error</Reason>
            <Return code="700.400.530">reversal needs at least one successful transaction of type (CP or DB or RB or PA)</Return>
            <Risk score="0" />
        </Processing>
    </Transaction>
</Response>
    XML
  end
end
