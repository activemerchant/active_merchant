require 'test_helper'
require 'yaml'

class FirstdataE4Test < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = FirstdataE4Gateway.new(
      :login    => "A00427-01",
      :password => "testus"
    )

    @credit_card = credit_card
    @amount = 100
    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
    @authorization = "ET1700;106625152;4738"
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'ET1700;106625152;4738', response.authorization
    assert response.test?
    assert_equal 'Transaction Normal - Approved', response.message

    ExactGateway::SENSITIVE_FIELDS.each{|f| assert !response.params.has_key?(f.to_s)}
  end

  def test_successful_purchase_with_token
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, '8938737759041111;visa;Longbob;Longsen;9;2014')
    assert_success response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    assert response = @gateway.void(@authorization, @options)
    assert_success response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert response = @gateway.refund(@amount, @authorization)
    assert_success response
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal '8938737759041111', response.params['transarmor_token']
    assert_equal "8938737759041111;visa;Longbob;Longsen;9;#{@credit_card.year}", response.authorization
  end

  def test_failed_store_without_transarmor_support
    @gateway.expects(:ssl_post).returns(successful_purchase_response_without_transarmor)
    assert_raise StandardError do
      @gateway.store(@credit_card, @options)
    end
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_expdate
    assert_equal(
      "%02d%s" % [@credit_card.month, @credit_card.year.to_s[-2..-1]],
      @gateway.send(:expdate, @credit_card)
    )
  end

  def test_no_transaction
    @gateway.expects(:ssl_post).raises(no_transaction_response())
    assert response = @gateway.purchase(100, @credit_card, {})
    assert_failure response
    assert response.test?
    assert_equal 'Malformed request: Transaction Type is missing.', response.message
  end

  def test_supported_countries
    assert_equal ['CA', 'US'], ExactGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :jcb, :discover], ExactGateway.supported_cardtypes
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'U', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_requests_include_verification_string
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match "<VerificationStr1>1234 My Street|K1C2N6|Ottawa|ON|CA</VerificationStr1>", data
    end.respond_with(successful_purchase_response)
  end

  private

  def successful_purchase_response
    <<-RESPONSE
  <?xml version="1.0" encoding="UTF-8"?>
  <TransactionResult>
    <ExactID>AD1234-56</ExactID>
    <Password></Password>
    <Transaction_Type>00</Transaction_Type>
    <DollarAmount>47.38</DollarAmount>
    <SurchargeAmount></SurchargeAmount>
    <Card_Number>############1111</Card_Number>
    <Transaction_Tag>106625152</Transaction_Tag>
    <Track1></Track1>
    <Track2></Track2>
    <PAN></PAN>
    <Authorization_Num>ET1700</Authorization_Num>
    <Expiry_Date>0913</Expiry_Date>
    <CardHoldersName>Fred Burfle</CardHoldersName>
    <VerificationStr1></VerificationStr1>
    <VerificationStr2>773</VerificationStr2>
    <CVD_Presence_Ind>0</CVD_Presence_Ind>
    <ZipCode></ZipCode>
    <Tax1Amount></Tax1Amount>
    <Tax1Number></Tax1Number>
    <Tax2Amount></Tax2Amount>
    <Tax2Number></Tax2Number>
    <Secure_AuthRequired></Secure_AuthRequired>
    <Secure_AuthResult></Secure_AuthResult>
    <Ecommerce_Flag></Ecommerce_Flag>
    <XID></XID>
    <CAVV></CAVV>
    <CAVV_Algorithm></CAVV_Algorithm>
    <Reference_No>77</Reference_No>
    <Customer_Ref></Customer_Ref>
    <Reference_3></Reference_3>
    <Language></Language>
    <Client_IP>1.1.1.10</Client_IP>
    <Client_Email></Client_Email>
    <Transaction_Error>false</Transaction_Error>
    <Transaction_Approved>true</Transaction_Approved>
    <EXact_Resp_Code>00</EXact_Resp_Code>
    <EXact_Message>Transaction Normal</EXact_Message>
    <Bank_Resp_Code>100</Bank_Resp_Code>
    <Bank_Message>Approved</Bank_Message>
    <Bank_Resp_Code_2></Bank_Resp_Code_2>
    <SequenceNo>000040</SequenceNo>
    <AVS>U</AVS>
    <CVV2>M</CVV2>
    <Retrieval_Ref_No>3146117</Retrieval_Ref_No>
    <CAVV_Response></CAVV_Response>
    <Currency>USD</Currency>
    <AmountRequested></AmountRequested>
    <PartialRedemption>false</PartialRedemption>
    <MerchantName>Friendly Inc DEMO0983</MerchantName>
    <MerchantAddress>123 King St</MerchantAddress>
    <MerchantCity>Toronto</MerchantCity>
    <MerchantProvince>Ontario</MerchantProvince>
    <MerchantCountry>Canada</MerchantCountry>
    <MerchantPostal>L7Z 3K8</MerchantPostal>
    <MerchantURL></MerchantURL>
    <TransarmorToken>8938737759041111</TransarmorToken>
    <CTR>=========== TRANSACTION RECORD ==========
