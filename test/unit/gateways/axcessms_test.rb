require_relative '../../test_helper'

class AxcessmsTest < Test::Unit::TestCase
  include CommStub

  TEST_AUTHORIZATION = '8a8294494830a3bb01483174f1827b9a'
  TEST_PURCHASE = '8a82944a4830c4810148350aeeec5e58'

  def setup
    @gateway = AxcessmsGateway.new(fixtures(:axcessms))

    @amount = 1500
    @credit_card = credit_card("4200000000000000", month: 05, year: 2022)
    @declined_card = credit_card("4444444444444444", month: 05, year: 2022)
    @mode = "CONNECTOR_TEST"

    @options = {
      order_id: generate_unique_id,
      email: "customer@example.com",
      description: "Order Number #{Time.now.to_f.divmod(2473)[1]}",
      ip: "0.0.0.0",
      mode: @mode,
      billing_address: {
        :address1 => "10 Marklar St",
        :address2 => "Musselburgh",
        :city => "Dunedin",
        :zip => "9013",
        :state => "Otago",
        :country => "NZ"
      }
    }
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
    assert_equal TEST_AUTHORIZATION, response.authorization
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
    assert_equal TEST_PURCHASE, response.authorization
  end

  def test_successful_reference_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, '12345', @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
    assert_equal TEST_PURCHASE, response.authorization
  end

  def test_successful_reference_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    assert response = @gateway.authorize(@amount, '12345', @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
    assert_equal TEST_AUTHORIZATION, response.authorization
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(@amount, TEST_AUTHORIZATION, @options)
    assert_success response
    assert response.test?
    assert response.params["reference_id"], TEST_AUTHORIZATION
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert response = @gateway.refund(@amount - 30, TEST_PURCHASE, @options)
    assert_success response
    assert response.test?
    assert response.params["reference_id"], TEST_PURCHASE
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    assert response = @gateway.void(TEST_AUTHORIZATION, @options)
    assert_success response
    assert response.test?
    assert response.params["reference_id"], TEST_AUTHORIZATION
  end

  def test_unauthorized_capture
    @gateway.expects(:ssl_post).returns(unauthorized_capture_response)
    assert response = @gateway.capture(@amount, "authorization", @options)
    assert_failure response
    assert response.params["status"], "REJECTED_VALIDATION"
    assert response.message, "Reference Error - capture needs at least one successful transaction of type (PA)"
    assert response.params["return_code"], "700.400.510"
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(unauthorized_refund_response)
    assert response = @gateway.refund(@amount - 30, "authorization", @options)
    assert_failure response
    assert response.params["status"], "REJECTED_VALIDATION"
    assert response.message, "Configuration Validation - Invalid payment data. You are not configured for this currency or sub type (country or brand)"
    assert response.params["return_code"], "600.200.500"
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(unauthorized_void_response)
    assert response = @gateway.refund(@amount - 30, "authorization", @options)
    assert_failure response
    assert response.params["status"], "REJECTED_VALIDATION"
    assert response.message, "Reference Error - reversal needs at least one successful transaction of type (CP or DB or RB or PA)"
    assert response.params["return_code"], "700.400.530"
  end

  def test_authorization_using_reference_sets_proper_elements
    stub_comms do
      @gateway.authorize(@amount, "MY_AUTHORIZE_VALUE", @options)
    end.check_request do |endpoint, body, headers|
      assert_xpath_text(body, "//ReferenceID", "MY_AUTHORIZE_VALUE")
      assert_no_match(/<Account>/, body)
    end.respond_with(successful_authorization_response)
  end

  def test_purchase_using_reference_sets_proper_elements
    stub_comms do
      @gateway.purchase(@amount, "MY_AUTHORIZE_VALUE", @options)
    end.check_request do |endpoint, body, headers|
      assert_xpath_text(body, "//ReferenceID", "MY_AUTHORIZE_VALUE")
      assert_no_match(/<Account>/, body)
    end.respond_with(successful_authorization_response)
  end

  def test_setting_mode_sets_proper_element
    stub_comms do
      @gateway.purchase(@amount, "MY_AUTHORIZE_VALUE", {mode: "CRAZY_TEST_MODE"})
    end.check_request do |endpoint, body, headers|
      assert_xpath_text(body, "//Transaction/@mode", "CRAZY_TEST_MODE")
    end.respond_with(successful_authorization_response)
  end

  def test_defaults_to_integrator_test
    stub_comms do
      @gateway.purchase(@amount, "MY_AUTHORIZE_VALUE", {})
    end.check_request do |endpoint, body, headers|
      assert_xpath_text(body, "//Transaction/@mode", "INTEGRATOR_TEST")
    end.respond_with(successful_authorization_response)
  end

  private

  def assert_xpath_text(xml, xpath, expected_text)
    xml = CGI.unescape(xml.gsub("load=", ""))
    root = REXML::Document.new(xml).root
    element = REXML::XPath.first(root, xpath)
    actual_text = xpath.include?("@") ? element.value : element.text
    assert_equal expected_text, actual_text, %{Expected to find the text "#{expected_text}" within the XML element with path "#{xpath}", but instead found the text "#{actual_text}" in the following XML:\n#{xml}}
  end

  def successful_authorization_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <Response version="1.0">
        <Transaction mode="INTEGRATOR_TEST" channel="8a82941745bc8b070145bc8d545a0019" response="SYNC">
            <Identification>
                <ShortID>7159.9714.3714</ShortID>
                <UniqueID>8a8294494830a3bb01483174f1827b9a</UniqueID>
                <TransactionID>64ac051ce71ede9fbf6d9d9f17dd43db</TransactionID>
            </Identification>
            <Payment code="CC.PA">
                <Clearing>
                    <Amount>10.00</Amount>
                    <Currency>GBP</Currency>
                    <Descriptor>7159.9714.3714 Recurring </Descriptor>
                    <FxRate>1.0</FxRate>
                    <FxSource>INTERN</FxSource>
                    <FxDate>2014-09-01 13:43:40</FxDate>
                </Clearing>
            </Payment>
            <Processing code="CC.PA.90.00">
                <Timestamp>2014-09-01 13:43:40</Timestamp>
                <Result>ACK</Result>
                <Status code="90">NEW</Status>
                <Reason code="00">Successful Processing</Reason>
                <Return code="000.100.110">Request successfully processed in 'Merchant in Connector Test Mode'</Return>
                <Risk score="100" />
            </Processing>
        </Transaction>
    </Response>
    XML
  end

  def successful_purchase_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <Response version="1.0">
        <Transaction mode="INTEGRATOR_TEST" channel="8a82941745bc8b070145bc8d545a0019" response="SYNC">
            <Identification>
                <ShortID>5120.3652.8802</ShortID>
                <UniqueID>8a82944a4830c4810148350aeeec5e58</UniqueID>
                <TransactionID>38a96c022cafb4ef2e308c119ae34452</TransactionID>
            </Identification>
            <Payment code="CC.DB">
                <Clearing>
                    <Amount>10.00</Amount>
                    <Currency>GBP</Currency>
                    <Descriptor>5120.3652.8802 Recurring </Descriptor>
                    <FxRate>1.0</FxRate>
                    <FxSource>INTERN</FxSource>
                    <FxDate>2014-09-02 06:26:22</FxDate>
                </Clearing>
            </Payment>
            <Processing code="CC.DB.90.00">
                <Timestamp>2014-09-02 06:26:22</Timestamp>
                <Result>ACK</Result>
                <Status code="90">NEW</Status>
                <Reason code="00">Successful Processing</Reason>
                <Return code="000.100.110">Request successfully processed in 'Merchant in Integrator Test Mode'</Return>
                <Risk score="100" />
            </Processing>
        </Transaction>
    </Response>
    XML
  end

  def successful_capture_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <Response version="1.0">
        <Transaction mode="INTEGRATOR_TEST" channel="8a82941745bc8b070145bc8d545a0019" response="SYNC">
            <Identification>
                <ShortID>9318.6958.1986</ShortID>
                <UniqueID>8a8294494830a3bb0148351b6546087a</UniqueID>
                <TransactionID>2a45729f95aec98e263461e124593a50</TransactionID>
                <ReferenceID>8a8294494830a3bb0148351b5c9d086e</ReferenceID>
            </Identification>
            <Payment code="CC.CP">
                <Clearing>
                    <Amount>10.00</Amount>
                    <Currency>GBP</Currency>
                    <Descriptor>9318.6958.1986 Recurring</Descriptor>
                    <FxRate>1.0</FxRate>
                    <FxSource>INTERN</FxSource>
                    <FxDate>2014-09-02 06:44:21</FxDate>
                </Clearing>
            </Payment>
            <Processing code="CC.CP.90.00">
                <Timestamp>2014-09-02 06:44:21</Timestamp>
                <Result>ACK</Result>
                <Status code="90">NEW</Status>
                <Reason code="00">Successful Processing</Reason>
                <Return code="000.100.110">Request successfully processed in 'Merchant in Integrator Test Mode'</Return>
                <Risk score="0" />
            </Processing>
        </Transaction>
    </Response>
    XML
  end

  def successful_refund_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <Response version="1.0">
        <Transaction mode="INTEGRATOR_TEST" channel="8a82941745bc8b070145bc8d545a0019" response="SYNC">
            <Identification>
                <ShortID>8073.1553.0402</ShortID>
                <UniqueID>8a82944a4830c4810148350aeeec5e58</UniqueID>
                <TransactionID>94e8c527be2ffb1c120188b4c9bec521</TransactionID>
                <ReferenceID>8a82944a4830c4810148352533ef630f</ReferenceID>
            </Identification>
            <Payment code="CC.RF">
                <Clearing>
                    <Amount>10.00</Amount>
                    <Currency>GBP</Currency>
                    <Descriptor>8073.1553.0402 Recurring</Descriptor>
                    <FxRate>1.0</FxRate>
                    <FxSource>INTERN</FxSource>
                    <FxDate>2014-09-02 06:55:06</FxDate>
                </Clearing>
            </Payment>
            <Processing code="CC.RF.90.00">
                <Timestamp>2014-09-02 06:55:06</Timestamp>
                <Result>ACK</Result>
                <Status code="90">NEW</Status>
                <Reason code="00">Successful Processing</Reason>
                <Return code="000.100.110">Request successfully processed in 'Merchant in Integrator Test Mode'</Return>
            </Processing>
        </Transaction>
    </Response>
    XML
  end

  def successful_void_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <Response version="1.0">
        <Transaction mode="INTEGRATOR_TEST" channel="8a82941745bc8b070145bc8d545a0019" response="SYNC">
            <Identification>
                <ShortID>7729.5579.2034</ShortID>
                <UniqueID>8a8294494830a3bb01483528826e0adf</UniqueID>
                <TransactionID>c3238be8ddc9dc269766add6d3d1b48f</TransactionID>
                <ReferenceID>8a82944a4830c481014835287b136390</ReferenceID>
            </Identification>
            <Payment code="CC.RV">
                <Clearing>
                    <Amount>10.00</Amount>
                    <Currency>GBP</Currency>
                    <Descriptor>7729.5579.2034 Recurring</Descriptor>
                    <FxRate>1.0</FxRate>
                    <FxSource>INTERN</FxSource>
                    <FxDate>2014-09-02 06:58:40</FxDate>
                </Clearing>
            </Payment>
            <Processing code="CC.RV.90.00">
                <Timestamp>2014-09-02 06:58:40</Timestamp>
                <Result>ACK</Result>
                <Status code="90">NEW</Status>
                <Reason code="00">Successful Processing</Reason>
                <Return code="000.100.110">Request successfully processed in 'Merchant in Integrator Test Mode'</Return>
                <Risk score="0" />
            </Processing>
        </Transaction>
    </Response>
    XML
  end

  def unauthorized_capture_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <Response version="1.0">
        <Transaction mode="INTEGRATOR_TEST" channel="8a82941745bc8b070145bc8d545a0019" response="SYNC">
            <Identification>
                <ShortID>6526.9670.7746</ShortID>
                <UniqueID>8a8294494830a3bb0148352d46c90bdf</UniqueID>
                <TransactionID>0c99fae829450624ba6151bed0957f05</TransactionID>
                <ReferenceID>authorization</ReferenceID>
            </Identification>
            <Payment code="CC.CP" />
            <Processing code="CC.CP.70.30">
                <Timestamp>2014-09-02 07:03:52</Timestamp>
                <Result>NOK</Result>
                <Status code="70">REJECTED_VALIDATION</Status>
                <Reason code="30">Reference Error</Reason>
                <Return code="700.400.510">capture needs at least one successful transaction of type (PA)</Return>
                <Risk score="0" />
            </Processing>
        </Transaction>
    </Response>
    XML
  end

  def unauthorized_refund_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <Response version="1.0">
        <Transaction mode="INTEGRATOR_TEST" channel="8a82941745bc8b070145bc8d545a0019" response="SYNC">
            <Identification>
                <ShortID>3864.0873.5394</ShortID>
                <UniqueID>8a8294494830a3bb0148353097580ca5</UniqueID>
                <TransactionID>2016aa53f62f498a6452ff0be1fbd060</TransactionID>
                <ReferenceID>authorization</ReferenceID>
            </Identification>
            <Payment code="CC.RF" />
            <Processing code="CC.RF.70.10">
                <Timestamp>2014-09-02 07:07:30</Timestamp>
                <Result>NOK</Result>
                <Status code="70">REJECTED_VALIDATION</Status>
                <Reason code="10">Configuration Validation</Reason>
                <Return code="600.200.500">Invalid payment data. You are not configured for this currency or sub type (country or brand)</Return>
            </Processing>
        </Transaction>
    </Response>
    XML
  end

  def unauthorized_void_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <Response version="1.0">
        <Transaction mode="INTEGRATOR_TEST" channel="8a82941745bc8b070145bc8d545a0019" response="SYNC">
            <Identification>
                <ShortID>8395.2778.5122</ShortID>
                <UniqueID>8a82944a4830c4810148353115b96501</UniqueID>
                <TransactionID>abe0ea6036cbf36b1bed45031b3263a7</TransactionID>
                <ReferenceID>authorization</ReferenceID>
            </Identification>
            <Payment code="CC.RV" />
            <Processing code="CC.RV.70.30">
                <Timestamp>2014-09-02 07:08:02</Timestamp>
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