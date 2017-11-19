require 'test_helper'
require 'nokogiri'
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

  def test_invalid_credentials
    @gateway.expects(:ssl_post).raises(bad_credentials_response)
    assert response = @gateway.store(@credit_card, {})
    assert_failure response
    assert response.test?
    assert_equal '', response.authorization
    assert_equal 'Unauthorized Request. Bad or missing credentials.', response.message
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'ET1700;106625152;4738', response.authorization
    assert response.test?
    assert_equal 'Transaction Normal - Approved', response.message

    FirstdataE4Gateway::SENSITIVE_FIELDS.each{|f| assert !response.params.has_key?(f.to_s)}
  end

  def test_successful_purchase_with_specified_currency
    options_with_specified_currency = @options.merge({currency: 'GBP'})
    @gateway.expects(:ssl_post).returns(successful_purchase_with_specified_currency_response)
    assert response = @gateway.purchase(@amount, @credit_card, options_with_specified_currency)
    assert_success response
    assert_equal 'ET1700;106625152;4738', response.authorization
    assert response.test?
    assert_equal 'Transaction Normal - Approved', response.message
    assert_equal 'GBP', response.params['currency']

    FirstdataE4Gateway::SENSITIVE_FIELDS.each{|f| assert !response.params.has_key?(f.to_s)}
  end

  def test_successful_purchase_with_token
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, '8938737759041111;visa;Longbob;Longsen;9;2014')
    assert_success response
  end

  def test_successful_purchase_with_specified_currency_and_token
    options_with_specified_currency = @options.merge({currency: 'GBP'})
    @gateway.expects(:ssl_post).returns(successful_purchase_with_specified_currency_response)
    assert response = @gateway.purchase(@amount, '8938737759041111;visa;Longbob;Longsen;9;2014',
                                        options_with_specified_currency)
    assert_success response
    assert_equal 'GBP', response.params['currency']
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

  def test_successful_refund_with_specified_currency
    options_with_specified_currency = @options.merge({currency: 'GBP'})
    @gateway.expects(:ssl_post).returns(successful_refund_with_specified_currency_response)
    assert response = @gateway.refund(@amount, @authorization, options_with_specified_currency)
    assert_success response
    assert_equal 'GBP', response.params['currency']
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
    assert_equal response.error_code, "invalid_expiry_date"
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_verify_response)
    assert_success response
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
    assert_equal ['CA', 'US'], FirstdataE4Gateway.supported_countries
  end

  def test_supported_cardtypes
    assert_equal [:visa, :master, :american_express, :jcb, :discover], FirstdataE4Gateway.supported_cardtypes
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
      assert_match "<VerificationStr1>456 My Street|K1C2N6|Ottawa|ON|CA</VerificationStr1>", data
    end.respond_with(successful_purchase_response)
  end

  def test_tax_fields_are_sent
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(tax1_amount: 830, tax1_number: "Br59a"))
    end.check_request do |endpoint, data, headers|
      assert_match "<Tax1Amount>830", data
      assert_match "<Tax1Number>Br59a", data
    end.respond_with(successful_purchase_response)
  end

  def test_customer_ref_is_sent
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(customer: "932"))
    end.check_request do |endpoint, data, headers|
      assert_match "<Customer_Ref>932", data
    end.respond_with(successful_purchase_response)
  end

  def test_eci_default_value
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match "<Ecommerce_Flag>07</Ecommerce_Flag>", data
    end.respond_with(successful_purchase_response)
  end

  def test_eci_numeric_padding
    @credit_card = network_tokenization_credit_card
    @credit_card.eci = "5"

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match "<Ecommerce_Flag>05</Ecommerce_Flag>", data
    end.respond_with(successful_purchase_response)

    @credit_card = network_tokenization_credit_card
    @credit_card.eci = 5

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match "<Ecommerce_Flag>05</Ecommerce_Flag>", data
    end.respond_with(successful_purchase_response)
  end

  def test_eci_option_value
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(eci: "05"))
    end.check_request do |endpoint, data, headers|
      assert_match "<Ecommerce_Flag>05</Ecommerce_Flag>", data
    end.respond_with(successful_purchase_response)
  end

  def test_network_tokenization_requests_with_amex
    stub_comms do
      credit_card = network_tokenization_credit_card(
        "378282246310005",
        brand: "american_express",
        transaction_id: "123",
        eci: "05",
        payment_cryptogram: "whatever_the_cryptogram_of_at_least_20_characters_is",
      )

      @gateway.purchase(@amount, credit_card, @options)
    end.check_request do |_, data, _|
      assert_match "<Ecommerce_Flag>05</Ecommerce_Flag>", data
      assert_match "<XID>mrLdtHIWq2nLXq7IrA==\n</XID>", data
      assert_match "<CAVV>whateverthecryptogramofatlc=\n</CAVV>", data
      assert_xml_valid_to_wsdl(data)
    end.respond_with(successful_purchase_response)
  end

  def test_network_tokenization_requests_with_other_brands
    %w(visa mastercard other).each do |brand|
      stub_comms do
        credit_card = network_tokenization_credit_card(
          "378282246310005",
          brand: brand,
          transaction_id: "123",
          eci: "05",
          payment_cryptogram: "whatever_the_cryptogram_is",
        )

        @gateway.purchase(@amount, credit_card, @options)
      end.check_request do |_, data, _|
        assert_match "<Ecommerce_Flag>05</Ecommerce_Flag>", data
        assert_match "<XID>123</XID>", data
        assert_match "<CAVV>whatever_the_cryptogram_is</CAVV>", data
        assert_xml_valid_to_wsdl(data)
      end.respond_with(successful_purchase_response)
    end
  end

  def test_requests_include_card_authentication_data
    authentication_hash = {
      eci: "06",
      cavv: "SAMPLECAVV",
      xid: "SAMPLEXID"
    }
    options_with_authentication_data = @options.merge(authentication_hash)

    stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_authentication_data)
    end.check_request do |endpoint, data, headers|
      assert_match "<Ecommerce_Flag>06</Ecommerce_Flag>", data
      assert_match "<CAVV>SAMPLECAVV</CAVV>", data
      assert_match "<XID>SAMPLEXID</XID>", data
      assert_xml_valid_to_wsdl(data)
    end.respond_with(successful_purchase_response)
  end

  def test_card_type
    assert_equal 'Visa', @gateway.send(:card_type, 'visa')
    assert_equal 'Mastercard', @gateway.send(:card_type, 'master')
    assert_equal 'Mastercard', @gateway.send(:card_type, 'mastercard')
    assert_equal 'American Express', @gateway.send(:card_type, 'american_express')
    assert_equal 'JCB', @gateway.send(:card_type, 'jcb')
    assert_equal 'Discover', @gateway.send(:card_type, 'discover')
  end

  def test_add_swipe_data_with_creditcard
    @credit_card.track_data = "Track Data"

    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match "<Track1>Track Data</Track1>", data
      assert_match "<Ecommerce_Flag>R</Ecommerce_Flag>", data
    end.respond_with(successful_purchase_response)
  end

  def test_supports_scrubbing?
    assert @gateway.supports_scrubbing?
  end

  def test_scrub
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_supports_network_tokenization
    assert_instance_of TrueClass, @gateway.supports_network_tokenization?
  end

  private

  def assert_xml_valid_to_wsdl(data)
    xsd = Nokogiri::XML::Schema(File.open("#{File.dirname(__FILE__)}/../../schema/firstdata_e4/v11.xsd"))
    doc = Nokogiri::XML(data)
    errors = xsd.validate(doc)
    assert_empty errors, "XSD validation errors in the following XML:\n#{doc}"
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to api.demo.globalgatewaye4.firstdata.com:443...
      opened
      starting SSL for api.demo.globalgatewaye4.firstdata.com:443...
      SSL established
      <- "POST /transaction/v11 HTTP/1.1\r\nContent-Type: application/xml\r\nAccepts: application/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.demo.globalgatewaye4.firstdata.com\r\nContent-Length: 593\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Transaction><ExactID>REDACTED</ExactID><Password>REDACTED</Password><Transaction_Type>00</Transaction_Type><DollarAmount>1.00</DollarAmount><Card_Number>4242424242424242</Card_Number><Expiry_Date>0916</Expiry_Date><CardHoldersName>Longbob Longsen</CardHoldersName><CardType>Visa</CardType><VerificationStr1>1234 My Street|K1C2N6|Ottawa|ON|CA</VerificationStr1><CVD_Presence_Ind>1</CVD_Presence_Ind><VerificationStr2>123</VerificationStr2><Reference_No>1</Reference_No><Reference_3>Store Purchase</Reference_3><CAVV>lol</CAVV><XID/><Ecommerce_Flag/></Transaction>"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
      -> "Content-Type: application/xml; charset=utf-8\r\n"
      -> "Date: Mon, 26 Jan 2015 17:11:44 GMT\r\n"
      -> "ETag: \"0a9a542fbfc55846e0ebe471b5725fe8\"\r\n"
      -> "Location: https://api.demo.globalgatewaye4.firstdata.com/transaction/v11/42930941\r\n"
      -> "Server: Apache\r\n"
      -> "Status: 201\r\n"
      -> "X-Rack-Cache: invalidate, pass\r\n"
      -> "X-Request-Id: e0fabf89d7d7272cab4d4d743327d036\r\n"
      -> "X-UA-Compatible: IE=Edge,chrome=1\r\n"
      -> "Content-Length: 2872\r\n"
      -> "Connection: Close\r\n"
      -> "\r\n"
      reading 2872 bytes...
      -> "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<TransactionResult>\n  <ExactID>AD2327-05</ExactID>\n  <Password></Password>\n  <Transaction_Type>00</Transaction_Type>\n  <DollarAmount>1.0</DollarAmount>\n  <SurchargeAmount></SurchargeAmount>\n  <Card_Number>############4242</Card_Number>\n  <Transaction_Tag>42930941</Transaction_Tag>\n  <Track1></Track1>\n  <Track2></Track2>\n  <PAN></PAN>\n  <Authorization_Num>ET151682</Authorization_Num>\n  <Expiry_Date>0916</Expiry_Date>\n  <CardHoldersName>Longbob Longsen</CardHoldersName>\n  <VerificationStr1>1234 My Street|K1C2N6|Ottawa|ON|CA</VerificationStr1>\n  <VerificationStr2>123</VerificationStr2>\n  <CVD_Presence_Ind>0</CVD_Presence_Ind>\n  <ZipCode></ZipCode>\n  <Tax1Amount></Tax1Amount>\n  <Tax1Number></Tax1Number>\n  <Tax2Amount></Tax2Amount>\n  <Tax2Number></Tax2Number>\n  <Secure_AuthRequired></Secure_AuthRequired>\n  <Secure_AuthResult></Secure_AuthResult>\n  <Ecommerce_Flag></Ecommerce_Flag>\n  <XID></XID>\n  <CAVV>lol</CAVV>\n  <CAVV_Algorithm></CAVV_Algorithm>\n  <Reference_No>1</Reference_No>\n  <Customer_Ref></Customer_Ref>\n  <Reference_3>Store Purchase</Reference_3>\n  <Language></Language>\n  <Client_IP>216.191.105.146</Client_IP>\n  <Client_Email></Client_Email>\n  <Transaction_Error>false</Transaction_Error>\n  <Transaction_Approved>true</Transaction_Approved>\n  <EXact_Resp_Code>00</EXact_Resp_Code>\n  <EXact_Message>Transaction Normal</EXact_Message>\n  <Bank_Resp_Code>100</Bank_Resp_Code>\n  <Bank_Message>Approved</Bank_Message>\n  <Bank_Resp_Code_2></Bank_Resp_Code_2>\n  <SequenceNo>106826</SequenceNo>\n  <AVS>1</AVS>\n  <CVV2>M</CVV2>\n  <Retrieval_Ref_No>0025564</Retrieval_Ref_No>\n  <CAVV_Response></CAVV_Response>\n  <Currency>USD</Currency>\n  <AmountRequested></AmountRequested>\n  <PartialRedemption>false</PartialRedemption>\n  <MerchantName>Shopify DEMO0678</MerchantName>\n  <MerchantAddress>126 York Street</MerchantAddress>\n  <MerchantCity>Ottawa</MerchantCity>\n  <MerchantProvince>Alabama</MerchantProvince>\n  <MerchantCountry>Canada</MerchantCountry>\n  <MerchantPostal>K1N 5T5</MerchantPostal>\n  <MerchantURL>www.shopify.com</MerchantURL>\n  <TransarmorToken></TransarmorToken>\n  <CardType>Visa</CardType>\n  <CurrentBalance></CurrentBalance>\n  <PreviousBalance></PreviousBalance>\n  <EAN></EAN>\n  <CardCost></CardCost>\n  <VirtualCard>false</VirtualCard>\n  <CTR>=========== TRANSACTION RECORD ==========\nShopify DEMO0678\n126 York Street\nOttawa, AL K1N 5T5\nCanada\nwww.shopify.com\n\nTY"
      -> "PE: Purchase\n\nACCT: Visa  $ 1.00 USD\n\nCARDHOLDER NAME : Longbob Longsen\nCARD NUMBER     : ############4242\nDATE/TIME       : 26 Jan 15 12:11:44\nREFERENCE #     :  106826 M\nAUTHOR. #       : ET151682\nTRANS. REF.     : 1\n\n    Approved - Thank You 100\n\n\nPlease retain this copy for your records.\n\nCardholder will pay above amount to card\nissuer pursuant to cardholder agreement.\n=========================================</CTR>\n</TransactionResult>\n"
      read 2872 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to api.demo.globalgatewaye4.firstdata.com:443...
      opened
      starting SSL for api.demo.globalgatewaye4.firstdata.com:443...
      SSL established
      <- "POST /transaction/v11 HTTP/1.1\r\nContent-Type: application/xml\r\nAccepts: application/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.demo.globalgatewaye4.firstdata.com\r\nContent-Length: 593\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Transaction><ExactID>REDACTED</ExactID><Password>REDACTED</Password><Transaction_Type>00</Transaction_Type><DollarAmount>1.00</DollarAmount><Card_Number>[FILTERED]</Card_Number><Expiry_Date>0916</Expiry_Date><CardHoldersName>Longbob Longsen</CardHoldersName><CardType>Visa</CardType><VerificationStr1>1234 My Street|K1C2N6|Ottawa|ON|CA</VerificationStr1><CVD_Presence_Ind>1</CVD_Presence_Ind><VerificationStr2>[FILTERED]</VerificationStr2><Reference_No>1</Reference_No><Reference_3>Store Purchase</Reference_3><CAVV>[FILTERED]</CAVV><XID/><Ecommerce_Flag/></Transaction>"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
      -> "Content-Type: application/xml; charset=utf-8\r\n"
      -> "Date: Mon, 26 Jan 2015 17:11:44 GMT\r\n"
      -> "ETag: \"0a9a542fbfc55846e0ebe471b5725fe8\"\r\n"
      -> "Location: https://api.demo.globalgatewaye4.firstdata.com/transaction/v11/42930941\r\n"
      -> "Server: Apache\r\n"
      -> "Status: 201\r\n"
      -> "X-Rack-Cache: invalidate, pass\r\n"
      -> "X-Request-Id: e0fabf89d7d7272cab4d4d743327d036\r\n"
      -> "X-UA-Compatible: IE=Edge,chrome=1\r\n"
      -> "Content-Length: 2872\r\n"
      -> "Connection: Close\r\n"
      -> "\r\n"
      reading 2872 bytes...
      -> "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<TransactionResult>\n  <ExactID>AD2327-05</ExactID>\n  <Password></Password>\n  <Transaction_Type>00</Transaction_Type>\n  <DollarAmount>1.0</DollarAmount>\n  <SurchargeAmount></SurchargeAmount>\n  <Card_Number>[FILTERED]</Card_Number>\n  <Transaction_Tag>42930941</Transaction_Tag>\n  <Track1></Track1>\n  <Track2></Track2>\n  <PAN></PAN>\n  <Authorization_Num>ET151682</Authorization_Num>\n  <Expiry_Date>0916</Expiry_Date>\n  <CardHoldersName>Longbob Longsen</CardHoldersName>\n  <VerificationStr1>1234 My Street|K1C2N6|Ottawa|ON|CA</VerificationStr1>\n  <VerificationStr2>[FILTERED]</VerificationStr2>\n  <CVD_Presence_Ind>0</CVD_Presence_Ind>\n  <ZipCode></ZipCode>\n  <Tax1Amount></Tax1Amount>\n  <Tax1Number></Tax1Number>\n  <Tax2Amount></Tax2Amount>\n  <Tax2Number></Tax2Number>\n  <Secure_AuthRequired></Secure_AuthRequired>\n  <Secure_AuthResult></Secure_AuthResult>\n  <Ecommerce_Flag></Ecommerce_Flag>\n  <XID></XID>\n  <CAVV>[FILTERED]</CAVV>\n  <CAVV_Algorithm></CAVV_Algorithm>\n  <Reference_No>1</Reference_No>\n  <Customer_Ref></Customer_Ref>\n  <Reference_3>Store Purchase</Reference_3>\n  <Language></Language>\n  <Client_IP>216.191.105.146</Client_IP>\n  <Client_Email></Client_Email>\n  <Transaction_Error>false</Transaction_Error>\n  <Transaction_Approved>true</Transaction_Approved>\n  <EXact_Resp_Code>00</EXact_Resp_Code>\n  <EXact_Message>Transaction Normal</EXact_Message>\n  <Bank_Resp_Code>100</Bank_Resp_Code>\n  <Bank_Message>Approved</Bank_Message>\n  <Bank_Resp_Code_2></Bank_Resp_Code_2>\n  <SequenceNo>106826</SequenceNo>\n  <AVS>1</AVS>\n  <CVV2>M</CVV2>\n  <Retrieval_Ref_No>0025564</Retrieval_Ref_No>\n  <CAVV_Response></CAVV_Response>\n  <Currency>USD</Currency>\n  <AmountRequested></AmountRequested>\n  <PartialRedemption>false</PartialRedemption>\n  <MerchantName>Shopify DEMO0678</MerchantName>\n  <MerchantAddress>126 York Street</MerchantAddress>\n  <MerchantCity>Ottawa</MerchantCity>\n  <MerchantProvince>Alabama</MerchantProvince>\n  <MerchantCountry>Canada</MerchantCountry>\n  <MerchantPostal>K1N 5T5</MerchantPostal>\n  <MerchantURL>www.shopify.com</MerchantURL>\n  <TransarmorToken></TransarmorToken>\n  <CardType>Visa</CardType>\n  <CurrentBalance></CurrentBalance>\n  <PreviousBalance></PreviousBalance>\n  <EAN></EAN>\n  <CardCost></CardCost>\n  <VirtualCard>false</VirtualCard>\n  <CTR>=========== TRANSACTION RECORD ==========\nShopify DEMO0678\n126 York Street\nOttawa, AL K1N 5T5\nCanada\nwww.shopify.com\n\nTY"
      -> "PE: Purchase\n\nACCT: Visa  $ 1.00 USD\n\nCARDHOLDER NAME : Longbob Longsen\nCARD NUMBER     : ############4242\nDATE/TIME       : 26 Jan 15 12:11:44\nREFERENCE #     :  106826 M\nAUTHOR. #       : ET151682\nTRANS. REF.     : 1\n\n    Approved - Thank You 100\n\n\nPlease retain this copy for your records.\n\nCardholder will pay above amount to card\nissuer pursuant to cardholder agreement.\n=========================================</CTR>\n</TransactionResult>\n"
      read 2872 bytes
      Conn close
    POST_SCRUBBED
  end

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
  def successful_purchase_with_specified_currency_response
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
    <Currency>GBP</Currency>
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