Friendly Inc DEMO0983
123 King St
Toronto, ON L7Z 3K8
Canada


TYPE: Purchase

ACCT: Visa  $ 47.38 USD

CARD NUMBER : ############1111
DATE/TIME   : 28 Sep 12 07:54:48
REFERENCE # :  000040 M
AUTHOR. #   : ET120454
TRANS. REF. : 77

    Approved - Thank You 100


Please retain this copy for your records.

Cardholder will pay above amount to card
issuer pursuant to cardholder agreement.
=========================================</CTR>
  </TransactionResult>
    RESPONSE
  end
  def successful_purchase_response_without_transarmor
    <<-RESPONSE
  <?xml version="1.0" encoding="UTF-8"?>
  <TransactionResult>
    <ExactID>AD1234-56</ExactID>
    <Password></Password>
    <Transaction_Type>00</Transaction_Type>
    <DollarAmount>47.38</DollarAmount>
    <SurchargeAmount></SurchargeAmount>
    <Card_Number>############1111</Card_Number>
    <Transaction_Tag>106625152</Transaction_Tag>
    <Track1></Track1>
    <Track2></Track2>
    <PAN></PAN>
    <Authorization_Num>ET1700</Authorization_Num>
    <Expiry_Date>0913</Expiry_Date>
    <CardHoldersName>Fred Burfle</CardHoldersName>
    <VerificationStr1></VerificationStr1>
    <VerificationStr2>773</VerificationStr2>
    <CVD_Presence_Ind>0</CVD_Presence_Ind>
    <ZipCode></ZipCode>
    <Tax1Amount></Tax1Amount>
    <Tax1Number></Tax1Number>
    <Tax2Amount></Tax2Amount>
    <Tax2Number></Tax2Number>
    <Secure_AuthRequired></Secure_AuthRequired>
    <Secure_AuthResult></Secure_AuthResult>
    <Ecommerce_Flag></Ecommerce_Flag>
    <XID></XID>
    <CAVV></CAVV>
    <CAVV_Algorithm></CAVV_Algorithm>
    <Reference_No>77</Reference_No>
    <Customer_Ref></Customer_Ref>
    <Reference_3></Reference_3>
    <Language></Language>
    <Client_IP>1.1.1.10</Client_IP>
    <Client_Email></Client_Email>
    <Transaction_Error>false</Transaction_Error>
    <Transaction_Approved>true</Transaction_Approved>
    <EXact_Resp_Code>00</EXact_Resp_Code>
    <EXact_Message>Transaction Normal</EXact_Message>
    <Bank_Resp_Code>100</Bank_Resp_Code>
    <Bank_Message>Approved</Bank_Message>
    <Bank_Resp_Code_2></Bank_Resp_Code_2>
    <SequenceNo>000040</SequenceNo>
    <AVS>U</AVS>
    <CVV2>M</CVV2>
    <Retrieval_Ref_No>3146117</Retrieval_Ref_No>
    <CAVV_Response></CAVV_Response>
    <Currency>USD</Currency>
    <AmountRequested></AmountRequested>
    <PartialRedemption>false</PartialRedemption>
    <MerchantName>Friendly Inc DEMO0983</MerchantName>
    <MerchantAddress>123 King St</MerchantAddress>
    <MerchantCity>Toronto</MerchantCity>
    <MerchantProvince>Ontario</MerchantProvince>
    <MerchantCountry>Canada</MerchantCountry>
    <MerchantPostal>L7Z 3K8</MerchantPostal>
    <MerchantURL></MerchantURL>
    <TransarmorToken></TransarmorToken>
    <CTR>=========== TRANSACTION RECORD ==========
