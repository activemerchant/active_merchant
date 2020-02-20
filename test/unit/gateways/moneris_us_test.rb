require 'test_helper'

class MonerisUsTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = MonerisUsGateway.new(
      :login => 'monusqa002',
      :password => 'qatoken'
    )

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @check = check({
      routing_number: '011000015',
      account_number: '1234455',
      number: 123
    })
    @options = { :order_id => '1', :billing_address => address }
  end

  def test_default_options
    assert_equal 7, @gateway.options[:crypt_type]
    assert_equal 'monusqa002', @gateway.options[:login]
    assert_equal 'qatoken', @gateway.options[:password]
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.authorize(100, @credit_card, @options)
    assert_success response
    assert_equal '58-0_3;1026.1', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.authorize(100, @credit_card, @options)
    assert_failure response
  end

  def test_successful_echeck_purchase
    @gateway.expects(:ssl_post).returns(successful_echeck_purchase_response)

    assert response = @gateway.authorize(100, @check, @options)
    assert_success response
    assert_equal '1522-0_25;cb80f38f44af2168fd9033cdf2d0d4c0', response.authorization
  end

  def test_deprecated_credit
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/txn_number>123<\//), anything).returns('')
    @gateway.expects(:parse).returns({})
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE) do
      @gateway.credit(@amount, '123;456', @options)
    end
  end

  def test_refund
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/txn_number>123<\//), anything).returns('')
    @gateway.expects(:parse).returns({})
    @gateway.refund(@amount, '123;456', @options)
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
    assert_equal '830337-0_25;d315c7a28623dec77dc136450692d2dd', response.authorization
  end

  def test_successful_verify_and_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_capture_response)
    assert_success response
    assert_equal '830337-0_25;d315c7a28623dec77dc136450692d2dd', response.authorization
    assert_equal 'Approved', response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response, successful_capture_response)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_amount_style
    assert_equal '10.34', @gateway.send(:amount, 1034)

    assert_raise(ArgumentError) do
      @gateway.send(:amount, '10.34')
    end
  end

  def test_preauth_is_valid_xml
    params = {
      :order_id => 'order1',
      :amount => '1.01',
      :pan => '4242424242424242',
      :expdate => '0303',
      :crypt_type => 7,
    }

    assert data = @gateway.send(:post_data, 'us_preauth', params)
    assert REXML::Document.new(data)
    assert_equal xml_capture_fixture.size, data.size
  end

  def test_purchase_is_valid_xml
    params = {
      :order_id => 'order1',
      :amount => '1.01',
      :pan => '4242424242424242',
      :expdate => '0303',
      :crypt_type => 7,
    }

    assert data = @gateway.send(:post_data, 'us_purchase', params)
    assert REXML::Document.new(data)
    assert_equal xml_purchase_fixture.size, data.size
  end

  def test_capture_is_valid_xml
    params = {
      :order_id => 'order1',
      :amount => '1.01',
      :pan => '4242424242424242',
      :expdate => '0303',
      :crypt_type => 7,
    }

    assert data = @gateway.send(:post_data, 'us_preauth', params)
    assert REXML::Document.new(data)
    assert_equal xml_capture_fixture.size, data.size
  end

  def test_supported_countries
    assert_equal ['US'], MonerisUsGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :diners_club, :discover], MonerisUsGateway.supported_cardtypes
  end

  def test_should_raise_error_if_transaction_param_empty_on_credit_request
    [nil, '', '1234'].each do |invalid_transaction_param|
      assert_raise(ArgumentError) { @gateway.void(invalid_transaction_param) }
    end
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'Successfully registered cc details', response.message
    assert response.params['data_key'].present?
    @data_key = response.params['data_key']
  end

  def test_successful_unstore
    @gateway.expects(:ssl_post).returns(successful_unstore_response)
    test_successful_store
    assert response = @gateway.unstore(@data_key)
    assert_success response
    assert_equal 'Successfully deleted cc details', response.message
    assert response.params['data_key'].present?
  end

  def test_update
    @gateway.expects(:ssl_post).returns(successful_update_response)
    test_successful_store
    assert response = @gateway.update(@data_key, @credit_card)
    assert_success response
    assert_equal 'Successfully updated cc details', response.message
    assert response.params['data_key'].present?
  end

  def test_successful_purchase_with_vault
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    test_successful_store
    assert response = @gateway.purchase(100, @data_key, {:order_id => generate_unique_id, :customer => generate_unique_id})
    assert_success response
    assert_equal 'Approved', response.message
    assert response.authorization.present?
  end

  def test_successful_authorization_with_vault
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    test_successful_store
    assert response = @gateway.authorize(100, @data_key, {:order_id => generate_unique_id, :customer => generate_unique_id})
    assert_success response
    assert_equal 'Approved', response.message
    assert response.authorization.present?
  end

  def test_failed_authorization_with_vault
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    test_successful_store
    assert response = @gateway.authorize(100, @data_key, @options)
    assert_failure response
  end

  def test_cvv_enabled_and_provided
    gateway = MonerisGateway.new(login: 'store1', password: 'yesguy', cvv_enabled: true)

    @credit_card.verification_value = '452'
    stub_comms(gateway) do
      gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{cvd_indicator>1<}, data)
      assert_match(%r{cvd_value>452<}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_cvv_enabled_but_not_provided
    gateway = MonerisGateway.new(login: 'store1', password: 'yesguy', cvv_enabled: true)

    @credit_card.verification_value = ''
    stub_comms(gateway) do
      gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{cvd_indicator>0<}, data)
      assert_no_match(%r{cvd_value>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_cvv_disabled_and_provided
    @credit_card.verification_value = '452'
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_no_match(%r{cvd_value>}, data)
      assert_no_match(%r{cvd_indicator>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_cvv_disabled_but_not_provided
    @credit_card.verification_value = ''
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_no_match(%r{cvd_value>}, data)
      assert_no_match(%r{cvd_indicator>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_avs_enabled_and_provided
    gateway = MonerisGateway.new(login: 'store1', password: 'yesguy', avs_enabled: true)

    billing_address = address(address1: '1234 Anystreet', address2: '')
    stub_comms(gateway) do
      gateway.purchase(@amount, @credit_card, billing_address: billing_address, order_id: '1')
    end.check_request do |endpoint, data, headers|
      assert_match(%r{avs_street_number>1234<}, data)
      assert_match(%r{avs_street_name>Anystreet<}, data)
      assert_match(%r{avs_zipcode>#{billing_address[:zip]}<}, data)
    end.respond_with(successful_purchase_response_with_avs_result)
  end

  def test_avs_enabled_but_not_provided
    gateway = MonerisGateway.new(login: 'store1', password: 'yesguy', avs_enabled: true)

    stub_comms(gateway) do
      gateway.purchase(@amount, @credit_card, @options.tap { |x| x.delete(:billing_address) })
    end.check_request do |endpoint, data, headers|
      assert_no_match(%r{avs_street_number>}, data)
      assert_no_match(%r{avs_street_name>}, data)
      assert_no_match(%r{avs_zipcode>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_avs_disabled_and_provided
    billing_address = address(address1: '1234 Anystreet', address2: '')
    stub_comms do
      @gateway.purchase(@amount, @credit_card, billing_address: billing_address, order_id: '1')
    end.check_request do |endpoint, data, headers|
      assert_no_match(%r{avs_street_number>}, data)
      assert_no_match(%r{avs_street_name>}, data)
      assert_no_match(%r{avs_zipcode>}, data)
    end.respond_with(successful_purchase_response_with_avs_result)
  end

  def test_avs_disabled_and_not_provided
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.tap { |x| x.delete(:billing_address) })
    end.check_request do |endpoint, data, headers|
      assert_no_match(%r{avs_street_number>}, data)
      assert_no_match(%r{avs_street_name>}, data)
      assert_no_match(%r{avs_zipcode>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_avs_result_valid_with_address
    @gateway.expects(:ssl_post).returns(successful_purchase_response_with_avs_result)
    assert response = @gateway.purchase(100, @credit_card, @options)
    assert_equal(response.avs_result, {
      'code' => 'A',
      'message' => 'Street address matches, but postal code does not match.',
      'street_match' => 'Y',
      'postal_match' => 'N'
    })
  end

  def test_customer_can_be_specified
    stub_comms do
      @gateway.purchase(@amount, @credit_card, order_id: '3', customer: 'Joe Jones')
    end.check_request do |endpoint, data, headers|
      assert_match(%r{cust_id>Joe Jones}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_customer_not_specified_card_name_used
    stub_comms do
      @gateway.purchase(@amount, @credit_card, order_id: '3')
    end.check_request do |endpoint, data, headers|
      assert_match(%r{cust_id>Longbob Longsen}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_transcript_scrubbing
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrub), post_scrub
  end

  private

  def successful_purchase_response
    <<-RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <ReceiptId>1026.1</ReceiptId>
          <ReferenceNum>661221050010170010</ReferenceNum>
          <ResponseCode>027</ResponseCode>
          <ISO>01</ISO>
          <AuthCode>013511</AuthCode>
          <TransTime>18:41:13</TransTime>
          <TransDate>2008-01-05</TransDate>
          <TransType>00</TransType>
          <Complete>true</Complete>
          <Message>APPROVED * =</Message>
          <TransAmount>1.00</TransAmount>
          <CardType>V</CardType>
          <TransID>58-0_3</TransID>
          <TimedOut>false</TimedOut>
        </receipt>
      </response>
    RESPONSE
  end

  def successful_purchase_response_with_avs_result
    <<-RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <ReceiptId>9c7189ec64b58f541335be1ca6294d09</ReceiptId>
          <ReferenceNum>660110910011136190</ReferenceNum>
          <ResponseCode>027</ResponseCode>
          <ISO>01</ISO>
          <AuthCode>115497</AuthCode>
          <TransTime>15:20:51</TransTime>
          <TransDate>2014-06-18</TransDate>
          <TransType>00</TransType>
          <Complete>true</Complete><Message>APPROVED * =</Message>
          <TransAmount>10.10</TransAmount>
          <CardType>V</CardType>
          <TransID>491573-0_9</TransID>
          <TimedOut>false</TimedOut>
          <BankTotals>null</BankTotals>
          <Ticket>null</Ticket>
          <CorporateCard>false</CorporateCard>
          <AvsResultCode>A</AvsResultCode>
          <ITDResponse>null</ITDResponse>
          <IsVisaDebit>false</IsVisaDebit>
        </receipt>
      </response>
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <ReceiptId>1026.1</ReceiptId>
          <ReferenceNum>661221050010170010</ReferenceNum>
          <ResponseCode>481</ResponseCode>
          <ISO>01</ISO>
          <AuthCode>013511</AuthCode>
          <TransTime>18:41:13</TransTime>
          <TransDate>2008-01-05</TransDate>
          <TransType>00</TransType>
          <Complete>true</Complete>
          <Message>DECLINED * =</Message>
          <TransAmount>1.00</TransAmount>
          <CardType>V</CardType>
          <TransID>97-2-0</TransID>
          <TimedOut>false</TimedOut>
        </receipt>
      </response>
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <response>
        <receipt>
          <ReceiptId>d315c7a28623dec77dc136450692d2dd</ReceiptId>
          <ReferenceNum>640000030011763320</ReferenceNum>
          <ResponseCode>001</ResponseCode>
          <ISO>00</ISO>
          <AuthCode>372611</AuthCode>
          <TransTime>09:08:58</TransTime>
          <TransDate>2015-04-21</TransDate>
          <TransType>01</TransType>
          <Complete>true</Complete>
          <Message>APPROVED*</Message>
          <TransAmount>1.00</TransAmount>
          <CardType>V</CardType>
          <TransID>830337-0_25</TransID>
          <TimedOut>false</TimedOut>
          <BankTotals>null</BankTotals>
          <Ticket>null</Ticket>
          <CorporateCard>false</CorporateCard>
          <CardLevelResult>A</CardLevelResult>
          <CavvResultCode />
        </receipt>
      </response>
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <response>
        <receipt>
          <ReceiptId>1fa06a83bbd1285ccfa1312835d5aa8d</ReceiptId>
          <ReferenceNum>640020510015803330</ReferenceNum>
          <ResponseCode>481</ResponseCode>
          <ISO>05</ISO>
          <AuthCode>242724</AuthCode>
          <TransTime>09:12:31</TransTime>
          <TransDate>2015-04-21</TransDate>
          <TransType>01</TransType>
          <Complete>true</Complete>
          <Message>DECLINED*</Message>
          <TransAmount>1.05</TransAmount>
          <CardType>V</CardType>
          <TransID>118187-0_25</TransID>
          <TimedOut>false</TimedOut>
          <BankTotals>null</BankTotals>
          <Ticket>null</Ticket>
          <CorporateCard>false</CorporateCard>
          <CardLevelResult>A</CardLevelResult>
          <CavvResultCode />
        </receipt>
      </response>
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <response>
        <receipt>
          <ReceiptId>3a7150ceb7026fccc380743ea3f47fdf</ReceiptId>
          <ReferenceNum>640000030011763340</ReferenceNum>
          <ResponseCode>001</ResponseCode>
          <ISO>00</ISO>
          <AuthCode>224958</AuthCode>
          <TransTime>09:13:45</TransTime>
          <TransDate>2015-04-21</TransDate>
          <TransType>02</TransType>
          <Complete>true</Complete>
          <Message>APPROVED*</Message>
          <TransAmount>0.00</TransAmount>
          <CardType>V</CardType>
          <TransID>830339-1_25</TransID>
          <TimedOut>false</TimedOut>
          <BankTotals>null</BankTotals>
          <Ticket>null</Ticket>
          <CorporateCard>false</CorporateCard>
          <CardLevelResult>A</CardLevelResult>
        </receipt>
      </response>
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <response>
        <receipt>
          <ReceiptId>3a7150ceb7026fccc380743ea3f47fdf</ReceiptId>
          <ReferenceNum>640000030011763350</ReferenceNum>
          <ResponseCode>476</ResponseCode>
          <ISO>12</ISO>
          <AuthCode>224958</AuthCode>
          <TransTime>09:13:46</TransTime>
          <TransDate>2015-04-21</TransDate>
          <TransType>02</TransType>
          <Complete>true</Complete>
          <Message>DECLINED*</Message>
          <TransAmount>0.00</TransAmount>
          <CardType>V</CardType>
          <TransID>830340-2_25</TransID>
          <TimedOut>false</TimedOut>
          <BankTotals>null</BankTotals>
          <Ticket>null</Ticket>
          <CorporateCard>false</CorporateCard>
        </receipt>
      </response>
    RESPONSE
  end

  def successful_store_response
    <<-RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <DataKey>1234567890</DataKey>
          <ResponseCode>027</ResponseCode>
          <Complete>true</Complete>
          <Message>Successfully registered cc details * =</Message>
        </receipt>
      </response>
    RESPONSE
  end

  def successful_unstore_response
    <<-RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <DataKey>1234567890</DataKey>
          <ResponseCode>027</ResponseCode>
          <Complete>true</Complete>
          <Message>Successfully deleted cc details * =</Message>
        </receipt>
      </response>
    RESPONSE
  end

  def successful_update_response
    <<-RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <DataKey>1234567890</DataKey>
          <ResponseCode>027</ResponseCode>
          <Complete>true</Complete>
          <Message>Successfully updated cc details * =</Message>
        </receipt>
      </response>
    RESPONSE
  end

  def successful_echeck_purchase_response
    <<-RESPONSE
     <?xml version="1.0"?>
     <response>
      <receipt>
        <ReceiptId>cb80f38f44af2168fd9033cdf2d0d4c0</ReceiptId>
        <ReferenceNum>001000040010015220</ReferenceNum>
        <ResponseCode>005</ResponseCode>
        <ISO>01</ISO>
        <AuthCode></AuthCode>
        <TransTime>08:23:37</TransTime>
        <TransDate>2018-06-18</TransDate>
        <TransType>00</TransType>
        <Complete>true</Complete>
        <Message>REGISTERED           *                    =</Message>
        <TransAmount>1.0</TransAmount>
        <CardType>CQ</CardType>
        <TransID>1522-0_25</TransID>
        <TimedOut>false</TimedOut>
        <BankTotals>null</BankTotals>
        <Ticket>null</Ticket>
        <CorporateCard>false</CorporateCard>
        <MessageId>null</MessageId>
        <RecurSuccess>true</RecurSuccess>
       </receipt>
     </response>
    RESPONSE
  end

  def xml_purchase_fixture
    '<request><store_id>monusqa002</store_id><api_token>qatoken</api_token><us_purchase><amount>1.01</amount><pan>4242424242424242</pan><expdate>0303</expdate><crypt_type>7</crypt_type><order_id>order1</order_id></us_purchase></request>'
  end

  def xml_capture_fixture
    '<request><store_id>monusqa002</store_id><api_token>qatoken</api_token><us_preauth><amount>1.01</amount><pan>4242424242424242</pan><expdate>0303</expdate><crypt_type>7</crypt_type><order_id>order1</order_id></us_preauth></request>'
  end

  def pre_scrub
    %q{
opening connection to esplusqa.moneris.com:443...
opened
starting SSL for esplusqa.moneris.com:443...
SSL established
<- "POST /gateway_us/servlet/MpgRequest HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: esplusqa.moneris.com\r\nContent-Length: 291\r\n\r\n"
<- "<request><store_id>monusqa002</store_id><api_token>qatoken</api_token><us_purchase><order_id>cec9ca34132f0945446589e36fff9cce</order_id><cust_id>Longbob Longsen</cust_id><amount>1.00</amount><pan>4242424242424242</pan><expdate>1909</expdate><crypt_type>7</crypt_type></us_purchase></request>"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Mon, 08 Jan 2018 19:20:26 GMT\r\n"
-> "Content-Length: 659\r\n"
-> "X-UA-Compatible: IE=Edge\r\n"
-> "Connection: close\r\n"
-> "Content-Type: text/html; charset=UTF-8\r\n"
-> "Set-Cookie: TS01d02998=01649737b16d4ca54c296a0a369f4e549e4191e85d8d022d01468e559975e945b419002a42; Path=/\r\n"
-> "Set-Cookie: TS01d02998_28=01e24a44e55591744bc115f421ddccd549b1655d75bda586c8ea625670efaa4432f67c8b7e06e7af82c70ef3ac4f46d7435664f2ac; Path=/\r\n"
-> "\r\n"
reading 659 bytes...
-> "<?xml version=\"1.0\" standalone=\"yes\"?><response><receipt><ReceiptId>cec9ca34132f0945446589e36fff9cce</ReceiptId><ReferenceNum>640000030013630190</ReferenceNum><ResponseCode>001</ResponseCode><ISO>00</ISO><AuthCode>827125</AuthCode><TransTime>13:20:24</TransTime><TransDate>2018-01-08</TransDate><TransType>00</TransType><Complete>true</Complete><Message>APPROVED*</Message><TransAmount>1.00</TransAmount><CardType>V</CardType><TransID>113295-0_25</TransID><TimedOut>false</TimedOut><BankTotals>null</BankTotals><Ticket>null</Ticket><CorporateCard>false</CorporateCard><CardLevelResult>A</CardLevelResult><CavvResultCode> </CavvResultCode></receipt></response>"
read 659 bytes
Conn close
  }
  end

  def post_scrub
    %q{
opening connection to esplusqa.moneris.com:443...
opened
starting SSL for esplusqa.moneris.com:443...
SSL established
<- "POST /gateway_us/servlet/MpgRequest HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: esplusqa.moneris.com\r\nContent-Length: 291\r\n\r\n"
<- "<request><store_id>monusqa002</store_id><api_token>[FILTERED]</api_token><us_purchase><order_id>cec9ca34132f0945446589e36fff9cce</order_id><cust_id>Longbob Longsen</cust_id><amount>1.00</amount><pan>[FILTERED]</pan><expdate>1909</expdate><crypt_type>7</crypt_type></us_purchase></request>"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Mon, 08 Jan 2018 19:20:26 GMT\r\n"
-> "Content-Length: 659\r\n"
-> "X-UA-Compatible: IE=Edge\r\n"
-> "Connection: close\r\n"
-> "Content-Type: text/html; charset=UTF-8\r\n"
-> "Set-Cookie: TS01d02998=01649737b16d4ca54c296a0a369f4e549e4191e85d8d022d01468e559975e945b419002a42; Path=/\r\n"
-> "Set-Cookie: TS01d02998_28=01e24a44e55591744bc115f421ddccd549b1655d75bda586c8ea625670efaa4432f67c8b7e06e7af82c70ef3ac4f46d7435664f2ac; Path=/\r\n"
-> "\r\n"
reading 659 bytes...
-> "<?xml version=\"1.0\" standalone=\"yes\"?><response><receipt><ReceiptId>cec9ca34132f0945446589e36fff9cce</ReceiptId><ReferenceNum>640000030013630190</ReferenceNum><ResponseCode>001</ResponseCode><ISO>00</ISO><AuthCode>827125</AuthCode><TransTime>13:20:24</TransTime><TransDate>2018-01-08</TransDate><TransType>00</TransType><Complete>true</Complete><Message>APPROVED*</Message><TransAmount>1.00</TransAmount><CardType>V</CardType><TransID>113295-0_25</TransID><TimedOut>false</TimedOut><BankTotals>null</BankTotals><Ticket>null</Ticket><CorporateCard>false</CorporateCard><CardLevelResult>A</CardLevelResult><CavvResultCode> </CavvResultCode></receipt></response>"
read 659 bytes
Conn close
  }
  end
end