ACCT: Visa  £ 47.38 GBP

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

  def successful_refund_with_specified_currency_response
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
    <Currency>GBP</Currency>
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

ACCT: Visa  £ 23.69 GBP

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

  def successful_verify_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<TransactionResult>
  <ExactID>AD2552-05</ExactID>
  <Password></Password>
  <Transaction_Type>05</Transaction_Type>
  <DollarAmount>0.0</DollarAmount>
  <SurchargeAmount></SurchargeAmount>
  <Card_Number>############4242</Card_Number>
  <Transaction_Tag>25101911</Transaction_Tag>
  <Track1></Track1>
  <Track2></Track2>
  <PAN></PAN>
  <Authorization_Num>ET184931</Authorization_Num>
  <Expiry_Date>0915</Expiry_Date>
  <CardHoldersName>Longbob Longsen</CardHoldersName>
  <VerificationStr1>1234 My Street|K1C2N6|Ottawa|ON|CA</VerificationStr1>
  <VerificationStr2>123</VerificationStr2>
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
  <Reference_No>1</Reference_No>
  <Customer_Ref></Customer_Ref>
  <Reference_3>Store Purchase</Reference_3>
  <Language></Language>
  <Client_IP>75.182.123.244</Client_IP>
  <Client_Email></Client_Email>
  <Transaction_Error>false</Transaction_Error>
  <Transaction_Approved>true</Transaction_Approved>
  <EXact_Resp_Code>00</EXact_Resp_Code>
  <EXact_Message>Transaction Normal</EXact_Message>
  <Bank_Resp_Code>100</Bank_Resp_Code>
  <Bank_Message>Approved</Bank_Message>
  <Bank_Resp_Code_2></Bank_Resp_Code_2>
  <SequenceNo>000040</SequenceNo>
  <AVS>1</AVS>
  <CVV2>M</CVV2>
  <Retrieval_Ref_No>7228838</Retrieval_Ref_No>
  <CAVV_Response></CAVV_Response>
  <Currency>USD</Currency>
  <AmountRequested></AmountRequested>
  <PartialRedemption>false</PartialRedemption>
  <MerchantName>FriendlyInc</MerchantName>
  <MerchantAddress>123 Main Street</MerchantAddress>
  <MerchantCity>Durham</MerchantCity>
  <MerchantProvince>North Carolina</MerchantProvince>
  <MerchantCountry>United States</MerchantCountry>
  <MerchantPostal>27592</MerchantPostal>
  <MerchantURL></MerchantURL>
  <TransarmorToken></TransarmorToken>
  <CardType>Visa</CardType>
  <CurrentBalance></CurrentBalance>
  <PreviousBalance></PreviousBalance>
  <EAN></EAN>
  <CardCost></CardCost>
  <VirtualCard>false</VirtualCard>
  <CTR>=========== TRANSACTION RECORD ==========