Friendly Inc DEMO0983
123 King St
Toronto, ON L7Z 3K8
Canada


TYPE: Purchase

ACCT: Visa  $ 47.38 USD

CARD NUMBER : ############1111
DATE/TIME   : 28 Sep 12 07:54:48
REFERENCE # :  000040 M
AUTHOR. #   : ET120454
TRANS. REF. : 77

    Approved - Thank You 100


Please retain this copy for your records.

Cardholder will pay above amount to card
issuer pursuant to cardholder agreement.
=========================================</CTR>
  </TransactionResult>
    RESPONSE
  end
  def successful_refund_response
    <<-RESPONSE
  <?xml version="1.0" encoding="UTF-8"?>
  <TransactionResult>
    <ExactID>AD1234-56</ExactID>
    <Password></Password>
    <Transaction_Type>34</Transaction_Type>
    <DollarAmount>123</DollarAmount>
    <SurchargeAmount></SurchargeAmount>
    <Card_Number>############1111</Card_Number>
    <Transaction_Tag>888</Transaction_Tag>
    <Track1></Track1>
    <Track2></Track2>
    <PAN></PAN>
    <Authorization_Num>ET112216</Authorization_Num>
    <Expiry_Date>0913</Expiry_Date>
    <CardHoldersName>Fred Burfle</CardHoldersName>
    <VerificationStr1></VerificationStr1>
    <VerificationStr2></VerificationStr2>
    <CVD_Presence_Ind>0</CVD_Presence_Ind>
    <ZipCode></ZipCode>
    <Tax1Amount></Tax1Amount>
    <Tax1Number></Tax1Number>
    <Tax2Amount></Tax2Amount>
    <Tax2Number></Tax2Number>
    <Secure_AuthRequired></Secure_AuthRequired>
    <Secure_AuthResult></Secure_AuthResult>
    <Ecommerce_Flag></Ecommerce_Flag>
    <XID></XID>
    <CAVV></CAVV>
    <CAVV_Algorithm></CAVV_Algorithm>
    <Reference_No></Reference_No>
    <Customer_Ref></Customer_Ref>
    <Reference_3></Reference_3>
    <Language></Language>
    <Client_IP>1.1.1.10</Client_IP>
    <Client_Email></Client_Email>
    <Transaction_Error>false</Transaction_Error>
    <Transaction_Approved>true</Transaction_Approved>
    <EXact_Resp_Code>00</EXact_Resp_Code>
    <EXact_Message>Transaction Normal</EXact_Message>
    <Bank_Resp_Code>100</Bank_Resp_Code>
    <Bank_Message>Approved</Bank_Message>
    <Bank_Resp_Code_2></Bank_Resp_Code_2>
    <SequenceNo>000041</SequenceNo>
    <AVS></AVS>
    <CVV2>I</CVV2>
    <Retrieval_Ref_No>9176784</Retrieval_Ref_No>
    <CAVV_Response></CAVV_Response>
    <Currency>USD</Currency>
    <AmountRequested></AmountRequested>
    <PartialRedemption>false</PartialRedemption>
    <MerchantName>Friendly Inc DEMO0983</MerchantName>
    <MerchantAddress>123 King St</MerchantAddress>
    <MerchantCity>Toronto</MerchantCity>
    <MerchantProvince>Ontario</MerchantProvince>
    <MerchantCountry>Canada</MerchantCountry>
    <MerchantPostal>L7Z 3K8</MerchantPostal>
    <MerchantURL></MerchantURL>
    <CTR>=========== TRANSACTION RECORD ==========
Friendly Inc DEMO0983
123 King St
Toronto, ON L7Z 3K8
Canada


TYPE: Refund

