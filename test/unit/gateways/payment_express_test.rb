require 'test_helper'

class PaymentExpressTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PaymentExpressGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @visa = credit_card

    @solo = credit_card("6334900000000005", :brand => "solo", :issue_number => '01')

    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :email => 'cody@example.com',
      :description => 'Store purchase'
    }

    @amount = 100
  end

  def test_default_currency
    assert_equal 'NZD', PaymentExpressGateway.default_currency
  end

  def test_invalid_credentials
    @gateway.expects(:ssl_post).returns(invalid_credentials_response)

    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_equal 'The transaction was Declined (AG)', response.message
    assert_failure response
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
    assert response.test?
    assert_equal 'The Transaction was approved', response.message
    assert_equal '00000004011a2478', response.authorization
  end

  def test_purchase_request_should_include_cvc2_presence
    @gateway.expects(:commit).with do |type, request|
      type == :purchase && request.to_s =~ %r{<Cvc2Presence>1<\/Cvc2Presence>}
    end

    @gateway.purchase(@amount, @visa, @options)
  end

  def test_successful_solo_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.purchase(@amount, @solo, @options)
    assert_success response
    assert response.test?
    assert_equal 'The Transaction was approved', response.message
    assert_equal '00000004011a2478', response.authorization
  end

  def test_successful_card_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@visa)
    assert_success response
    assert response.test?
    assert_equal '0000030000141581', response.authorization
    assert_equal response.authorization, response.token
  end

  def test_successful_card_store_with_custom_billing_id
    @gateway.expects(:ssl_post).returns(successful_store_response(:billing_id => "my-custom-id"))

    assert response = @gateway.store(@visa, :billing_id => "my-custom-id")
    assert_success response
    assert response.test?
    assert_equal 'my-custom-id', response.token
  end

  def test_unsuccessful_card_store
    @gateway.expects(:ssl_post).returns(unsuccessful_store_response)

    @visa.number = 2

    assert response = @gateway.store(@visa)
    assert_failure response
  end

  def test_purchase_using_dps_billing_id_token
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@visa)
    token = response.token

    @gateway.expects(:ssl_post).returns(successful_dps_billing_id_token_purchase_response)

    assert response = @gateway.purchase(@amount, token, @options)
    assert_success response
    assert_equal 'The Transaction was approved', response.message
    assert_equal '0000000303ace8db', response.authorization
  end

  def test_purchase_using_merchant_specified_billing_id_token
    @gateway = PaymentExpressGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD',
      :use_custom_payment_token => true
    )

    @gateway.expects(:ssl_post).returns(successful_store_response({:billing_id => 'TEST1234'}))

    assert response = @gateway.store(@visa, {:billing_id => 'TEST1234'})
    assert_equal 'TEST1234', response.token

    @gateway.expects(:ssl_post).returns(successful_billing_id_token_purchase_response)

    assert response = @gateway.purchase(@amount, 'TEST1234', @options)
    assert_success response
    assert_equal 'The Transaction was approved', response.message
    assert_equal '0000000303ace8db', response.authorization
  end

  def test_supported_countries
    assert_equal %w(AU FJ GB HK IE MY NZ PG SG US), PaymentExpressGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [ :visa, :master, :american_express, :diners_club, :jcb ], PaymentExpressGateway.supported_cardtypes
  end

  def test_avs_result_not_supported
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    response = @gateway.purchase(@amount, @visa, @options)
    assert_nil response.avs_result['code']
  end

  def test_cvv_result_not_supported
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    response = @gateway.purchase(@amount, @visa, @options)
    assert_nil response.cvv_result['code']
  end

  def test_expect_no_optional_fields_by_default
    perform_each_transaction_type_with_request_body_assertions do |body|
      assert_no_match(/<ClientType>/, body)
      assert_no_match(/<TxnData1>/, body)
      assert_no_match(/<TxnData2>/, body)
      assert_no_match(/<TxnData3>/, body)
    end
  end

  def test_pass_optional_txn_data
    options = {
      :txn_data1 => "Transaction Data 1",
      :txn_data2 => "Transaction Data 2",
      :txn_data3 => "Transaction Data 3"
    }

    perform_each_transaction_type_with_request_body_assertions(options) do |body|
      assert_match(/<TxnData1>Transaction Data 1<\/TxnData1>/, body)
      assert_match(/<TxnData2>Transaction Data 2<\/TxnData2>/, body)
      assert_match(/<TxnData3>Transaction Data 3<\/TxnData3>/, body)
    end
  end

  def test_pass_optional_txn_data_truncated_to_255_chars
    options = {
      :txn_data1 => "Transaction Data 1-01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345-EXTRA",
      :txn_data2 => "Transaction Data 2-01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345-EXTRA",
      :txn_data3 => "Transaction Data 3-01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345-EXTRA"
    }

    truncated_addendum = "01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345"

    perform_each_transaction_type_with_request_body_assertions(options) do |body|
      assert_match(/<TxnData1>Transaction Data 1-#{truncated_addendum}<\/TxnData1>/, body)
      assert_match(/<TxnData2>Transaction Data 2-#{truncated_addendum}<\/TxnData2>/, body)
      assert_match(/<TxnData3>Transaction Data 3-#{truncated_addendum}<\/TxnData3>/, body)
    end
  end

  def test_pass_client_type_as_symbol_for_web
    options = {:client_type => :web}

    perform_each_transaction_type_with_request_body_assertions(options) do |body|
      assert_match(/<ClientType>Web<\/ClientType>/, body)
    end
  end

  def test_pass_client_type_as_symbol_for_ivr
    options = {:client_type => :ivr}

    perform_each_transaction_type_with_request_body_assertions(options) do |body|
      assert_match(/<ClientType>IVR<\/ClientType>/, body)
    end
  end

  def test_pass_client_type_as_symbol_for_moto
    options = {:client_type => :moto}

    perform_each_transaction_type_with_request_body_assertions(options) do |body|
      assert_match(/<ClientType>MOTO<\/ClientType>/, body)
    end
  end

  def test_pass_client_type_as_symbol_for_unattended
    options = {:client_type => :unattended}

    perform_each_transaction_type_with_request_body_assertions(options) do |body|
      assert_match(/<ClientType>Unattended<\/ClientType>/, body)
    end
  end

  def test_pass_client_type_as_symbol_for_internet
    options = {:client_type => :internet}

    perform_each_transaction_type_with_request_body_assertions(options) do |body|
      assert_match(/<ClientType>Internet<\/ClientType>/, body)
    end
  end

  def test_pass_client_type_as_symbol_for_recurring
    options = {:client_type => :recurring}

    perform_each_transaction_type_with_request_body_assertions(options) do |body|
      assert_match(/<ClientType>Recurring<\/ClientType>/, body)
    end
  end

  def test_pass_client_type_as_symbol_for_unknown_type_omits_element
    options = {:client_type => :unknown}

    perform_each_transaction_type_with_request_body_assertions(options) do |body|
      assert_no_match(/<ClientType>/, body)
    end
  end

  def test_purchase_truncates_order_id_to_16_chars
    stub_comms do
      @gateway.purchase(@amount, @visa, {:order_id => "16chars---------EXTRA"})
    end.check_request do |endpoint, data, headers|
      assert_match(/<TxnId>16chars---------<\/TxnId>/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_authorize_truncates_order_id_to_16_chars
    stub_comms do
      @gateway.authorize(@amount, @visa, {:order_id => "16chars---------EXTRA"})
    end.check_request do |endpoint, data, headers|
      assert_match(/<TxnId>16chars---------<\/TxnId>/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_capture_truncates_order_id_to_16_chars
    stub_comms do
      @gateway.capture(@amount, 'identification', {:order_id => "16chars---------EXTRA"})
    end.check_request do |endpoint, data, headers|
      assert_match(/<TxnId>16chars---------<\/TxnId>/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_refund_truncates_order_id_to_16_chars
    stub_comms do
      @gateway.refund(@amount, 'identification', {:description => 'refund', :order_id => "16chars---------EXTRA"})
    end.check_request do |endpoint, data, headers|
      assert_match(/<TxnId>16chars---------<\/TxnId>/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_purchase_truncates_description_to_50_chars
    stub_comms do
      @gateway.purchase(@amount, @visa, {:description => "50chars-------------------------------------------EXTRA"})
    end.check_request do |endpoint, data, headers|
      assert_match(/<MerchantReference>50chars-------------------------------------------<\/MerchantReference>/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_authorize_truncates_description_to_50_chars
    stub_comms do
      @gateway.authorize(@amount, @visa, {:description => "50chars-------------------------------------------EXTRA"})
    end.check_request do |endpoint, data, headers|
      assert_match(/<MerchantReference>50chars-------------------------------------------<\/MerchantReference>/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_capture_truncates_description_to_50_chars
    stub_comms do
      @gateway.capture(@amount, 'identification', {:description => "50chars-------------------------------------------EXTRA"})
    end.check_request do |endpoint, data, headers|
      assert_match(/<MerchantReference>50chars-------------------------------------------<\/MerchantReference>/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_refund_truncates_description_to_50_chars
    stub_comms do
      @gateway.capture(@amount, 'identification', {:description => "50chars-------------------------------------------EXTRA"})
    end.check_request do |endpoint, data, headers|
      assert_match(/<MerchantReference>50chars-------------------------------------------<\/MerchantReference>/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def perform_each_transaction_type_with_request_body_assertions(options = {})
    # purchase
    stub_comms do
      @gateway.purchase(@amount, @visa, options)
    end.check_request do |endpoint, data, headers|
      yield data
    end.respond_with(successful_authorization_response)

    # authorize
    stub_comms do
      @gateway.authorize(@amount, @visa, options)
    end.check_request do |endpoint, data, headers|
      yield data
    end.respond_with(successful_authorization_response)

    # capture
    stub_comms do
      @gateway.capture(@amount, 'identification', options)
    end.check_request do |endpoint, data, headers|
      yield data
    end.respond_with(successful_authorization_response)

    # refund
    stub_comms do
      @gateway.refund(@amount, 'identification', {:description => "description"}.merge(options))
    end.check_request do |endpoint, data, headers|
      yield data
    end.respond_with(successful_authorization_response)

    # store
    stub_comms do
      @gateway.store(@visa, options)
    end.check_request do |endpoint, data, headers|
      yield data
    end.respond_with(successful_store_response)
  end

  def billing_id_token_purchase(options = {})
    "<Txn><BillingId>#{options[:billing_id]}</BillingId><Amount>1.00</Amount><InputCurrency>NZD</InputCurrency><TxnId>aaa050be9488e8e4</TxnId><MerchantReference>Store purchase</MerchantReference><EnableAvsData>1</EnableAvsData><AvsAction>1</AvsAction><AvsStreetAddress>1234 My Street</AvsStreetAddress><AvsPostCode>K1C2N6</AvsPostCode><PostUsername>LOGIN</PostUsername><PostPassword>PASSWORD</PostPassword><TxnType>Purchase</TxnType></Txn>"
  end

  def invalid_credentials_response
    '<Txn><ReCo>0</ReCo><ResponseText>Invalid Credentials</ResponseText><CardHolderHelpText>The transaction was Declined (AG)</CardHolderHelpText></Txn>'
  end

  def successful_authorization_response
    <<-RESPONSE
<Txn>
  <Transaction success="1" reco="00" responsetext="APPROVED">
    <Authorized>1</Authorized>
    <MerchantReference>Test Transaction</MerchantReference>
    <Cvc2>M</Cvc2>
    <CardName>Visa</CardName>
    <Retry>0</Retry>
    <StatusRequired>0</StatusRequired>
    <AuthCode>015921</AuthCode>
    <Amount>1.23</Amount>
    <InputCurrencyId>1</InputCurrencyId>
    <InputCurrencyName>NZD</InputCurrencyName>
    <Acquirer>WestpacTrust</Acquirer>
    <CurrencyId>1</CurrencyId>
    <CurrencyName>NZD</CurrencyName>
    <CurrencyRate>1.00</CurrencyRate>
    <Acquirer>WestpacTrust</Acquirer>
    <AcquirerDate>30102000</AcquirerDate>
    <AcquirerId>1</AcquirerId>
    <CardHolderName>DPS</CardHolderName>
    <DateSettlement>20050811</DateSettlement>
    <TxnType>Purchase</TxnType>
    <CardNumber>411111</CardNumber>
    <DateExpiry>0807</DateExpiry>
    <ProductId></ProductId>
    <AcquirerDate>20050811</AcquirerDate>
    <AcquirerTime>060039</AcquirerTime>
    <AcquirerId>9000</AcquirerId>
    <Acquirer>Test</Acquirer>
    <TestMode>1</TestMode>
    <CardId>2</CardId>
    <CardHolderResponseText>APPROVED</CardHolderResponseText>
    <CardHolderHelpText>The Transaction was approved</CardHolderHelpText>
    <CardHolderResponseDescription>The Transaction was approved</CardHolderResponseDescription>
    <MerchantResponseText>APPROVED</MerchantResponseText>
    <MerchantHelpText>The Transaction was approved</MerchantHelpText>
    <MerchantResponseDescription>The Transaction was approved</MerchantResponseDescription>
    <GroupAccount>9997</GroupAccount>
    <DpsTxnRef>00000004011a2478</DpsTxnRef>
    <AllowRetry>0</AllowRetry>
    <DpsBillingId></DpsBillingId>
    <BillingId></BillingId>
    <TransactionId>011a2478</TransactionId>
  </Transaction>
  <ReCo>00</ReCo>
  <ResponseText>APPROVED</ResponseText>
  <HelpText>The Transaction was approved</HelpText>
  <Success>1</Success>
  <TxnRef>00000004011a2478</TxnRef>
</Txn>
    RESPONSE
  end

  def successful_store_response(options = {})
    %(<Txn><Transaction success="1" reco="00" responsetext="APPROVED"><Authorized>1</Authorized><MerchantReference></MerchantReference><CardName>Visa</CardName><Retry>0</Retry><StatusRequired>0</StatusRequired><AuthCode>02381203accf5c00000003</AuthCode><Amount>0.01</Amount><CurrencyId>554</CurrencyId><InputCurrencyId>554</InputCurrencyId><InputCurrencyName>NZD</InputCurrencyName><CurrencyRate>1.00</CurrencyRate><CurrencyName>NZD</CurrencyName><CardHolderName>BOB BOBSEN</CardHolderName><DateSettlement>20070323</DateSettlement><TxnType>Auth</TxnType><CardNumber>424242........42</CardNumber><DateExpiry>0809</DateExpiry><ProductId></ProductId><AcquirerDate>20070323</AcquirerDate><AcquirerTime>023812</AcquirerTime><AcquirerId>9000</AcquirerId><Acquirer>Test</Acquirer><TestMode>1</TestMode><CardId>2</CardId><CardHolderResponseText>APPROVED</CardHolderResponseText><CardHolderHelpText>The Transaction was approved</CardHolderHelpText><CardHolderResponseDescription>The Transaction was approved</CardHolderResponseDescription><MerchantResponseText>APPROVED</MerchantResponseText><MerchantHelpText>The Transaction was approved</MerchantHelpText><MerchantResponseDescription>The Transaction was approved</MerchantResponseDescription><UrlFail></UrlFail><UrlSuccess></UrlSuccess><EnablePostResponse>0</EnablePostResponse><PxPayName></PxPayName><PxPayLogoSrc></PxPayLogoSrc><PxPayUserId></PxPayUserId><PxPayXsl></PxPayXsl><PxPayBgColor></PxPayBgColor><AcquirerPort>9999999999-99999999</AcquirerPort><AcquirerTxnRef>12835</AcquirerTxnRef><GroupAccount>9997</GroupAccount><DpsTxnRef>0000000303accf5c</DpsTxnRef><AllowRetry>0</AllowRetry><DpsBillingId>0000030000141581</DpsBillingId><BillingId>#{options[:billing_id]}</BillingId><TransactionId>03accf5c</TransactionId><PxHostId>00000003</PxHostId></Transaction><ReCo>00</ReCo><ResponseText>APPROVED</ResponseText><HelpText>The Transaction was approved</HelpText><Success>1</Success><DpsTxnRef>0000000303accf5c</DpsTxnRef><TxnRef></TxnRef></Txn>)
  end

  def unsuccessful_store_response(options = {})
    %(<Txn><Transaction success="0" reco="QK" responsetext="INVALID CARD NUMBER"><Authorized>0</Authorized><MerchantReference></MerchantReference><CardName></CardName><Retry>0</Retry><StatusRequired>0</StatusRequired><AuthCode></AuthCode><Amount>0.01</Amount><CurrencyId>554</CurrencyId><InputCurrencyId>554</InputCurrencyId><InputCurrencyName>NZD</InputCurrencyName><CurrencyRate>1.00</CurrencyRate><CurrencyName>NZD</CurrencyName><CardHolderName>LONGBOB LONGSEN</CardHolderName><DateSettlement>19800101</DateSettlement><TxnType>Validate</TxnType><CardNumber>000000........00</CardNumber><DateExpiry>0808</DateExpiry><ProductId></ProductId><AcquirerDate></AcquirerDate><AcquirerTime></AcquirerTime><AcquirerId>9000</AcquirerId><Acquirer></Acquirer><TestMode>0</TestMode><CardId>0</CardId><CardHolderResponseText>INVALID CARD NUMBER</CardHolderResponseText><CardHolderHelpText>An Invalid Card Number was entered. Check the card number</CardHolderHelpText><CardHolderResponseDescription>An Invalid Card Number was entered. Check the card number</CardHolderResponseDescription><MerchantResponseText>INVALID CARD NUMBER</MerchantResponseText><MerchantHelpText>An Invalid Card Number was entered. Check the card number</MerchantHelpText><MerchantResponseDescription>An Invalid Card Number was entered. Check the card number</MerchantResponseDescription><UrlFail></UrlFail><UrlSuccess></UrlSuccess><EnablePostResponse>0</EnablePostResponse><PxPayName></PxPayName><PxPayLogoSrc></PxPayLogoSrc><PxPayUserId></PxPayUserId><PxPayXsl></PxPayXsl><PxPayBgColor></PxPayBgColor><AcquirerPort>9999999999-99999999</AcquirerPort><AcquirerTxnRef>0</AcquirerTxnRef><GroupAccount>9997</GroupAccount><DpsTxnRef></DpsTxnRef><AllowRetry>0</AllowRetry><DpsBillingId></DpsBillingId><BillingId></BillingId><TransactionId>00000000</TransactionId><PxHostId>00000003</PxHostId></Transaction><ReCo>QK</ReCo><ResponseText>INVALID CARD NUMBER</ResponseText><HelpText>An Invalid Card Number was entered. Check the card number</HelpText><Success>0</Success><DpsTxnRef></DpsTxnRef><TxnRef></TxnRef></Txn>)
  end

  def successful_dps_billing_id_token_purchase_response
    %(<Txn><Transaction success="1" reco="00" responsetext="APPROVED"><Authorized>1</Authorized><MerchantReference></MerchantReference><CardName>Visa</CardName><Retry>0</Retry><StatusRequired>0</StatusRequired><AuthCode>030817</AuthCode><Amount>10.00</Amount><CurrencyId>554</CurrencyId><InputCurrencyId>554</InputCurrencyId><InputCurrencyName>NZD</InputCurrencyName><CurrencyRate>1.00</CurrencyRate><CurrencyName>NZD</CurrencyName><CardHolderName>LONGBOB LONGSEN</CardHolderName><DateSettlement>20070323</DateSettlement><TxnType>Purchase</TxnType><CardNumber>424242........42</CardNumber><DateExpiry>0808</DateExpiry><ProductId></ProductId><AcquirerDate>20070323</AcquirerDate><AcquirerTime>030817</AcquirerTime><AcquirerId>9000</AcquirerId><Acquirer>Test</Acquirer><TestMode>1</TestMode><CardId>2</CardId><CardHolderResponseText>APPROVED</CardHolderResponseText><CardHolderHelpText>The Transaction was approved</CardHolderHelpText><CardHolderResponseDescription>The Transaction was approved</CardHolderResponseDescription><MerchantResponseText>APPROVED</MerchantResponseText><MerchantHelpText>The Transaction was approved</MerchantHelpText><MerchantResponseDescription>The Transaction was approved</MerchantResponseDescription><UrlFail></UrlFail><UrlSuccess></UrlSuccess><EnablePostResponse>0</EnablePostResponse><PxPayName></PxPayName><PxPayLogoSrc></PxPayLogoSrc><PxPayUserId></PxPayUserId><PxPayXsl></PxPayXsl><PxPayBgColor></PxPayBgColor><AcquirerPort>9999999999-99999999</AcquirerPort><AcquirerTxnRef>12859</AcquirerTxnRef><GroupAccount>9997</GroupAccount><DpsTxnRef>0000000303ace8db</DpsTxnRef><AllowRetry>0</AllowRetry><DpsBillingId>0000030000141581</DpsBillingId><BillingId></BillingId><TransactionId>03ace8db</TransactionId><PxHostId>00000003</PxHostId></Transaction><ReCo>00</ReCo><ResponseText>APPROVED</ResponseText><HelpText>The Transaction was approved</HelpText><Success>1</Success><DpsTxnRef>0000000303ace8db</DpsTxnRef><TxnRef></TxnRef></Txn>)
  end

  def successful_billing_id_token_purchase_response
    %(<Txn><Transaction success="1" reco="00" responsetext="APPROVED"><Authorized>1</Authorized><MerchantReference></MerchantReference><CardName>Visa</CardName><Retry>0</Retry><StatusRequired>0</StatusRequired><AuthCode>030817</AuthCode><Amount>10.00</Amount><CurrencyId>554</CurrencyId><InputCurrencyId>554</InputCurrencyId><InputCurrencyName>NZD</InputCurrencyName><CurrencyRate>1.00</CurrencyRate><CurrencyName>NZD</CurrencyName><CardHolderName>LONGBOB LONGSEN</CardHolderName><DateSettlement>20070323</DateSettlement><TxnType>Purchase</TxnType><CardNumber>424242........42</CardNumber><DateExpiry>0808</DateExpiry><ProductId></ProductId><AcquirerDate>20070323</AcquirerDate><AcquirerTime>030817</AcquirerTime><AcquirerId>9000</AcquirerId><Acquirer>Test</Acquirer><TestMode>1</TestMode><CardId>2</CardId><CardHolderResponseText>APPROVED</CardHolderResponseText><CardHolderHelpText>The Transaction was approved</CardHolderHelpText><CardHolderResponseDescription>The Transaction was approved</CardHolderResponseDescription><MerchantResponseText>APPROVED</MerchantResponseText><MerchantHelpText>The Transaction was approved</MerchantHelpText><MerchantResponseDescription>The Transaction was approved</MerchantResponseDescription><UrlFail></UrlFail><UrlSuccess></UrlSuccess><EnablePostResponse>0</EnablePostResponse><PxPayName></PxPayName><PxPayLogoSrc></PxPayLogoSrc><PxPayUserId></PxPayUserId><PxPayXsl></PxPayXsl><PxPayBgColor></PxPayBgColor><AcquirerPort>9999999999-99999999</AcquirerPort><AcquirerTxnRef>12859</AcquirerTxnRef><GroupAccount>9997</GroupAccount><DpsTxnRef>0000000303ace8db</DpsTxnRef><AllowRetry>0</AllowRetry><DpsBillingId></DpsBillingId><BillingId>TEST1234</BillingId><TransactionId>03ace8db</TransactionId><PxHostId>00000003</PxHostId></Transaction><ReCo>00</ReCo><ResponseText>APPROVED</ResponseText><HelpText>The Transaction was approved</HelpText><Success>1</Success><DpsTxnRef>0000000303ace8db</DpsTxnRef><TxnRef></TxnRef></Txn>)
  end

  def transcript
    %(<Txn><CardHolderName>Longbob Longsen</CardHolderName><CardNumber>4111111111111111</CardNumber><DateExpiry>0916</DateExpiry><Cvc2>123</Cvc2><Cvc2Presence>1</Cvc2Presence><Amount>1.00</Amount><InputCurrency>NZD</InputCurrency><TxnId>59956b468905bde7</TxnId><MerchantReference>Store purchase</MerchantReference><EnableAvsData>1</EnableAvsData><AvsAction>1</AvsAction><AvsStreetAddress>456 My Street</AvsStreetAddress><AvsPostCode>K1C2N6</AvsPostCode><PostUsername>WaysactDev</PostUsername><PostPassword>kvr52dw9</PostPassword><TxnType>Purchase</TxnType></Txn>)
  end

  def scrubbed_transcript
    %(<Txn><CardHolderName>Longbob Longsen</CardHolderName><CardNumber>[FILTERED]</CardNumber><DateExpiry>0916</DateExpiry><Cvc2>[FILTERED]</Cvc2><Cvc2Presence>1</Cvc2Presence><Amount>1.00</Amount><InputCurrency>NZD</InputCurrency><TxnId>59956b468905bde7</TxnId><MerchantReference>Store purchase</MerchantReference><EnableAvsData>1</EnableAvsData><AvsAction>1</AvsAction><AvsStreetAddress>456 My Street</AvsStreetAddress><AvsPostCode>K1C2N6</AvsPostCode><PostUsername>WaysactDev</PostUsername><PostPassword>kvr52dw9</PostPassword><TxnType>Purchase</TxnType></Txn>)
  end
end
