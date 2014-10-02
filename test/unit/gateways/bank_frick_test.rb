require 'test_helper'

class BankFrickTest < Test::Unit::TestCase
  def setup
    @gateway = BankFrickGateway.new(
      sender: 'sender-uuid',
      channel: 'channel-uuid',
      userid: 'user-uuid',
      userpwd: 'password',
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
    assert_equal '8a82944948642b6401486524e8637d97', response.authorization
    assert response.test?
    assert_match %r{Transaction succeeded}, response.message
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{account or user is blacklisted}, response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_match %r{Transaction succeeded}, response.message
    assert response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'account or user is blacklisted', response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, '8a82944948642b6401486524e8637d97')
    assert_success response
    assert_match %r{Transaction succeeded}, response.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(nil, '')
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert refund = @gateway.refund(@amount, '8a82944948642b6401486524e8637d97')
    assert_success refund
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert void = @gateway.void('8a82944948642b6401486524e8637d97')
    assert_success void
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('')
    assert_failure response
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).twice.returns(successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Transaction succeeded}, response.message
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
  end

  private

  def successful_purchase_response
    %(
<Response version="1.0">
    <Transaction mode="LIVE" channel="8a829417480cfaf601481b94906b220c" response="SYNC">
        <Identification>
            <ShortID>4884.5929.7442</ShortID>
            <UniqueID>8a82944948642b6401486524e8637d97</UniqueID>
        </Identification>
        <Payment code="CC.DB">
            <Clearing>
                <Amount>1.00</Amount>
                <Currency>EUR</Currency>
                <Descriptor>4884.5929.7442 Payment Principals cards Store Purchase</Descriptor>
                <FxRate>1.0</FxRate>
                <FxSource>INTERN</FxSource>
                <FxDate>2014-09-11 14:36:30</FxDate>
            </Clearing>
        </Payment>
        <Processing code="CC.DB.90.00">
            <Timestamp>2014-09-11 14:36:30</Timestamp>
            <Result>ACK</Result>
            <Status code="90">NEW</Status>
            <Reason code="00">Successful Processing</Reason>
            <Return code="000.000.000">Transaction succeeded</Return>
            <Risk score="0" />
        </Processing>
    </Transaction>
</Response>
    )
  end

  def failed_purchase_response
    %(
<Response version="1.0">
    <Transaction mode="LIVE" channel="8a829417480cfaf601481b94906b220c" response="SYNC">
        <Identification>
            <ShortID>6709.9540.7522</ShortID>
            <UniqueID>8a82944a486446ed0148652bb89567dc</UniqueID>
        </Identification>
        <Payment code="CC.DB" />
        <Processing code="CC.DB.65.50">
            <Timestamp>2014-09-11 14:43:57</Timestamp>
            <Result>NOK</Result>
            <Status code="65">REJECTED_RISK</Status>
            <Reason code="50">Blacklist Validation</Reason>
            <Return code="800.300.101">account or user is blacklisted</Return>
            <Risk score="-100" />
        </Processing>
    </Transaction>
</Response>
      )
  end

  def successful_authorize_response
    %(
<Response version="1.0">
    <Transaction mode="LIVE" channel="8a829417480cfaf601481b94906b220c" response="SYNC">
        <Identification>
            <ShortID>3231.0305.6546</ShortID>
            <UniqueID>8a82944a486446ed0148652d337268c1</UniqueID>
        </Identification>
        <Payment code="CC.PA">
            <Clearing>
                <Amount>1.00</Amount>
                <Currency>EUR</Currency>
                <Descriptor>3231.0305.6546 Payment Principals cards Store Purchase</Descriptor>
                <FxRate>1.0</FxRate>
                <FxSource>INTERN</FxSource>
                <FxDate>2014-09-11 14:45:34</FxDate>
            </Clearing>
        </Payment>
        <Processing code="CC.PA.90.00">
            <Timestamp>2014-09-11 14:45:34</Timestamp>
            <Result>ACK</Result>
            <Status code="90">NEW</Status>
            <Reason code="00">Successful Processing</Reason>
            <Return code="000.000.000">Transaction succeeded</Return>
            <Risk score="0" />
        </Processing>
    </Transaction>
</Response>
      )
  end

  def failed_authorize_response
    %(
<Response version="1.0">
    <Transaction mode="LIVE" channel="8a829417480cfaf601481b94906b220c" response="SYNC">
        <Identification>
            <ShortID>1244.6081.9106</ShortID>
            <UniqueID>8a82944948642b640148652ee86202fe</UniqueID>
        </Identification>
        <Payment code="CC.PA" />
        <Processing code="CC.PA.65.50">
            <Timestamp>2014-09-11 14:47:26</Timestamp>
            <Result>NOK</Result>
            <Status code="65">REJECTED_RISK</Status>
            <Reason code="50">Blacklist Validation</Reason>
            <Return code="800.300.101">account or user is blacklisted</Return>
            <Risk score="-100" />
        </Processing>
    </Transaction>
</Response>
      )
  end

  def successful_capture_response
    %(
<Response version="1.0">
    <Transaction mode="LIVE" channel="8a829417480cfaf601481b94906b220c" response="SYNC">
        <Identification>
            <ShortID>5603.9999.9650</ShortID>
            <UniqueID>8a82944a486446ed014865309b3c6c64</UniqueID>
            <ReferenceID>8a82944948642b6401486530960d04ad</ReferenceID>
        </Identification>
        <Payment code="CC.CP">
            <Clearing>
                <Amount>1.00</Amount>
                <Currency>EUR</Currency>
                <Descriptor>5603.9999.9650 Payment Principals cards Store Purchase</Descriptor>
                <FxRate>1.0</FxRate>
                <FxSource>INTERN</FxSource>
                <FxDate>2014-09-11 14:49:17</FxDate>
            </Clearing>
        </Payment>
        <Processing code="CC.CP.90.00">
            <Timestamp>2014-09-11 14:49:17</Timestamp>
            <Result>ACK</Result>
            <Status code="90">NEW</Status>
            <Reason code="00">Successful Processing</Reason>
            <Return code="000.000.000">Transaction succeeded</Return>
            <Risk score="0" />
        </Processing>
    </Transaction>
</Response>
      )
  end

  def failed_capture_response
    %(
<Response version="1.0">
    <Transaction mode="LIVE" channel="8a829417480cfaf601481b94906b220c" response="SYNC">
        <Identification>
            <ShortID>3456.5163.4850</ShortID>
            <UniqueID>8a82944a486446ed01486532dcf66e22</UniqueID>
            <ReferenceID />
        </Identification>
        <Payment code="CC.CP" />
        <Processing code="CC.CP.70.35">
            <Timestamp>2014-09-11 14:51:45</Timestamp>
            <Result>NOK</Result>
            <Status code="70">REJECTED_VALIDATION</Status>
            <Reason code="35">Amount Error</Reason>
            <Return code="100.550.300">request contains no amount or too low amount</Return>
        </Processing>
    </Transaction>
</Response>
      )
  end

  def successful_refund_response
    %(
<Response version="1.0">
    <Transaction mode="LIVE" channel="8a829417480cfaf601481b94906b220c" response="SYNC">
        <Identification>
            <ShortID>5437.5700.1378</ShortID>
            <UniqueID>8a82944948642b64014865347aef07eb</UniqueID>
            <ReferenceID>8a82944a486446ed01486534758f6f85</ReferenceID>
        </Identification>
        <Payment code="CC.RF">
            <Clearing>
                <Amount>1.00</Amount>
                <Currency>EUR</Currency>
                <Descriptor>5437.5700.1378 Payment Principals cards Store Purchase</Descriptor>
                <FxRate>1.0</FxRate>
                <FxSource>INTERN</FxSource>
                <FxDate>2014-09-11 14:53:31</FxDate>
            </Clearing>
        </Payment>
        <Processing code="CC.RF.90.00">
            <Timestamp>2014-09-11 14:53:31</Timestamp>
            <Result>ACK</Result>
            <Status code="90">NEW</Status>
            <Reason code="00">Successful Processing</Reason>
            <Return code="000.000.000">Transaction succeeded</Return>
            <Risk score="0" />
        </Processing>
    </Transaction>
</Response>
      )
  end

  def failed_refund_response
    %(
<Response version="1.0">
    <Transaction mode="LIVE" channel="8a829417480cfaf601481b94906b220c" response="SYNC">
        <Identification>
            <ShortID>6248.2450.9090</ShortID>
            <UniqueID>8a82944a486446ed0148653681ea713b</UniqueID>
            <ReferenceID />
        </Identification>
        <Payment code="CC.RF" />
        <Processing code="CC.RF.70.35">
            <Timestamp>2014-09-11 14:55:44</Timestamp>
            <Result>NOK</Result>
            <Status code="70">REJECTED_VALIDATION</Status>
            <Reason code="35">Amount Error</Reason>
            <Return code="100.550.300">request contains no amount or too low amount</Return>
        </Processing>
    </Transaction>
</Response>
      )
  end

  def successful_void_response
    %(
<Response version="1.0">
    <Transaction mode="LIVE" channel="8a829417480cfaf601481b94906b220c" response="SYNC">
        <Identification>
            <ShortID>7305.8807.8754</ShortID>
            <UniqueID>8a82944a486446ed014865398749724c</UniqueID>
            <ReferenceID>8a82944a486446ed014865398203723d</ReferenceID>
        </Identification>
        <Payment code="CC.RV">
            <Clearing>
                <Amount>1.00</Amount>
                <Currency>EUR</Currency>
                <Descriptor>7305.8807.8754 Payment Principals cards Store Purchase</Descriptor>
                <FxRate>1.0</FxRate>
                <FxSource>INTERN</FxSource>
                <FxDate>2014-09-11 14:59:02</FxDate>
            </Clearing>
        </Payment>
        <Processing code="CC.RV.90.00">
            <Timestamp>2014-09-11 14:59:02</Timestamp>
            <Result>ACK</Result>
            <Status code="90">NEW</Status>
            <Reason code="00">Successful Processing</Reason>
            <Return code="000.000.000">Transaction succeeded</Return>
            <Risk score="0" />
        </Processing>
    </Transaction>
</Response>
      )
  end

  def failed_void_response
    %(
<Response version="1.0">
    <Transaction mode="LIVE" channel="8a829417480cfaf601481b94906b220c" response="SYNC">
        <Identification>
            <ShortID>4192.0294.9794</ShortID>
            <UniqueID>8a82944948642b640148653bc3370c7e</UniqueID>
            <ReferenceID />
        </Identification>
        <Payment code="CC.RV" />
        <Processing code="CC.RV.70.30">
            <Timestamp>2014-09-11 15:01:28</Timestamp>
            <Result>NOK</Result>
            <Status code="70">REJECTED_VALIDATION</Status>
            <Reason code="30">Reference Error</Reason>
            <Return code="700.400.530">reversal needs at least one successful transaction of type (CP or DB or RB or PA)</Return>
            <Risk score="0" />
        </Processing>
    </Transaction>
</Response>
      )
  end
end