ACCT: Visa  $ 23.69 USD

CARD NUMBER : ############1111
DATE/TIME   : 28 Sep 12 08:31:23
REFERENCE # :  000041 M
AUTHOR. #   : ET112216
TRANS. REF. :

    Approved - Thank You 100


Please retain this copy for your records.

=========================================</CTR>
  </TransactionResult>
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
    <?xml version="1.0" encoding="UTF-8"?>
    <TransactionResult>
      <ExactID>AD1234-56</ExactID>
      <Password></Password>
      <Transaction_Type>00</Transaction_Type>
      <DollarAmount>5013.0</DollarAmount>
      <SurchargeAmount></SurchargeAmount>
      <Card_Number>############1111</Card_Number>
      <Transaction_Tag>555555</Transaction_Tag>
      <Track1></Track1>
      <Track2></Track2>
      <PAN></PAN>
      <Authorization_Num></Authorization_Num>
      <Expiry_Date>0911</Expiry_Date>
      <CardHoldersName>Fred Burfle</CardHoldersName>
      <VerificationStr1></VerificationStr1>
      <VerificationStr2>773</VerificationStr2>
      <CVD_Presence_Ind>0</CVD_Presence_Ind>
      <ZipCode></ZipCode>
      <Tax1Amount></Tax1Amount>
      <Tax1Number></Tax1Number>
      <Tax2Amount></Tax2Amount>
      <Tax2Number></Tax2Number>
      <Secure_AuthRequired></Secure_AuthRequired>
      <Secure_AuthResult></Secure_AuthResult>
      <Ecommerce_Flag></Ecommerce_Flag>
      <XID></XID>
      <CAVV></CAVV>
      <CAVV_Algorithm></CAVV_Algorithm>
      <Reference_No>77</Reference_No>
      <Customer_Ref></Customer_Ref>
      <Reference_3></Reference_3>
      <Language></Language>
      <Client_IP>1.1.1.10</Client_IP>
      <Client_Email></Client_Email>
      <LogonMessage></LogonMessage>
      <Error_Number>0</Error_Number>
      <Error_Description> </Error_Description>
      <Transaction_Error>false</Transaction_Error>
      <Transaction_Approved>false</Transaction_Approved>
      <EXact_Resp_Code>00</EXact_Resp_Code>
      <EXact_Message>Transaction Normal</EXact_Message>
      <Bank_Resp_Code>605</Bank_Resp_Code>
      <Bank_Message>Invalid Expiration Date</Bank_Message>
      <Bank_Resp_Code_2></Bank_Resp_Code_2>
      <SequenceNo>000033</SequenceNo>
      <AVS></AVS>
      <CVV2></CVV2>
      <Retrieval_Ref_No></Retrieval_Ref_No>
      <CAVV_Response></CAVV_Response>
      <Currency>USD</Currency>
      <AmountRequested></AmountRequested>
      <PartialRedemption>false</PartialRedemption>
      <MerchantName>Friendly Inc DEMO0983</MerchantName>
      <MerchantAddress>123 King St</MerchantAddress>
      <MerchantCity>Toronto</MerchantCity>
      <MerchantProvince>Ontario</MerchantProvince>
      <MerchantCountry>Canada</MerchantCountry>
      <MerchantPostal>L7Z 3K8</MerchantPostal>
      <MerchantURL></MerchantURL>
      <CTR>=========== TRANSACTION RECORD ==========
Friendly Inc DEMO0983
123 King St
Toronto, ON L7Z 3K8
Canada


TYPE: Purchase
ACCT: Visa  $ 5,013.00 USD
CARD NUMBER : ############1111
DATE/TIME   : 25 Sep 12 07:27:00
REFERENCE # :  000033 M
AUTHOR. #   :
TRANS. REF. : 77
Transaction not approved 605
Please retain this copy for your records.
=========================================</CTR>
    </TransactionResult>
    RESPONSE
  end

  def no_transaction_response
    yamlexcep = <<-RESPONSE
