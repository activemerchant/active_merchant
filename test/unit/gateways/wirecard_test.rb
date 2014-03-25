# encoding: UTF-8
require 'test_helper'

class WirecardTest < Test::Unit::TestCase
  include CommStub

  TEST_AUTHORIZATION_GUWID = 'C822580121385121429927'
  TEST_PURCHASE_GUWID = 'C865402121385575982910'
  TEST_CAPTURE_GUWID = 'C833707121385268439116'

  def setup
    @gateway = WirecardGateway.new(:login => '', :password => '', :signature => '')
    @credit_card = credit_card('4200000000000000')
    @declined_card = credit_card('4000300011112220')
    @unsupported_card = credit_card('4200000000000000', :brand => :maestro)

    @amount = 111

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Wirecard Purchase',
      :email => 'soleone@example.com'
    }

    @address_without_state = {
      :name     => 'Jim Smith',
      :address1 => '1234 My Street',
      :company  => 'Widgets Inc',
      :city     => 'Ottawa',
      :zip      => 'K12 P2A',
      :country  => 'CA',
      :state    => nil,
    }
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response

    assert_success response
    assert response.test?
    assert_equal TEST_AUTHORIZATION_GUWID, response.authorization
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response

    assert_success response
    assert response.test?
    assert_equal TEST_PURCHASE_GUWID, response.authorization
  end

  def test_wrong_credit_card_authorization
    @gateway.expects(:ssl_post).returns(wrong_creditcard_authorization_response)
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_instance_of Response, response

    assert_failure response
    assert response.test?
    assert_equal TEST_AUTHORIZATION_GUWID, response.authorization
    assert_match /credit card number not allowed in demo mode/i, response.message
    assert_equal '24997', response.params['ErrorCode']
  end

  def test_successful_authorization_and_capture
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal TEST_AUTHORIZATION_GUWID, response.authorization

    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(@amount, response.authorization, @options)
    assert_success response
    assert response.test?
    assert response.message[/this is a demo/i]
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal TEST_PURCHASE_GUWID, response.authorization

    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert response = @gateway.refund(@amount - 30, response.authorization, @options)
    assert_success response
    assert response.test?
    assert_match /All good!/, response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal TEST_PURCHASE_GUWID, response.authorization

    @gateway.expects(:ssl_post).returns(successful_void_response)
    assert response = @gateway.void(response.authorization, @options)
    assert_success response
    assert response.test?
    assert_match /Nice one!/, response.message
  end

  def test_successful_authorization_and_partial_capture
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal TEST_AUTHORIZATION_GUWID, response.authorization

    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(@amount - 10, response.authorization, @options)
    assert_success response
    assert response.test?
    assert response.message[/this is a demo/i]
  end

  def test_unauthorized_capture
    @gateway.expects(:ssl_post).returns(unauthorized_capture_response)
    assert response = @gateway.capture(@amount, "1234567890123456789012", @options)

    assert_failure response
    assert_equal TEST_CAPTURE_GUWID, response.authorization
    assert response.message["Could not find referenced transaction for GuWID 1234567890123456789012."]
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)
    assert response = @gateway.refund(@amount - 30, "TheIdentifcation", @options)
    assert_failure response
    assert_match /Not prudent/, response.message
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    assert response = @gateway.refund(@amount - 30, "TheIdentifcation", @options)
    assert_failure response
    assert_match /Not gonna do it/, response.message
  end

  def test_no_error_if_no_state_is_provided_in_address
    options = @options.merge(:billing_address => @address_without_state)
    @gateway.expects(:ssl_post).returns(unauthorized_capture_response)
    assert_nothing_raised do
      @gateway.authorize(@amount, @credit_card, options)
    end
  end

  def test_no_error_if_no_address_provided
    @options.delete(:billing_address)
    @gateway.expects(:ssl_post).returns(unauthorized_capture_response)
    assert_nothing_raised do
      @gateway.authorize(@amount, @credit_card, @options)
    end
  end

  def test_description_trucated_to_32_chars_in_authorize
    options = { description: "32chars-------------------------EXTRA" }

    stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<FunctionID>32chars-------------------------<\/FunctionID>/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_description_trucated_to_32_chars_in_purchase
    options = { description: "32chars-------------------------EXTRA" }

    stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<FunctionID>32chars-------------------------<\/FunctionID>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_description_is_ascii_encoded_since_wirecard_does_not_like_utf_8
    options = { description: "¿Dónde está la estación?" }

    stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<FunctionID>\?D\?nde est\? la estaci\?n\?<\/FunctionID>/, data)
    end.respond_with(successful_purchase_response)
  end

  private

  # Authorization success
  def successful_authorization_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <WIRECARD_BXML xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance" xsi:noNamespaceSchemaLocation="wirecard.xsd">
    <W_RESPONSE>
      <W_JOB>
        <JobID>test dummy data</JobID>
        <FNC_CC_PREAUTHORIZATION>
          <FunctionID>Wirecard remote test purchase</FunctionID>
          <CC_TRANSACTION>
            <TransactionID>1</TransactionID>
            <PROCESSING_STATUS>
              <GuWID>C822580121385121429927</GuWID>
              <AuthorizationCode>709678</AuthorizationCode>
              <Info>THIS IS A DEMO TRANSACTION USING CREDIT CARD NUMBER 420000****0000. NO REAL MONEY WILL BE TRANSFERED.</Info>
              <StatusType>INFO</StatusType>
              <FunctionResult>ACK</FunctionResult>
              <TimeStamp>2008-06-19 06:53:33</TimeStamp>
            </PROCESSING_STATUS>
          </CC_TRANSACTION>
        </FNC_CC_PREAUTHORIZATION>
      </W_JOB>
  </W_RESPONSE>
