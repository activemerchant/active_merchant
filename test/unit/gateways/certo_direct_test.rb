require 'test_helper'

class CertoDirectTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CertoDirectGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    @amount = 100
    @credit_card = credit_card
    @options = {
      :billing_address => {
        :address1 => 'Infinite Loop 1',
        :country => 'US',
        :state => 'TX',
        :city => 'Gotham',
        :zip => '23456',
        :phone => '+1-132-12345678',

      },
      :email           => 'john.doe@example.com',
      :currency        => 'USD',
      :ip              => '127.0.0.1',
      :description => 'Test of ActiveMerchant'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '364926', response.authorization
  end

  def test_failed_authorization
    http_response = mock()
    http_response.stubs(:code).returns('403')
    http_response.stubs(:body).returns(failed_authorization_response)
    response_error = ::ActiveMerchant::ResponseError.new(http_response)
    @gateway.expects(:ssl_post).raises(response_error)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Authentication was failed', response.message
    assert_equal nil, response.authorization
  end

  def test_communication_error
    http_response = mock()
    http_response.stubs(:code).returns('408')
    response_error = ::ActiveMerchant::ResponseError.new(http_response)
    @gateway.expects(:ssl_post).raises(response_error)

    assert_raise(ActiveMerchant::ResponseError) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
  end

  def test_declined_purchase
    @gateway.expects(:ssl_post).returns(declined_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '364971', response.authorization
  end


  private

  def successful_purchase_response
    <<-XML
<transaction>
  <amount type="decimal">1.0</amount>
  <created_at type="datetime">2011-11-01T12:35:45+02:00</created_at>
  <id type="integer">367646</id>
  <state>completed</state>
  <type>Sale</type>
  <signature>3d01d5834daeeb360a45a6336326eb2a03c27d7b</signature>
  <response>
    <message>Transaction was successfully processed</message>
    <status>success</status>
    <provider>
      <code>00</code>
      <message>Approved (test mode)</message>
      <billing_descriptor>test desc136</billing_descriptor>
      <authorization_code>a0080z</authorization_code>
      <rrn>130510079645</rrn>
    </provider>
  </response>
  <order>
    <authorized_amount type="decimal">0.0</authorized_amount>
    <id type="integer">364926</id>
    <payment_method_type>CreditCard</payment_method_type>
    <settled_amount type="decimal">1.0</settled_amount>
    <state>paid</state>
    <test type="boolean">true</test>
    <payment_method>
      <brand>TestCard</brand>
      <pan_strip>7000-00XX-XXXX-0005</pan_strip>
    </payment_method>
    <tracking_params type="array"/>
    <billing_address>
      <address>Infinite Loop 1</address>
      <city>Gotham</city>
      <country>US</country>
      <first_name>Longbob</first_name>
      <last_name>Longsen</last_name>
      <phone>+1-132-12345678</phone>
      <state>TX</state>
      <zip>23456</zip>
    </billing_address>
    <details>
      <amount type="decimal">1.0</amount>
      <currency>USD</currency>
      <description>CertoConnect order #</description>
      <discount type="decimal" nil="true"></discount>
      <email>john.doe@example.com</email>
      <ip>127.0.0.1</ip>
      <items type="array"/>
    </details>
    <antifraud_responses type="array"/>
  </order>
</transaction>
XML
  end

  def failed_authorization_response
    <<-XML
<response>
  <errors type="array">
    <error>Authentication was failed</error>
  </errors>
</response>
XML
  end

  def declined_purchase_response
    <<-XML
<transaction>
  <amount type="decimal">1.0</amount>
  <created_at type="datetime">2011-11-01T13:52:18+02:00</created_at>
  <id type="integer">367691</id>
  <state>completed</state>
  <type>Sale</type>
  <signature>4c62abd58d59856a1ac465b03822e9e3937423ff</signature>
  <response>
    <message>Transaction was declined</message>
    <status>fail</status>
    <provider>
      <code>D3</code>
      <message>Declined (test mode)</message>
      <authorization_code>a0458z</authorization_code>
      <rrn>130511089540</rrn>
    </provider>
  </response>
  <order>
    <authorized_amount type="decimal">0.0</authorized_amount>
    <id type="integer">364971</id>
    <payment_method_type>CreditCard</payment_method_type>
    <settled_amount type="decimal">0.0</settled_amount>
    <state>declined</state>
    <test type="boolean">true</test>
    <payment_method>
      <brand>TestCard</brand>
      <pan_strip>7000-00XX-XXXX-0005</pan_strip>
    </payment_method>
    <tracking_params type="array"/>
    <billing_address>
      <address>Infinite Loop 1</address>
      <city>Gotham</city>
      <country>US</country>
      <first_name>Longbob</first_name>
      <last_name>Longsen</last_name>
      <phone>+1-132-12345678</phone>
      <state>TX</state>
      <zip>23456</zip>
    </billing_address>
    <details>
      <amount type="decimal">1.0</amount>
      <currency>USD</currency>
      <description>CertoConnect order #</description>
      <discount type="decimal" nil="true"></discount>
      <email>john.doe@example.com</email>
      <ip>127.0.0.1</ip>
      <items type="array"/>
    </details>
    <antifraud_responses type="array"/>
  </order>
</transaction>
XML
  end
end