--- !ruby/exception:ActiveMerchant::ResponseError
message: Failed with 400 Bad Request
message:
response: !ruby/object:Net::HTTPBadRequest
  body: "Malformed request: Transaction Type is missing."
  body_exist: true
  code: "400"
  header:
    connection:
    - Close
    content-type:
    - text/html; charset=utf-8
    server:
    - Apache
    date:
    - Fri, 28 Sep 2012 18:21:37 GMT
    content-length:
    - "47"
    status:
    - "400"
    cache-control:
    - no-cache
  http_version: "1.1"
  message: Bad Request
  read: true
  socket:
    RESPONSE
    YAML.load(yamlexcep)
  end

  def successful_void_response
    <<-RESPONSE
    <?xml version="1.0" encoding="UTF-8"?>
  <TransactionResult>
    <ExactID>AD1234-56</ExactID>
    <Password></Password>
    <Transaction_Type>33</Transaction_Type>
    <DollarAmount>11.45</DollarAmount>
    <SurchargeAmount></SurchargeAmount>
    <Card_Number>############1111</Card_Number>
    <Transaction_Tag>987123</Transaction_Tag>
    <Track1></Track1>
    <Track2></Track2>
    <PAN></PAN>
    <Authorization_Num>ET112112</Authorization_Num>
    <Expiry_Date>0913</Expiry_Date>
    <CardHoldersName>Fred Burfle</CardHoldersName>
    <VerificationStr1></VerificationStr1>
    <VerificationStr2></VerificationStr2>
    <CVD_Presence_Ind>0</CVD_Presence_Ind>
    <ZipCode></ZipCode>
    <Tax1Amount></Tax1Amount>
    <Tax1Number></Tax1Number>
    <Tax2Amount></Tax2Amount>
    <Tax2Number></Tax2Number>
    <Secure_AuthRequired></Secure_AuthRequired>
    <Secure_AuthResult></Secure_AuthResult>
    <Ecommerce_Flag></Ecommerce_Flag>
    <XID></XID>
    <CAVV></CAVV>
    <CAVV_Algorithm></CAVV_Algorithm>
    <Reference_No></Reference_No>
    <Customer_Ref></Customer_Ref>
    <Reference_3></Reference_3>
    <Language></Language>
    <Client_IP>1.1.1.10</Client_IP>
    <Client_Email></Client_Email>
    <LogonMessage></LogonMessage>
    <Error_Number>0</Error_Number>
    <Error_Description> </Error_Description>
    <Transaction_Error>false</Transaction_Error>
    <Transaction_Approved>true</Transaction_Approved>
    <EXact_Resp_Code>00</EXact_Resp_Code>
    <EXact_Message>Transaction Normal</EXact_Message>
    <Bank_Resp_Code>100</Bank_Resp_Code>
    <Bank_Message>Approved</Bank_Message>
    <Bank_Resp_Code_2></Bank_Resp_Code_2>
    <SequenceNo>000166</SequenceNo>
    <AVS></AVS>
    <CVV2>I</CVV2>
    <Retrieval_Ref_No>2046743</Retrieval_Ref_No>
    <CAVV_Response></CAVV_Response>
    <Currency>USD</Currency>
    <AmountRequested></AmountRequested>
    <PartialRedemption>false</PartialRedemption>
    <MerchantName>FreshBooks DEMO0785</MerchantName>
    <MerchantAddress>35 Golden Ave</MerchantAddress>
    <MerchantCity>Toronto</MerchantCity>
    <MerchantProvince>Ontario</MerchantProvince>
    <MerchantCountry>Canada</MerchantCountry>
    <MerchantPostal>M6R 2J5</MerchantPostal>
    <MerchantURL></MerchantURL>
<CTR>=========== TRANSACTION RECORD ==========
FreshBooks DEMO0785
35 Golden Ave
Toronto, ON M6R 2J5
Canada


TYPE: Void

ACCT: Visa  $ 47.38 USD

CARD NUMBER : ############1111
DATE/TIME   : 15 Nov 12 08:20:36
REFERENCE # :  000166 M
AUTHOR. #   : ET112112
TRANS. REF. :

Approved - Thank You 100


Please retain this copy for your records.

Cardholder will pay above amount to card
issuer pursuant to cardholder agreement.
=========================================</CTR>
    </TransactionResult>
RESPONSE
  end
end