</WIRECARD_BXML>
    XML
  end

  # Authorization failure
  # TODO: replace with real xml string here (current way seems to complicated)
  def wrong_creditcard_authorization_response
    error = <<-XML
            <ERROR>
              <Type>DATA_ERROR</Type>
              <Number>24997</Number>
              <Message>Credit card number not allowed in demo mode.</Message>
              <Advice>Only demo card number '4200000000000000' is allowed for VISA in demo mode.</Advice>
            </ERROR>
            XML
    result_node = '</FunctionResult>'
    auth = 'AuthorizationCode'
    successful_authorization_response.gsub('ACK', 'NOK') \
      .gsub(result_node, result_node + error) \
      .gsub(/<#{auth}>\w+<\/#{auth}>/, "<#{auth}><\/#{auth}>") \
      .gsub(/<Info>.+<\/Info>/, '')
  end

  # Capture success
  def successful_capture_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <WIRECARD_BXML xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance" xsi:noNamespaceSchemaLocation="wirecard.xsd">
      <W_RESPONSE>
        <W_JOB>
          <JobID>test dummy data</JobID>
          <FNC_CC_CAPTURE>
            <FunctionID>Wirecard remote test purchase</FunctionID>
            <CC_TRANSACTION>
              <TransactionID>1</TransactionID>
              <PROCESSING_STATUS>
                <GuWID>C833707121385268439116</GuWID>
                <AuthorizationCode>915025</AuthorizationCode>
                <Info>THIS IS A DEMO TRANSACTION USING CREDIT CARD NUMBER 420000****0000. NO REAL MONEY WILL BE TRANSFERED.</Info>
                <StatusType>INFO</StatusType>
                <FunctionResult>ACK</FunctionResult>
                <TimeStamp>2008-06-19 07:18:04</TimeStamp>
              </PROCESSING_STATUS>
            </CC_TRANSACTION>
          </FNC_CC_CAPTURE>
        </W_JOB>
      </W_RESPONSE>
    </WIRECARD_BXML>
    XML
  end

  # Capture failure
  def unauthorized_capture_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <WIRECARD_BXML xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance" xsi:noNamespaceSchemaLocation="wirecard.xsd">
      <W_RESPONSE>
        <W_JOB>
          <JobID>test dummy data</JobID>
          <FNC_CC_CAPTURE>
            <FunctionID>Test dummy FunctionID</FunctionID>
            <CC_TRANSACTION>
              <TransactionID>a2783d471ccc98825b8c498f1a62ce8f</TransactionID>
              <PROCESSING_STATUS>
                <GuWID>C833707121385268439116</GuWID>
                <AuthorizationCode></AuthorizationCode>
                <StatusType>INFO</StatusType>
                <FunctionResult>NOK</FunctionResult>
                <ERROR>
                  <Type>DATA_ERROR</Type>
                  <Number>20080</Number>
                  <Message>Could not find referenced transaction for GuWID 1234567890123456789012.</Message>
                </ERROR>
                <TimeStamp>2008-06-19 08:09:20</TimeStamp>
              </PROCESSING_STATUS>
            </CC_TRANSACTION>
          </FNC_CC_CAPTURE>
        </W_JOB>
      </W_RESPONSE>
    </WIRECARD_BXML>
    XML
  end

  # Purchase success
  def successful_purchase_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <WIRECARD_BXML xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance" xsi:noNamespaceSchemaLocation="wirecard.xsd">
      <W_RESPONSE>
        <W_JOB>
          <JobID>test dummy data</JobID>
          <FNC_CC_PURCHASE>
            <FunctionID>Wirecard remote test purchase</FunctionID>
            <CC_TRANSACTION>
              <TransactionID>1</TransactionID>
              <PROCESSING_STATUS>
                <GuWID>C865402121385575982910</GuWID>
                <AuthorizationCode>531750</AuthorizationCode>
                <Info>THIS IS A DEMO TRANSACTION USING CREDIT CARD NUMBER 420000****0000. NO REAL MONEY WILL BE TRANSFERED.</Info>
                <StatusType>INFO</StatusType>
                <FunctionResult>ACK</FunctionResult>
                <TimeStamp>2008-06-19 08:09:19</TimeStamp>
              </PROCESSING_STATUS>
            </CC_TRANSACTION>
          </FNC_CC_PURCHASE>
        </W_JOB>
      </W_RESPONSE>
    </WIRECARD_BXML>
    XML
  end

  def successful_refund_response
    <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <WIRECARD_BXML xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance" xsi:noNamespaceSchemaLocation="wirecard.xsd">
          <W_RESPONSE>
              <W_JOB>
                <JobID></JobID>
                <FNC_CC_BOOKBACK>
                  <FunctionID></FunctionID>
                  <CC_TRANSACTION>
                    <TransactionID>2a486b3ab747df694d5460c3cb444591</TransactionID>
                    <PROCESSING_STATUS>
                      <GuWID>C898842138247065382261</GuWID>
                      <AuthorizationCode>424492</AuthorizationCode>
                      <Info>All good!</Info>
                      <StatusType>INFO</StatusType>
                      <FunctionResult>ACK</FunctionResult>
                      <TimeStamp>2013-10-22 21:37:33</TimeStamp>
                    </PROCESSING_STATUS>
                  </CC_TRANSACTION>
                </FNC_CC_BOOKBACK>
              </W_JOB>
          </W_RESPONSE>
      </WIRECARD_BXML>
    XML
  end

  def failed_refund_response
    <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <WIRECARD_BXML xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance" xsi:noNamespaceSchemaLocation="wirecard.xsd">
        <W_RESPONSE>
          <W_JOB>
            <JobID></JobID>
            <FNC_CC_BOOKBACK>
              <FunctionID></FunctionID>
              <CC_TRANSACTION>
                  <TransactionID>98680cbeee81d32e94a2b71397ffdf88</TransactionID>
                  <PROCESSING_STATUS>
                    <GuWID>C999187138247102291030</GuWID>
                    <AuthorizationCode></AuthorizationCode>
                    <StatusType>INFO</StatusType>
                    <FunctionResult>NOK</FunctionResult>
                    <ERROR>
                        <Type>DATA_ERROR</Type>
                        <Number>20080</Number>
                        <Message>Not prudent</Message>
                    </ERROR>
                    <TimeStamp>2013-10-22 21:43:42</TimeStamp>
                  </PROCESSING_STATUS>
              </CC_TRANSACTION>
            </FNC_CC_BOOKBACK>
          </W_JOB>
        </W_RESPONSE>
      </WIRECARD_BXML>
    XML
  end

  def successful_void_response
    <<-XML
       <?xml version="1.0" encoding="UTF-8"?>
       <WIRECARD_BXML xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance" xsi:noNamespaceSchemaLocation="wirecard.xsd">
        <W_RESPONSE>
          <W_JOB>
            <JobID></JobID>
            <FNC_CC_REVERSAL>
              <FunctionID></FunctionID>
              <CC_TRANSACTION>
                <TransactionID>5f1a2ab3fb2ed7a6aaa0eea74dc109e2</TransactionID>
                <PROCESSING_STATUS>
                  <GuWID>C907807138247383379288</GuWID>
                  <AuthorizationCode>802187</AuthorizationCode>
                  <Info>Nice one!</Info>
                  <StatusType>INFO</StatusType>
                  <FunctionResult>ACK</FunctionResult>
                  <TimeStamp>2013-10-22 22:30:33</TimeStamp>
                </PROCESSING_STATUS>
              </CC_TRANSACTION>
            </FNC_CC_REVERSAL>
          </W_JOB>
        </W_RESPONSE>
      </WIRECARD_BXML>
    XML
  end

  def failed_void_response
    <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <WIRECARD_BXML xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance" xsi:noNamespaceSchemaLocation="wirecard.xsd">
          <W_RESPONSE>
              <W_JOB>
                <JobID></JobID>
                <FNC_CC_REVERSAL>
                  <FunctionID></FunctionID>
                  <CC_TRANSACTION>
                    <TransactionID>c11154e9395cf03c49bd68ec5c7087cc</TransactionID>
                    <PROCESSING_STATUS>
                      <GuWID>C941776138247400010330</GuWID>
                      <AuthorizationCode></AuthorizationCode>
                      <StatusType>INFO</StatusType>
                      <FunctionResult>NOK</FunctionResult>
                      <ERROR>
                          <Type>DATA_ERROR</Type>
                          <Number>20080</Number>
                          <Message>Not gonna do it</Message>
                      </ERROR>
                      <TimeStamp>2013-10-22 22:33:20</TimeStamp>
                    </PROCESSING_STATUS>
                  </CC_TRANSACTION>
                </FNC_CC_REVERSAL>
              </W_JOB>
          </W_RESPONSE>
      </WIRECARD_BXML>
    XML
  end


  # Purchase failure
  def wrong_creditcard_purchase_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <WIRECARD_BXML xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance" xsi:noNamespaceSchemaLocation="wirecard.xsd">
      <W_RESPONSE>
        <W_JOB>
          <JobID>test dummy data</JobID>
          <FNC_CC_PURCHASE>
            <FunctionID>Wirecard remote test purchase</FunctionID>
            <CC_TRANSACTION>
              <TransactionID>1</TransactionID>
              <PROCESSING_STATUS>
                <GuWID>C824697121385153203112</GuWID>
                <AuthorizationCode></AuthorizationCode>
                <StatusType>INFO</StatusType>
                <FunctionResult>NOK</FunctionResult>
                <ERROR>
                  <Type>DATA_ERROR</Type>                                                    <Number>24997</Number>
                  <Message>Credit card number not allowed in demo mode.</Message>
                  <Advice>Only demo card number '4200000000000000' is allowed for VISA in demo mode.</Advice>
                </ERROR>
                <TimeStamp>2008-06-19 06:58:51</TimeStamp>
              </PROCESSING_STATUS>
            </CC_TRANSACTION>
          </FNC_CC_PURCHASE>
        </W_JOB>
      </W_RESPONSE>
    </WIRECARD_BXML>
    XML
  end
end
