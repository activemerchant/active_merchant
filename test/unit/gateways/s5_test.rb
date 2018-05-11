require 'test_helper'

class S5Test < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = S5Gateway.new(
      sender: 'sender',
      channel: 'channel',
      login: 'login',
      password: 'password'
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

    assert_equal '8a8294494d0a8ecd014d25a71d1502c7', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_recurring_flag
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(recurring: true))
    end.check_request do |endpoint, data, headers|
      assert_match(/Recurrence.*REPEATED/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
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

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure auth
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, '8a8294494d0a8ecd014d25a71d1502c7')
    assert_success response
    assert_match %r{Request successfully processed}, response.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(nil, '')
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert refund = @gateway.refund(@amount, '8a8294494d0a8ecd014d25a71d1502c7')
    assert_success refund
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert void = @gateway.void('8a8294494d0a8ecd014d25a71d1502c7')
    assert_success void
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('')
    assert_failure response
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, failed_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(successful_store_response)

    assert_success response
    assert response.test?
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(failed_store_response)

    assert_failure response
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
    SSL established
    <- "load=<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Request version=\"1.0\">\n  <Header>\n    <Security sender=\"ff80808142b2c03c0142b7a7339603e0\"/>\n  </Header>\n  <Transaction mode=\"CONNECTOR_TEST\" channel=\"ff80808142b2c03c0142b7a7339803e5\">\n    <User login=\"8a82941847c4d0780147cea1d1730dcc\" pwd=\"n3yNMBGK\"/>\n    <Payment code=\"CC.DB\">\n      <Presentation>\n        <Amount>1.00</Amount>\n        <Currency>EUR</Currency>\n        <Usage>Store Purchase</Usage>\n      </Presentation>\n    </Payment>\n    <Account>\n      <Number>4000100011112224</Number>\n      <Holder>Longbob Longsen</Holder>\n      <Brand>visa</Brand>\n      <Expiry year=\"2016\" month=\"9\"/>\n      <Verification>123</Verification>\n    </Account>\n    <Customer>\n      <Contact>\n        <Email/>\n        <Ip/>\n        <Phone>(555)555-5555</Phone>\n      </Contact>\n      <Address>\n        <Street>456 My Street Apt 1</Street>\n        <Zip>K1C2N6</Zip>\n        <City>Ottawa</City>\n        <State>ON</State>\n        <Country>CA</Country>\n      </Address>\n      <Name>\n        <Given>Longbob</Given>\n        <Family>Longsen</Family>\n        <Company/>\n      </Name>\n    </Customer>\n    <Recurrence mode=\"INITIAL\"/>\n  </Transaction>\n</Request>\n"
    )
  end

  def post_scrubbed
    %q(
    SSL established
    <- "load=<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Request version=\"1.0\">\n  <Header>\n    <Security sender=\"ff80808142b2c03c0142b7a7339603e0\"/>\n  </Header>\n  <Transaction mode=\"CONNECTOR_TEST\" channel=\"ff80808142b2c03c0142b7a7339803e5\">\n    <User login=\"8a82941847c4d0780147cea1d1730dcc\" pwd=[FILTERED]/>\n    <Payment code=\"CC.DB\">\n      <Presentation>\n        <Amount>1.00</Amount>\n        <Currency>EUR</Currency>\n        <Usage>Store Purchase</Usage>\n      </Presentation>\n    </Payment>\n    <Account>\n      <Number>[FILTERED]</Number>\n      <Holder>Longbob Longsen</Holder>\n      <Brand>visa</Brand>\n      <Expiry year=\"2016\" month=\"9\"/>\n      <Verification>[FILTERED]</Verification>\n    </Account>\n    <Customer>\n      <Contact>\n        <Email/>\n        <Ip/>\n        <Phone>(555)555-5555</Phone>\n      </Contact>\n      <Address>\n        <Street>456 My Street Apt 1</Street>\n        <Zip>K1C2N6</Zip>\n        <City>Ottawa</City>\n        <State>ON</State>\n        <Country>CA</Country>\n      </Address>\n      <Name>\n        <Given>Longbob</Given>\n        <Family>Longsen</Family>\n        <Company/>\n      </Name>\n    </Customer>\n    <Recurrence mode=\"INITIAL\"/>\n  </Transaction>\n</Request>\n"
    )
  end

  def successful_purchase_response
    <<-RESPONSE
   <Response version="1.0">
       <Transaction mode="CONNECTOR_TEST" channel="ff80808142b2c03c0142b7a7339803e5">
            <Identification>
                <ShortID>8856.7293.6098</ShortID>
                <UniqueID>8a8294494d0a8ecd014d25a71d1502c7</UniqueID>
                <ReferenceID />
            </Identification>
            <Payment code="CC.DB">
                <Clearing>
                    <Amount>1.00</Amount>
                    <Currency>EUR</Currency>
                    <Descriptor>8856.7293.6098 eCommerce Store Purchase</Descriptor>
                    <FxRate>1.0</FxRate>
                    <FxSource>INTERN</FxSource>
                    <FxDate>2015-05-05 19:56:58</FxDate>
                </Clearing>
            </Payment>
            <Processing code="CC.DB.90.00">
                <Timestamp>2015-05-05 19:56:58</Timestamp>
                <Result>ACK</Result>
                <Status code="90">NEW</Status>
                <Reason code="00">Successful Processing</Reason>
                <Return code="000.100.112">Request successfully processed in 'Merchant in Connector Test Mode'</Return>
                <Risk score="-200" />
                <SecurityHash>6b5a52b4b838b174f9c7875d2e97466abf30b224</SecurityHash>
            </Processing>
        </Transaction>
    </Response>
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
    <Response version="1.0">
        <Transaction mode="CONNECTOR_TEST" channel="ff80808142b2c03c0142b7a7339803e5">
            <Identification>
                <ReferenceID />
            </Identification>
            <Payment code="CC.DB" />
            <Processing code="CC.DB.60.95">
                <Timestamp>2015-05-05 20:01:41</Timestamp>
                <Result>NOK</Result>
                <Status code="60">REJECTED_BANK</Status>
                <Reason code="95">Authorization Error</Reason>
                <Return code="800.100.151">transaction declined (invalid card)</Return>
                <InfoMessage>This error is the result of passing: "return_code=800.100.151" in the memo-field of the request</InfoMessage>
                <SecurityHash>957413fda6ffc521c30d46ab880064379c8c2193</SecurityHash>
            </Processing>
        </Transaction>
    </Response>
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
    <Response version="1.0">
        <Transaction mode="CONNECTOR_TEST" channel="ff80808142b2c03c0142b7a7339803e5">
            <Identification>
                <ShortID>5828.7774.1730</ShortID>
                <UniqueID>8a82944a4d0aa282014d25aea9d16729</UniqueID>
                <ReferenceID>8a8294494d0a8ecd014d25aea4850378</ReferenceID>
            </Identification>
            <Payment code="CC.CP">
                <Clearing>
                    <Amount>1.00</Amount>
                    <Currency>EUR</Currency>
                    <Descriptor>5828.7774.1730 eCommerce Store Purchase</Descriptor>
                    <FxRate>1.0</FxRate>
                    <FxSource>INTERN</FxSource>
                    <FxDate>2015-05-05 20:05:13</FxDate>
                </Clearing>
            </Payment>
            <Processing code="CC.CP.90.00">
                <Timestamp>2015-05-05 20:05:13</Timestamp>
                <Result>ACK</Result>
                <Status code="90">NEW</Status>
                <Reason code="00">Successful Processing</Reason>
                <Return code="000.100.112">Request successfully processed in 'Merchant in Connector Test Mode'</Return>
                <Risk score="-100" />
                <SecurityHash>1869f6d5506af35726026a63c8c904d083edb9c4</SecurityHash>
            </Processing>
        </Transaction>
    </Response>
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
    <Response version="1.0">
        <Transaction mode="CONNECTOR_TEST" channel="ff80808142b2c03c0142b7a7339803e5">
            <Identification>
                <ReferenceID />
            </Identification>
            <Payment code="CC.PA" />
            <Processing code="CC.PA.65.78">
                <Timestamp>2015-05-05 20:06:13</Timestamp>
                <Result>NOK</Result>
                <Status code="65">REJECTED_RISK</Status>
                <Reason code="78">External Risk Error</Reason>
                <Return code="100.400.080">authorization failure</Return>
                <InfoMessage>This error is the result of passing: "return_code=100.400.080" in the memo-field of the request</InfoMessage>
                <SecurityHash>08ea8175a66923303c6b4bbb4d70dbbb4253550c</SecurityHash>
            </Processing>
        </Transaction>
    </Response>
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    <Response version="1.0">
        <Transaction mode="CONNECTOR_TEST" channel="ff80808142b2c03c0142b7a7339803e5">
            <Identification>
                <ShortID>1039.8888.8226</ShortID>
                <UniqueID>8a8294494d0a8ecd014d25b069ec03d8</UniqueID>
                <ReferenceID>8a8294494d0a8ecd014d25b063f503c9</ReferenceID>
            </Identification>
            <Payment code="CC.CP">
                <Clearing>
                    <Amount>0.99</Amount>
                    <Currency>EUR</Currency>
                    <Descriptor>1039.8888.8226 eCommerce Store Purchase</Descriptor>
                    <FxRate>1.0</FxRate>
                    <FxSource>INTERN</FxSource>
                    <FxDate>2015-05-05 20:07:08</FxDate>
                </Clearing>
            </Payment>
            <Processing code="CC.CP.90.00">
                <Timestamp>2015-05-05 20:07:08</Timestamp>
                <Result>ACK</Result>
                <Status code="90">NEW</Status>
                <Reason code="00">Successful Processing</Reason>
                <Return code="000.100.112">Request successfully processed in 'Merchant in Connector Test Mode'</Return>
                <Risk score="-100" />
                <SecurityHash>bc4f41acddd19bb70a696d8479c8b165fe2e7e19</SecurityHash>
            </Processing>
        </Transaction>
    </Response>
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
    <Response version="1.0">
        <Transaction mode="CONNECTOR_TEST" channel="ff80808142b2c03c0142b7a7339803e5">
            <Identification>
                <ShortID>1383.4862.6594</ShortID>
                <UniqueID>8a8294494d0a8ecd014d25b1060603f7</UniqueID>
                <ReferenceID />
            </Identification>
            <Payment code="CC.CP" />
            <Processing code="CC.CP.70.35">
                <Timestamp>2015-05-05 20:07:47</Timestamp>
                <Result>NOK</Result>
                <Status code="70">REJECTED_VALIDATION</Status>
                <Reason code="35">Amount Error</Reason>
                <Return code="100.550.300">request contains no amount or too low amount</Return>
                <SecurityHash>6ec0c692bdf08b8de2012af7811b803d603188d6</SecurityHash>
            </Processing>
        </Transaction>
    </Response>
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    <Response version="1.0">
        <Transaction mode="CONNECTOR_TEST" channel="ff80808142b2c03c0142b7a7339803e5">
            <Identification>
                <ShortID>6193.8496.3746</ShortID>
                <UniqueID>8a8294494d0a8ecd014d25b20ded043e</UniqueID>
                <ReferenceID>8a8294494d0a8ecd014d25b208b1042f</ReferenceID>
            </Identification>
            <Payment code="CC.RF">
                <Clearing>
                    <Amount>1.00</Amount>
                    <Currency>EUR</Currency>
                    <Descriptor>6193.8496.3746 eCommerce Store Purchase</Descriptor>
                    <FxRate>1.0</FxRate>
                    <FxSource>INTERN</FxSource>
                    <FxDate>2015-05-05 20:08:55</FxDate>
                </Clearing>
            </Payment>
            <Processing code="CC.RF.90.00">
                <Timestamp>2015-05-05 20:08:55</Timestamp>
                <Result>ACK</Result>
                <Status code="90">NEW</Status>
                <Reason code="00">Successful Processing</Reason>
                <Return code="000.100.112">Request successfully processed in 'Merchant in Connector Test Mode'</Return>
                <SecurityHash>2a42ad4815845fc490788000f47d8133f8c56df5</SecurityHash>
            </Processing>
        </Transaction>
    </Response>
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
    <Response version="1.0">
        <Transaction mode="CONNECTOR_TEST" channel="ff80808142b2c03c0142b7a7339803e5">
            <Identification>
                <ShortID>8663.4558.3266</ShortID>
                <UniqueID>8a82944a4d0aa282014d25b317a6679c</UniqueID>
                <ReferenceID />
            </Identification>
            <Payment code="CC.RF" />
            <Processing code="CC.RF.70.35">
                <Timestamp>2015-05-05 20:10:03</Timestamp>
                <Result>NOK</Result>
                <Status code="70">REJECTED_VALIDATION</Status>
                <Reason code="35">Amount Error</Reason>
                <Return code="100.550.300">request contains no amount or too low amount</Return>
                <SecurityHash>2a3b858866371e35bb6ee50e5edc480e251e6320</SecurityHash>
            </Processing>
        </Transaction>
    </Response>
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    <Response version="1.0">
        <Transaction mode="CONNECTOR_TEST" channel="ff80808142b2c03c0142b7a7339803e5">
            <Identification>
                <ShortID>8083.6352.4770</ShortID>
                <UniqueID>8a8294494d0a8ecd014d25b3a9d3048e</UniqueID>
                <ReferenceID>8a8294494d0a8ecd014d25b3a364047f</ReferenceID>
            </Identification>
            <Payment code="CC.RV">
                <Clearing>
                    <Amount>1.00</Amount>
                    <Currency>EUR</Currency>
                    <Descriptor>8083.6352.4770 eCommerce Store Purchase</Descriptor>
                    <FxRate>1.0</FxRate>
                    <FxSource>INTERN</FxSource>
                    <FxDate>2015-05-05 20:10:40</FxDate>
                </Clearing>
            </Payment>
            <Processing code="CC.RV.90.00">
                <Timestamp>2015-05-05 20:10:41</Timestamp>
                <Result>ACK</Result>
                <Status code="90">NEW</Status>
                <Reason code="00">Successful Processing</Reason>
                <Return code="000.100.112">Request successfully processed in 'Merchant in Connector Test Mode'</Return>
                <Risk score="-100" />
                <SecurityHash>b3bce3318214c86efdf63ad4874db803e9bbaf28</SecurityHash>
            </Processing>
        </Transaction>
    </Response>
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
    <Response version="1.0">
        <Transaction mode="CONNECTOR_TEST" channel="ff80808142b2c03c0142b7a7339803e5">
            <Identification>
                <ShortID>6945.4689.1426</ShortID>
                <UniqueID>8a82944a4d0aa282014d25b4576d67cd</UniqueID>
                <ReferenceID />
            </Identification>
            <Payment code="CC.RV" />
            <Processing code="CC.RV.70.30">
                <Timestamp>2015-05-05 20:11:25</Timestamp>
                <Result>NOK</Result>
                <Status code="70">REJECTED_VALIDATION</Status>
                <Reason code="30">Reference Error</Reason>
                <Return code="700.400.530">reversal needs at least one successful transaction of type (CP or DB or RB or PA)</Return>
                <Risk score="-100" />
                <SecurityHash>06ee4076e8ae7cad6613c3eaf7d8094fccdd5773</SecurityHash>
            </Processing>
        </Transaction>
    </Response>
    RESPONSE
  end

  def successful_store_response
    <<-RESPONSE
      <Response version="1.0">
        <Transaction mode="CONNECTOR_TEST" channel="ff80808142b2c03c0142b7a7339803e5">
            <Identification>
                <ShortID>1901.3386.3074</ShortID>
                <UniqueID>8a8294494e634488014e6a586d91354e</UniqueID>
            </Identification>
            <Payment code="CC.RG" />
            <Account />
            <Processing code="CC.RG.90.00">
                <Timestamp>2015-07-07 21:07:36</Timestamp>
                <Result>ACK</Result>
                <Status code="90">NEW</Status>
                <Reason code="00">Successful Processing</Reason>
                <Return code="000.100.112">Request successfully processed in 'Merchant in Connector Test Mode'</Return>
                <Risk score="-100" />
                <ConfirmationStatus>CONFIRMED</ConfirmationStatus>
                <SecurityHash>1ebb9fc2109729dbfd63f7fe9df7996b20f8d66f</SecurityHash>
            </Processing>
        </Transaction>
      </Response>
    RESPONSE
  end

  def failed_store_response
    <<-RESPONSE
      <Response version="1.0">
        <Transaction mode="CONNECTOR_TEST" channel="ff80808142b2c03c0142b7a7339803e5">
            <Identification>
                <ShortID>1263.6366.5058</ShortID>
                <UniqueID>8a82944a4e6357e2014e6a66adea602a</UniqueID>
            </Identification>
            <Payment code="CC.RG" />
            <Account />
            <Processing code="CC.RG.70.40">
                <Timestamp>2015-07-07 21:23:10</Timestamp>
                <Result>NOK</Result>
                <Status code="70">REJECTED_VALIDATION</Status>
                <Reason code="40">Account Validation</Reason>
                <Return code="100.100.101">invalid creditcard, bank account number or bank name</Return>
                <SecurityHash>ecc63ca63ef074129c8997c8bb94591223f127a4</SecurityHash>
            </Processing>
        </Transaction>
      </Response>
    RESPONSE
  end
end
