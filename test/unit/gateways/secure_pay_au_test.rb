require 'test_helper'

class SecurePayAuTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = SecurePayAuGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_supported_countries
    assert_equal ['AU'], SecurePayAuGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :diners_club, :jcb], SecurePayAuGateway.supported_cardtypes
  end


  def test_successful_purchase_with_live_data
    @gateway.expects(:ssl_post).returns(successful_live_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '000000*#1047.5**211700', response.authorization
    assert response.test?
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '024259*test**1000', response.authorization
    assert response.test?
  end

  def test_localized_currency
    stub_comms do
      @gateway.purchase(100, @credit_card, @options.merge(:currency => 'CAD'))
    end.check_request do |endpoint, data, headers|
      assert_match /<amount>100<\/amount>/, data
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.purchase(100, @credit_card, @options.merge(:currency => 'JPY'))
    end.check_request do |endpoint, data, headers|
      assert_match /<amount>1<\/amount>/, data
    end.respond_with(successful_purchase_response)
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
    assert_equal "CARD EXPIRED", response.message
  end

  def test_purchase_with_stored_id_calls_commit_periodic
    @gateway.expects(:commit_periodic)

    @gateway.purchase(@amount, "123", @options)
  end

  def test_purchase_with_creditcard_calls_commit_with_purchase
    @gateway.expects(:commit).with(:purchase, anything)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '269057*1*369057*100', response.authorization
  end

  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Insufficient Funds", response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, "crazy*reference*thingy*100", {})
    assert_success response
    assert_equal "Approved", response.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    assert response = @gateway.capture(@amount, "crazy*reference*thingy*100")
    assert_failure response
    assert_equal "Preauth was done for smaller amount", response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert_success @gateway.refund(@amount, "crazy*reference*thingy*100", {})
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(@amount, "crazy*reference*thingy*100")
    assert_failure response
    assert_equal "Only $1.00 available for refund", response.message
  end

  def test_deprecated_credit
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE, @gateway) do
      assert_success @gateway.credit(@amount, "crazy*reference*thingy*100", {})
    end
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void("crazy*reference*thingy*100", {})
    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert response = @gateway.void("crazy*reference*thingy*100")
    assert_failure response
    assert_equal "Transaction was done for different amount", response.message
  end

  def test_failed_login
    @gateway.expects(:ssl_post).returns(failed_login_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "Invalid merchant ID", response.message
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@credit_card, {:billing_id => 'test3', :amount => 123})
    assert_instance_of Response, response
    assert_equal "Successful", response.message
    assert_equal 'test3', response.params['client_id']
  end

  def test_successful_unstore
    @gateway.expects(:ssl_post).returns(successful_unstore_response)

    assert response = @gateway.unstore('test2')
    assert_instance_of Response, response
    assert_equal "Successful", response.message
    assert_equal 'test2', response.params['client_id']
  end

  def test_successful_triggered_payment
    @gateway.expects(:ssl_post).returns(successful_triggered_payment_response)

    assert response = @gateway.purchase(@amount, 'test3', @options)
    assert_instance_of Response, response
    assert_equal "Approved", response.message
    assert_equal 'test3', response.params['client_id']
  end

  private

  def successful_store_response
    <<-XML.gsub(/^\s{4}/,'')
    <?xml version="1.0" encoding="UTF-8"?>
    <SecurePayMessage>
      <MessageInfo>
        <messageID>8af793f9af34bea0ecd7eff71b37ef</messageID>
        <messageTimestamp>20040710144410220000+600</messageTimestamp>
        <apiVersion>spxml-3.0</apiVersion>
      </MessageInfo>
      <RequestType>Periodic</RequestType>
      <MerchantInfo>
        <merchantID>ABC0001</merchantID>
      </MerchantInfo>
      <Status>
        <statusCode>0</statusCode>
        <statusDescription>Normal</statusDescription>
      </Status>
      <Periodic>
        <PeriodicList count="1">
          <PeriodicItem ID="1">
            <actionType>add</actionType>
            <clientID>test3</clientID>
            <responseCode>00</responseCode>
            <responseText>Successful</responseText>
            <successful>yes</successful>
            <CreditCardInfo>
              <pan>444433...111</pan>
              <expiryDate>09/15</expiryDate>
              <recurringFlag>no</recurringFlag>
            </CreditCardInfo>
            <amount>1100</amount>
            <periodicType>4</periodicType>
          </PeriodicItem>
        </PeriodicList>
      </Periodic>
    </SecurePayMessage>
    XML
  end

  def successful_unstore_response
    <<-XML.gsub(/^\s{4}/,'')
    <?xml version="1.0" encoding="UTF-8"?>
    <SecurePayMessage>
      <MessageInfo>
        <messageID>8af793f9af34bea0ecd7eff71c3ef1</messageID>
        <messageTimestamp>20040710150207549000+600</messageTimestamp>
        <apiVersion>spxml-3.0</apiVersion>
      </MessageInfo>
      <RequestType>Periodic</RequestType>
      <MerchantInfo>
        <merchantID>ABC0001</merchantID>
      </MerchantInfo>
      <Status>
        <statusCode>0</statusCode>
        <statusDescription>Normal</statusDescription>
      </Status>
      <Periodic>
        <PeriodicList count="1">
          <PeriodicItem ID="1">
            <actionType>delete</actionType>
            <clientID>test2</clientID>
            <responseCode>00</responseCode>
            <responseText>Successful</responseText>
            <successful>yes</successful>
          </PeriodicItem>
        </PeriodicList>
      </Periodic>
    </SecurePayMessage>
    XML
  end

  def successful_triggered_payment_response
    <<-XML.gsub(/^\s{4}/,'')
    <?xml version="1.0" encoding="UTF-8"?>
    <SecurePayMessage>
      <MessageInfo>
        <messageID>8af793f9af34bea0ecd7eff71c94d6</messageID>
        <messageTimestamp>20040710150808428000+600</messageTimestamp>
        <apiVersion>spxml-3.0</apiVersion>
      </MessageInfo>
      <RequestType>Periodic</RequestType>
      <MerchantInfo>
        <merchantID>ABC0001</merchantID>
      </MerchantInfo>
      <Status>
        <statusCode>0</statusCode>
        <statusDescription>Normal</statusDescription>
      </Status>
      <Periodic>
        <PeriodicList count="1">
          <PeriodicItem ID="1">
            <actionType>trigger</actionType>
            <clientID>test3</clientID>
            <responseCode>00</responseCode>
            <responseText>Approved</responseText>
            <successful>yes</successful>
            <amount>1400</amount>
            <txnID>011700</txnID>
            <CreditCardInfo>
              <pan>424242...242</pan>
              <expiryDate>09/08</expiryDate>
              <recurringFlag>no</recurringFlag>
              <cardType>6</cardType>
              <cardDescription>Visa</cardDescription>
            </CreditCardInfo>
            <settlementDate>20041007</settlementDate>
          </PeriodicItem>
        </PeriodicList>
      </Periodic>
    </SecurePayMessage>
    XML
  end

  def failed_login_response
    '<SecurePayMessage><Status><statusCode>504</statusCode><statusDescription>Invalid merchant ID</statusDescription></Status></SecurePayMessage>'
  end

  def successful_purchase_response
    <<-XML.gsub(/^\s{4}/,'')
    <?xml version="1.0" encoding="UTF-8"?>
    <SecurePayMessage>
      <MessageInfo>
        <messageID>8af793f9af34bea0cf40f5fb5c630c</messageID>
        <messageTimestamp>20080802041625665000+660</messageTimestamp>
        <apiVersion>xml-4.2</apiVersion>
      </MessageInfo>
      <RequestType>Payment</RequestType>
      <MerchantInfo>
        <merchantID>XYZ0001</merchantID>
      </MerchantInfo>
      <Status>
        <statusCode>000</statusCode>
        <statusDescription>Normal</statusDescription>
      </Status>
      <Payment>
        <TxnList count="1">
          <Txn ID="1">
            <txnType>0</txnType>
            <txnSource>0</txnSource>
            <amount>1000</amount>
            <currency>AUD</currency>
            <purchaseOrderNo>test</purchaseOrderNo>
            <approved>Yes</approved>
            <responseCode>00</responseCode>
            <responseText>Approved</responseText>
            <thinlinkResponseCode>100</thinlinkResponseCode>
            <thinlinkResponseText>000</thinlinkResponseText>
            <thinlinkEventStatusCode>000</thinlinkEventStatusCode>
            <thinlinkEventStatusText>Normal</thinlinkEventStatusText>
            <settlementDate>20080208</settlementDate>
            <txnID>024259</txnID>
            <CreditCardInfo>
              <pan>424242...242</pan>
              <expiryDate>07/11</expiryDate>
              <cardType>6</cardType>
              <cardDescription>Visa</cardDescription>
            </CreditCardInfo>
          </Txn>
        </TxnList>
      </Payment>
    </SecurePayMessage>
    XML
  end

  def failed_purchase_response
    <<-XML.gsub(/^\s{4}/,'')
    <?xml version="1.0" encoding="UTF-8"?>
    <SecurePayMessage>
      <MessageInfo>
        <messageID>8af793f9af34bea0cf40f5fb5c630c</messageID>
        <messageTimestamp>20080802040346380000+660</messageTimestamp>
        <apiVersion>xml-4.2</apiVersion>
      </MessageInfo>
      <RequestType>Payment</RequestType>
      <MerchantInfo>
        <merchantID>XYZ0001</merchantID>
      </MerchantInfo>
      <Status>
        <statusCode>000</statusCode>
        <statusDescription>Normal</statusDescription>
      </Status>
      <Payment>
        <TxnList count="1">
          <Txn ID="1">
            <txnType>0</txnType>
            <txnSource>0</txnSource>
            <amount>1000</amount>
            <currency>AUD</currency>
            <purchaseOrderNo>test</purchaseOrderNo>
            <approved>No</approved>
            <responseCode>907</responseCode>
            <responseText>CARD EXPIRED</responseText>
            <thinlinkResponseCode>300</thinlinkResponseCode>
            <thinlinkResponseText>000</thinlinkResponseText>
            <thinlinkEventStatusCode>981</thinlinkEventStatusCode>
            <thinlinkEventStatusText>Error - Expired Card</thinlinkEventStatusText>
            <settlementDate>        </settlementDate>
            <txnID>000000</txnID>
            <CreditCardInfo>
              <pan>424242...242</pan>
              <expiryDate>07/06</expiryDate>
              <cardType>6</cardType>
              <cardDescription>Visa</cardDescription>
            </CreditCardInfo>
          </Txn>
        </TxnList>
      </Payment>
    </SecurePayMessage>
    XML
  end

  def successful_live_purchase_response
    <<-XML.gsub(/^\s{4}/,'')
    <?xml version="1.0" encoding="UTF-8"?>
    <SecurePayMessage>
      <MessageInfo>
        <messageID>8af793f9af34bea0cf40f5fb5c630c</messageID>
        <messageTimestamp>20080802041625665000+660</messageTimestamp>
        <apiVersion>xml-4.2</apiVersion>
      </MessageInfo>
      <RequestType>Payment</RequestType>
      <MerchantInfo>
        <merchantID>XYZ0001</merchantID>
      </MerchantInfo>
      <Status>
        <statusCode>000</statusCode>
        <statusDescription>Normal</statusDescription>
      </Status>
      <Payment>
        <TxnList count="1">
          <Txn ID="1">
            <txnType>0</txnType>
            <txnSource>23</txnSource>
            <amount>211700</amount>
            <currency>AUD</currency>
            <purchaseOrderNo>#1047.5</purchaseOrderNo>
            <approved>Yes</approved>
            <responseCode>77</responseCode>
            <responseText>Approved</responseText>
            <thinlinkResponseCode>100</thinlinkResponseCode>
            <thinlinkResponseText>000</thinlinkResponseText>
            <thinlinkEventStatusCode>000</thinlinkEventStatusCode>
            <thinlinkEventStatusText>Normal</thinlinkEventStatusText>
            <settlementDate>20080525</settlementDate>
            <txnID>000000</txnID>
            <CreditCardInfo>
              <pan>424242...242</pan>
              <expiryDate>07/11</expiryDate>
              <cardType>6</cardType>
              <cardDescription>Visa</cardDescription>
            </CreditCardInfo>
          </Txn>
        </TxnList>
      </Payment>
    </SecurePayMessage>
    XML
  end

  def successful_authorization_response
    %(<?xml version="1.0" encoding="UTF-8" standalone="no"?><SecurePayMessage><MessageInfo><messageID>18071a6170073a7ef231ef048217be</messageID><messageTimestamp>20102807071229455000+600</messageTimestamp><apiVersion>xml-4.2</apiVersion></MessageInfo><RequestType>Payment</RequestType><MerchantInfo><merchantID>CAX0001</merchantID></MerchantInfo><Status><statusCode>000</statusCode><statusDescription>Normal</statusDescription></Status><Payment><TxnList count="1"><Txn ID="1"><txnType>10</txnType><txnSource>23</txnSource><amount>100</amount><currency>AUD</currency><purchaseOrderNo>1</purchaseOrderNo><approved>Yes</approved><responseCode>00</responseCode><responseText>Approved</responseText><thinlinkResponseCode>100</thinlinkResponseCode><thinlinkResponseText>000</thinlinkResponseText><thinlinkEventStatusCode>000</thinlinkEventStatusCode><thinlinkEventStatusText>Normal</thinlinkEventStatusText><settlementDate>20100728</settlementDate><txnID>269057</txnID><preauthID>369057</preauthID><CreditCardInfo><pan>444433...111</pan><expiryDate>09/11</expiryDate><cardType>6</cardType><cardDescription>Visa</cardDescription></CreditCardInfo></Txn></TxnList></Payment></SecurePayMessage>)
  end

  def failed_authorization_response
    %(<?xml version="1.0" encoding="UTF-8" standalone="no"?><SecurePayMessage><MessageInfo><messageID>97991d10eda9ae47d684ae21089b97</messageID><messageTimestamp>20102807071237345000+600</messageTimestamp><apiVersion>xml-4.2</apiVersion></MessageInfo><RequestType>Payment</RequestType><MerchantInfo><merchantID>CAX0001</merchantID></MerchantInfo><Status><statusCode>000</statusCode><statusDescription>Normal</statusDescription></Status><Payment><TxnList count="1"><Txn ID="1"><txnType>10</txnType><txnSource>23</txnSource><amount>151</amount><currency>AUD</currency><purchaseOrderNo>1</purchaseOrderNo><approved>No</approved><responseCode>51</responseCode><responseText>Insufficient Funds</responseText><thinlinkResponseCode>200</thinlinkResponseCode><thinlinkResponseText>000</thinlinkResponseText><thinlinkEventStatusCode>000</thinlinkEventStatusCode><thinlinkEventStatusText>Normal</thinlinkEventStatusText><settlementDate>20100728</settlementDate><txnID>269059</txnID><preauthID>269059</preauthID><CreditCardInfo><pan>444433...111</pan><expiryDate>09/11</expiryDate><cardType>6</cardType><cardDescription>Visa</cardDescription></CreditCardInfo></Txn></TxnList></Payment></SecurePayMessage>)
  end

  def successful_capture_response
    %(<?xml version="1.0" encoding="UTF-8" standalone="no"?><SecurePayMessage><MessageInfo><messageID>1e3b82037a228c237cbc89db8a5e8a</messageID><messageTimestamp>20102807071233509000+600</messageTimestamp><apiVersion>xml-4.2</apiVersion></MessageInfo><RequestType>Payment</RequestType><MerchantInfo><merchantID>CAX0001</merchantID></MerchantInfo><Status><statusCode>000</statusCode><statusDescription>Normal</statusDescription></Status><Payment><TxnList count="1"><Txn ID="1"><txnType>11</txnType><txnSource>23</txnSource><amount>100</amount><currency>AUD</currency><purchaseOrderNo>1</purchaseOrderNo><approved>Yes</approved><responseCode>00</responseCode><responseText>Approved</responseText><thinlinkResponseCode>100</thinlinkResponseCode><thinlinkResponseText>000</thinlinkResponseText><thinlinkEventStatusCode>000</thinlinkEventStatusCode><thinlinkEventStatusText>Normal</thinlinkEventStatusText><settlementDate>20100728</settlementDate><txnID>269058</txnID><CreditCardInfo><pan>444433...111</pan><expiryDate>09/11</expiryDate><cardType>6</cardType><cardDescription>Visa</cardDescription></CreditCardInfo></Txn></TxnList></Payment></SecurePayMessage>)
  end

  def failed_capture_response
    %(<?xml version="1.0" encoding="UTF-8" standalone="no"?><SecurePayMessage><MessageInfo><messageID>9ac0da93c0ea7a2d74c2430a078995</messageID><messageTimestamp>20102807071243261000+600</messageTimestamp><apiVersion>xml-4.2</apiVersion></MessageInfo><RequestType>Payment</RequestType><MerchantInfo><merchantID>CAX0001</merchantID></MerchantInfo><Status><statusCode>000</statusCode><statusDescription>Normal</statusDescription></Status><Payment><TxnList count="1"><Txn ID="1"><txnType>11</txnType><txnSource>23</txnSource><amount>101</amount><currency>AUD</currency><purchaseOrderNo>1</purchaseOrderNo><approved>No</approved><responseCode>142</responseCode><responseText>Preauth was done for smaller amount</responseText><thinlinkResponseCode>300</thinlinkResponseCode><thinlinkResponseText>000</thinlinkResponseText><thinlinkEventStatusCode>999</thinlinkEventStatusCode><thinlinkEventStatusText>Error - Pre-auth Was Done For Smaller Amount</thinlinkEventStatusText><settlementDate/><txnID/><CreditCardInfo><pan>444433...111</pan><expiryDate>09/11</expiryDate><cardType>6</cardType><cardDescription>Visa</cardDescription></CreditCardInfo></Txn></TxnList></Payment></SecurePayMessage>)
  end

  def successful_void_response
    %(<?xml version="1.0" encoding="UTF-8" standalone="no"?><SecurePayMessage><MessageInfo><messageID>2207c9396eb7005639edcbae9bfb46</messageID><messageTimestamp>20102807071317401000+600</messageTimestamp><apiVersion>xml-4.2</apiVersion></MessageInfo><RequestType>Payment</RequestType><MerchantInfo><merchantID>CAX0001</merchantID></MerchantInfo><Status><statusCode>000</statusCode><statusDescription>Normal</statusDescription></Status><Payment><TxnList count="1"><Txn ID="1"><txnType>6</txnType><txnSource>23</txnSource><amount>100</amount><currency>AUD</currency><purchaseOrderNo>269069</purchaseOrderNo><approved>Yes</approved><responseCode>00</responseCode><responseText>Approved</responseText><thinlinkResponseCode>100</thinlinkResponseCode><thinlinkResponseText>000</thinlinkResponseText><thinlinkEventStatusCode>000</thinlinkEventStatusCode><thinlinkEventStatusText>Normal</thinlinkEventStatusText><settlementDate>20100728</settlementDate><txnID>269070</txnID><CreditCardInfo><pan>444433...111</pan><expiryDate>09/11</expiryDate><cardType>6</cardType><cardDescription>Visa</cardDescription></CreditCardInfo></Txn></TxnList></Payment></SecurePayMessage>)
  end

  def failed_void_response
    %(<?xml version="1.0" encoding="UTF-8" standalone="no"?><SecurePayMessage><MessageInfo><messageID>5ae52d17168291fff92d0c45933eb5</messageID><messageTimestamp>20102807071257719000+600</messageTimestamp><apiVersion>xml-4.2</apiVersion></MessageInfo><RequestType>Payment</RequestType><MerchantInfo><merchantID>CAX0001</merchantID></MerchantInfo><Status><statusCode>000</statusCode><statusDescription>Normal</statusDescription></Status><Payment><TxnList count="1"><Txn ID="1"><txnType>6</txnType><txnSource>23</txnSource><amount>1001</amount><currency>AUD</currency><purchaseOrderNo>269063</purchaseOrderNo><approved>No</approved><responseCode>100</responseCode><responseText>Transaction was done for different amount</responseText><thinlinkResponseCode>300</thinlinkResponseCode><thinlinkResponseText>000</thinlinkResponseText><thinlinkEventStatusCode>990</thinlinkEventStatusCode><thinlinkEventStatusText>Error - Invalid amount</thinlinkEventStatusText><settlementDate/><txnID/><CreditCardInfo><pan>444433...111</pan><expiryDate>09/11</expiryDate><cardType>6</cardType><cardDescription>Visa</cardDescription></CreditCardInfo></Txn></TxnList></Payment></SecurePayMessage>)
  end

  def successful_refund_response
    %(<?xml version="1.0" encoding="UTF-8" standalone="no"?><SecurePayMessage><MessageInfo><messageID>feaedbe87239a005729aece8efa48b</messageID><messageTimestamp>20102807071306650000+600</messageTimestamp><apiVersion>xml-4.2</apiVersion></MessageInfo><RequestType>Payment</RequestType><MerchantInfo><merchantID>CAX0001</merchantID></MerchantInfo><Status><statusCode>000</statusCode><statusDescription>Normal</statusDescription></Status><Payment><TxnList count="1"><Txn ID="1"><txnType>4</txnType><txnSource>23</txnSource><amount>100</amount><currency>AUD</currency><purchaseOrderNo>269065</purchaseOrderNo><approved>Yes</approved><responseCode>00</responseCode><responseText>Approved</responseText><thinlinkResponseCode>100</thinlinkResponseCode><thinlinkResponseText>000</thinlinkResponseText><thinlinkEventStatusCode>000</thinlinkEventStatusCode><thinlinkEventStatusText>Normal</thinlinkEventStatusText><settlementDate>20100728</settlementDate><txnID>269067</txnID><CreditCardInfo><pan>444433...111</pan><expiryDate>09/11</expiryDate><cardType>6</cardType><cardDescription>Visa</cardDescription></CreditCardInfo></Txn></TxnList></Payment></SecurePayMessage>)
  end

  def failed_refund_response
    %(<?xml version="1.0" encoding="UTF-8" standalone="no"?><SecurePayMessage><MessageInfo><messageID>6bacab2b7ae1200d8099e0873e25bc</messageID><messageTimestamp>20102807071248484000+600</messageTimestamp><apiVersion>xml-4.2</apiVersion></MessageInfo><RequestType>Payment</RequestType><MerchantInfo><merchantID>CAX0001</merchantID></MerchantInfo><Status><statusCode>000</statusCode><statusDescription>Normal</statusDescription></Status><Payment><TxnList count="1"><Txn ID="1"><txnType>4</txnType><txnSource>23</txnSource><amount>101</amount><currency>AUD</currency><purchaseOrderNo>269061</purchaseOrderNo><approved>No</approved><responseCode>134</responseCode><responseText>Only $1.00 available for refund</responseText><thinlinkResponseCode>300</thinlinkResponseCode><thinlinkResponseText>000</thinlinkResponseText><thinlinkEventStatusCode>999</thinlinkEventStatusCode><thinlinkEventStatusText>Error - Transaction Already Fully Refunded/Only $x.xx Available for Refund</thinlinkEventStatusText><settlementDate/><txnID/><CreditCardInfo><pan>444433...111</pan><expiryDate>09/11</expiryDate><cardType>6</cardType><cardDescription>Visa</cardDescription></CreditCardInfo></Txn></TxnList></Payment></SecurePayMessage>)
  end
end
