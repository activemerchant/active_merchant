require 'test_helper'

class NabTransactTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = NabTransactGateway.new(
                 :login => 'login',
                 :password => 'password'
               )
    @credit_card = credit_card
    @amount = 200

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Test NAB Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).with(&check_transaction_type(:purchase)).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '009887*test**200', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_merchant_descriptor
    name, location = 'Active Merchant', 'USA'

    response = assert_metadata(name, location) do
      response = @gateway.purchase(@amount, @credit_card, @options.merge(:merchant_name => name, :merchant_location => location))
    end

    assert response
    assert_instance_of Response, response
    assert_success response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).with(&check_transaction_type(:authorization)).returns(successful_authorize_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal '009887*test*009887*200', response.authorization
    assert response.test?
  end

  def test_successful_authorize_with_merchant_descriptor
    name, location = 'Active Merchant', 'USA'

    response = assert_metadata(name, location) do
      response = @gateway.authorize(@amount, @credit_card, @options.merge(:merchant_name => name, :merchant_location => location))
    end

    assert response
    assert_instance_of Response, response
    assert_success response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).with(&check_transaction_type(:capture)).returns(successful_purchase_response)
    assert response = @gateway.capture(@amount, '009887*test*009887*200')
    assert_equal '009887*test**200', response.authorization
    assert response.test?
  end

  def test_successful_capture_with_merchant_descriptor
    name, location = 'Active Merchant', 'USA'

    response = assert_metadata(name, location) do
      response = @gateway.capture(@amount, '009887*test*009887*200', @options.merge(:merchant_name => name, :merchant_location => location))
    end

    assert response
    assert_instance_of Response, response
    assert_success response
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).with(&check_transaction_type(:purchase)).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
    assert_equal "Expired Card", response.message
  end

  def test_failed_login
    @gateway.expects(:ssl_post).returns(failed_login_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "Invalid merchant ID", response.message
  end

  def test_supported_countries
    assert_equal ['AU'], NabTransactGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :diners_club, :jcb], NabTransactGateway.supported_cardtypes
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).with(&check_transaction_type(:refund)).returns(successful_refund_response)
    assert_success @gateway.refund(@amount, "009887", {:order_id => '1'})
  end

  def test_successful_refund_with_merchant_descriptor
    name, location = 'Active Merchant', 'USA'

    response = assert_metadata(name, location) do
      response = @gateway.refund(@amount, '009887', {:order_id => '1', :merchant_name => name, :merchant_location => location})
    end

    assert response
    assert_instance_of Response, response
    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).with(&check_transaction_type(:refund)).returns(failed_refund_response)

    assert response = @gateway.refund(@amount, "009887", {:order_id => '1'})
    assert_failure response
    assert_equal "Only $1.00 available for refund", response.message
  end

  private

  def check_transaction_type(type)
    Proc.new do |endpoint, data, headers|
      request_hash = Hash.from_xml(data)
      request_hash['NABTransactMessage']['Payment']['TxnList']['Txn']['txnType'] == NabTransactGateway::TRANSACTIONS[type].to_s
    end
  end

  def valid_metadata(name, location)
    valid_metadata = <<-XML.gsub(/^\s{4}/,'').gsub(/\n/, '')
    <metadata><meta name="ca_name" value="#{name}"/><meta name="ca_location" value="#{location}"/></metadata>
    XML
  end

  def assert_metadata(name, location, &block)
    stub_comms(@gateway, :ssl_request) do
      block.call
    end.check_request do |method, endpoint, data, headers|
      metadata_matcher = Regexp.escape(valid_metadata(name, location))
      assert_match /#{metadata_matcher}/, data
    end.respond_with(successful_purchase_response)
  end

  def failed_login_response
    '<NABTransactMessage><Status><statusCode>504</statusCode><statusDescription>Invalid merchant ID</statusDescription></Status></NABTransactMessage>'
  end

  def successful_purchase_response
    <<-XML.gsub(/^\s{4}/,'')
    <?xml version="1.0" encoding="UTF-8"?>
    <NABTransactMessage>
      <MessageInfo>
        <messageID>8af793f9af34bea0cf40f5fb750f64</messageID>
        <messageTimestamp>20042303111226938000+660</messageTimestamp>
        <apiVersion>xml-4.2</apiVersion>
      </MessageInfo>
      <MerchantInfo>
        <merchantID>ABC0001</merchantID>
      </MerchantInfo>
      <RequestType>Payment</RequestType>
      <Status>
        <statusCode>000</statusCode>
        <statusDescription>Normal</statusDescription>
      </Status>
      <Payment>
        <TxnList count="1">
          <Txn ID="1">
            <txnType>0</txnType>
            <txnSource>23</txnSource>
            <amount>200</amount>
            <currency>AUD</currency>
            <purchaseOrderNo>test</purchaseOrderNo>
            <approved>Yes</approved>
            <responseCode>00</responseCode>
            <responseText>Approved</responseText>
            <settlementDate>20040323</settlementDate>
            <txnID>009887</txnID>
            <CreditCardInfo>
              <pan>444433...111</pan>
              <expiryDate>08/12</expiryDate>
              <cardType>6</cardType>
              <cardDescription>Visa</cardDescription>
            </CreditCardInfo>
          </Txn>
        </TxnList>
      </Payment>
    </NABTransactMessage>
    XML
  end

  def failed_purchase_response
    <<-XML.gsub(/^\s{4}/,'')
    <?xml version="1.0" encoding="UTF-8"?>
    <NABTransactMessage>
      <MessageInfo>
        <messageID>8af793f9af34bea0cf40f5fb5c630c</messageID>
        <messageTimestamp>20042303111226938000+660</messageTimestamp>
        <apiVersion>xml-4.2</apiVersion>
      </MessageInfo>
      <MerchantInfo>
        <merchantID>ABC0001</merchantID>
      </MerchantInfo>
      <RequestType>Payment</RequestType>
      <Status>
        <statusCode>000</statusCode>
        <statusDescription>Normal</statusDescription>
      </Status>
      <Payment>
        <TxnList count="1">
          <Txn ID="1">
            <txnType>0</txnType>
            <txnSource>23</txnSource>
            <amount>200</amount>
            <currency>AUD</currency>
            <purchaseOrderNo>test</purchaseOrderNo>
            <approved>No</approved>
            <responseCode>54</responseCode>
            <responseText>Expired Card</responseText>
            <settlementDate>20040323</settlementDate>
            <txnID>000000</txnID>
            <CreditCardInfo>
              <pan>444433...111</pan>
              <expiryDate>08/12</expiryDate>
              <cardType>6</cardType>
              <cardDescription>Visa</cardDescription>
            </CreditCardInfo>
          </Txn>
        </TxnList>
      </Payment>
    </NABTransactMessage>
    XML
  end

  def successful_authorize_response
    <<-XML.gsub(/^\s{4}/,'')
    <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
    <NABTransactMessage>
      <MessageInfo>
        <messageID>4650de0ab4db398640b672a85e59ac</messageID>
        <messageTimestamp>20131207164203929000+600</messageTimestamp>
        <apiVersion>xml-4.2</apiVersion>
      </MessageInfo>
      <RequestType>Payment</RequestType>
      <MerchantInfo>
        <merchantID>XYZ0010</merchantID>
      </MerchantInfo>
      <Status>
        <statusCode>000</statusCode>
        <statusDescription>Normal</statusDescription>
      </Status>
      <Payment>
        <TxnList count=\"1\">
          <Txn ID=\"1\">
            <txnType>10</txnType>
            <txnSource>23</txnSource>
            <amount>200</amount>
            <currency>AUD</currency>
            <purchaseOrderNo>test</purchaseOrderNo>
            <approved>Yes</approved>
            <responseCode>00</responseCode>
            <responseText>Approved</responseText>
            <settlementDate>20130712</settlementDate>
            <txnID>009887</txnID>
            <preauthID>009887</preauthID>
            <authID/>
            <CreditCardInfo>
              <pan>444433...111</pan>
              <expiryDate>09/14</expiryDate>
              <cardType>6</cardType>
              <cardDescription>Visa</cardDescription>
            </CreditCardInfo>
          </Txn>
        </TxnList>
      </Payment>
    </NABTransactMessage>
    XML
  end

  def successful_refund_response
    <<-XML.gsub(/^\s{4}/,'')
    <?xml version="1.0" encoding="UTF-8"?>
    <NABTransactMessage>
      <MessageInfo>
        <messageID>feaedbe87239a005729aece8efa48b</messageID>
        <messageTimestamp>20102807071306650000+600</messageTimestamp>
        <apiVersion>xml-4.2</apiVersion>
      </MessageInfo>
      <RequestType>Payment</RequestType>
      <MerchantInfo>
        <merchantID>ABC0001</merchantID>
      </MerchantInfo>
      <Status>
        <statusCode>000</statusCode>
        <statusDescription>Normal</statusDescription>
      </Status>
      <Payment>
        <TxnList count="1">
          <Txn ID="1">
            <txnType>4</txnType>
            <txnSource>23</txnSource>
            <amount>100</amount>
            <currency>AUD</currency>
            <purchaseOrderNo>269065</purchaseOrderNo>
            <approved>Yes</approved>
            <responseCode>00</responseCode>
            <responseText>Approved</responseText>
            <settlementDate>20100728</settlementDate>
            <txnID>269067</txnID>
            <CreditCardInfo>
              <pan>444433...111</pan>
              <expiryDate>08/12</expiryDate>
              <cardType>6</cardType>
              <cardDescription>Visa</cardDescription>
            </CreditCardInfo>
          </Txn>
        </TxnList>
      </Payment>
    </NABTransactMessage>
    XML
  end

  def failed_refund_response
    <<-XML.gsub(/^\s{4}/,'')
    <?xml version="1.0" encoding="UTF-8"?>
    <NABTransactMessage>
      <MessageInfo>
        <messageID>6bacab2b7ae1200d8099e0873e25bc</messageID>
        <messageTimestamp>20102807071248484000+600</messageTimestamp>
        <apiVersion>xml-4.2</apiVersion>
      </MessageInfo>
      <RequestType>Payment</RequestType>
      <MerchantInfo>
        <merchantID>ABC0001</merchantID>
      </MerchantInfo>
      <Status>
        <statusCode>000</statusCode>
        <statusDescription>Normal</statusDescription>
      </Status>
      <Payment>
        <TxnList count="1">
          <Txn ID="1">
            <txnType>4</txnType>
            <txnSource>23</txnSource>
            <amount>101</amount>
            <currency>AUD</currency>
            <purchaseOrderNo>269061</purchaseOrderNo>
            <approved>No</approved>
            <responseCode>134</responseCode>
            <responseText>Only $1.00 available for refund</responseText>
            <settlementDate />
            <txnID />
            <CreditCardInfo>
              <pan>444433...111</pan>
              <expiryDate>08/12</expiryDate>
              <cardType>6</cardType>
              <cardDescription>Visa</cardDescription>
            </CreditCardInfo>
          </Txn>
        </TxnList>
      </Payment>
    </NABTransactMessage>
    XML
  end

end