FriendlyInc DEMO0
123 Main Street
Durham, NC 27592
United States


TYPE: Auth Only

ACCT: Visa  $ 0.00 USD

CARDHOLDER NAME : Longbob Longsen
CARD NUMBER     : ############4242
DATE/TIME       : 04 Jul 14 14:21:52
REFERENCE #     :  000040 M
AUTHOR. #       : ET184931
TRANS. REF.     : 1

    Approved - Thank You 100


Please retain this copy for your records.

Cardholder will pay above amount to card
issuer pursuant to cardholder agreement.
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

  def bad_credentials_response
    yamlexcep = <<-RESPONSE
--- !ruby/exception:ActiveMerchant::ResponseError
message:
response: !ruby/object:Net::HTTPUnauthorized
  code: '401'
  message: Authorization Required
  body: Unauthorized Request. Bad or missing credentials.
  read: true
  header:
    cache-control:
    - no-cache
    content-type:
    - text/html; charset=utf-8
    date:
    - Tue, 30 Dec 2014 23:28:32 GMT
    server:
    - Apache
    status:
    - '401'
    x-rack-cache:
    - invalidate, pass
    x-request-id:
    - 4157e21cc5620a95ead8d2025b55bdf4
    x-ua-compatible:
    - IE=Edge,chrome=1
    content-length:
    - '49'
    connection:
    - Close
  body_exist: true
  http_version: '1.1'
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
