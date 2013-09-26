require 'test_helper'

class PayGateTest < Test::Unit::TestCase
  def setup
    @gateway = PayGateXmlGateway.new(fixtures(:pay_gate_xml))

    @amount = 245000
    @credit_card    = credit_card('4000000000000002')
    @declined_card  = credit_card('4000000000000036')

    @options = {
      :order_id         => 'abc123',
      :billing_address  => address,
      :description      => 'Store Purchase',
    }
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '16996548', response.authorization
    assert response.test?
  end


  def test_successful_settlement
    @gateway.expects(:ssl_post).returns(successful_settlement_response)

    assert response = @gateway.capture(@amount, '16996548', @options)
    assert_instance_of Response, response
    assert_success response

    assert response.test?
  end


  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  # Place raw successful response from gateway here
  def successful_authorization_response
    <<-ENDOFXML
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE protocol SYSTEM "https://www.paygate.co.za/payxml/payxml_v4.dtd">
    <protocol ver="4.0" pgid="10011021600" pwd="test" >
      <authrx tid="16996548" cref="abc123" stat="1" sdesc="Approved" res="990017" rdesc="Auth Done" auth="00209699" bno="0" risk="XX" ctype="1" />
    </protocol>
    ENDOFXML
  end

  # Place raw successful response from gateway here
  def successful_settlement_response
    <<-ENDOFXML
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE protocol SYSTEM "https://www.paygate.co.za/payxml/payxml_v4.dtd">
    <protocol ver="4.0" pgid="10011021600" pwd="test" >
      <settlerx res='990004' bno='0' tid='16996548' cref='abc123' rdesc='Request for Settlement Received' sdesc='Received by Paygate' stat='5'/>
    </protocol>
    ENDOFXML
  end

  # Place raw failed response from gateway here
  def failed_authorization_response
    <<-ENDOFXML
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE protocol SYSTEM "https://www.paygate.co.za/payxml/payxml_v4.dtd">
    <protocol ver="4.0" pgid="10011021600" pwd="test" >
      <errorrx edesc='Transaction ID Must Only Contain Digits' ecode='9'/>
    </protocol>
    ENDOFXML
  end


end
