require 'test_helper'

class MonerisTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = MonerisGateway.new(
      :login => 'store1',
      :password => 'yesguy'
    )

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = { :order_id => '1', :customer => '1', :billing_address => address}
  end

  def test_default_options
    assert_equal 7, @gateway.options[:crypt_type]
    assert_equal "store1", @gateway.options[:login]
    assert_equal "yesguy", @gateway.options[:password]
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

  def test_deprecated_credit
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/txn_number>123<\//), anything).returns("")
    @gateway.expects(:parse).returns({})
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE) do
      @gateway.credit(@amount, "123;456", @options)
    end
  end

  def test_refund
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/txn_number>123<\//), anything).returns("")
    @gateway.expects(:parse).returns({})
    @gateway.refund(@amount, "123;456", @options)
  end

  def test_amount_style
   assert_equal '10.34', @gateway.send(:amount, 1034)

   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end

  def test_preauth_is_valid_xml
   params = {
     :order_id => "order1",
     :amount => "1.01",
     :pan => "4242424242424242",
     :expdate => "0303",
     :crypt_type => 7,
   }

   assert data = @gateway.send(:post_data, 'preauth', params)
   assert REXML::Document.new(data)
   assert_equal xml_capture_fixture.size, data.size
  end

  def test_purchase_is_valid_xml
   params = {
     :order_id => "order1",
     :amount => "1.01",
     :pan => "4242424242424242",
     :expdate => "0303",
     :crypt_type => 7,
   }

   assert data = @gateway.send(:post_data, 'purchase', params)
   assert REXML::Document.new(data)
   assert_equal xml_purchase_fixture.size, data.size
  end

  def test_capture_is_valid_xml
   params = {
     :order_id => "order1",
     :amount => "1.01",
     :pan => "4242424242424242",
     :expdate => "0303",
     :crypt_type => 7,
   }

   assert data = @gateway.send(:post_data, 'preauth', params)
   assert REXML::Document.new(data)
   assert_equal xml_capture_fixture.size, data.size
  end

  def test_supported_countries
    assert_equal ['CA'], MonerisGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :diners_club, :discover], MonerisGateway.supported_cardtypes
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
    assert_equal "Successfully registered cc details", response.message
    assert response.params["data_key"].present?
    @data_key = response.params["data_key"]
  end

  def test_successful_unstore
    @gateway.expects(:ssl_post).returns(successful_unstore_response)
    test_successful_store
    assert response = @gateway.unstore(@data_key)
    assert_success response
    assert_equal "Successfully deleted cc details", response.message
    assert response.params["data_key"].present?
  end

  def test_update
    @gateway.expects(:ssl_post).returns(successful_update_response)
    test_successful_store
    assert response = @gateway.update(@data_key, @credit_card)
    assert_success response
    assert_equal "Successfully updated cc details", response.message
    assert response.params["data_key"].present?
  end

  def test_successful_purchase_with_vault
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    test_successful_store
    assert response = @gateway.purchase(100, @data_key, {:order_id => generate_unique_id, :customer => generate_unique_id})
    assert_success response
    assert_equal "Approved", response.message
    assert response.authorization.present?
  end

  def test_successful_authorization_with_vault
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    test_successful_store
    assert response = @gateway.authorize(100, @data_key, {:order_id => generate_unique_id, :customer => generate_unique_id})
    assert_success response
    assert_equal "Approved", response.message
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

    @credit_card.verification_value = "452"
    stub_comms(gateway) do
      gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{cvd_indicator>1<}, data)
      assert_match(%r{cvd_value>452<}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_cvv_enabled_but_not_provided
    gateway = MonerisGateway.new(login: 'store1', password: 'yesguy', cvv_enabled: true)

    @credit_card.verification_value = ""
    stub_comms(gateway) do
      gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{cvd_indicator>0<}, data)
      assert_no_match(%r{cvd_value>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_cvv_disabled_and_provided
    @credit_card.verification_value = "452"
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_no_match(%r{cvd_value>}, data)
      assert_no_match(%r{cvd_indicator>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_cvv_disabled_but_not_provided
    @credit_card.verification_value = ""
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_no_match(%r{cvd_value>}, data)
      assert_no_match(%r{cvd_indicator>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_avs_enabled_and_provided
    gateway = MonerisGateway.new(login: 'store1', password: 'yesguy', avs_enabled: true)

    billing_address = address(address1: "1234 Anystreet", address2: "")
    stub_comms do
      gateway.purchase(@amount, @credit_card, billing_address: billing_address, order_id: "1")
    end.check_request do |endpoint, data, headers|
      assert_match(%r{avs_street_number>1234<}, data)
      assert_match(%r{avs_street_name>Anystreet<}, data)
      assert_match(%r{avs_zipcode>#{billing_address[:zip]}<}, data)
    end.respond_with(successful_purchase_response_with_avs_result)
  end

  def test_avs_enabled_but_not_provided
    gateway = MonerisGateway.new(login: 'store1', password: 'yesguy', avs_enabled: true)

    stub_comms do
      gateway.purchase(@amount, @credit_card, @options.tap { |x| x.delete(:billing_address) })
    end.check_request do |endpoint, data, headers|
      assert_no_match(%r{avs_street_number>}, data)
      assert_no_match(%r{avs_street_name>}, data)
      assert_no_match(%r{avs_zipcode>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_avs_disabled_and_provided
    billing_address = address(address1: "1234 Anystreet", address2: "")
    stub_comms do
      @gateway.purchase(@amount, @credit_card, billing_address: billing_address, order_id: "1")
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
      'message' => 'Street address matches, but 5-digit and 9-digit postal code do not match.',
      'street_match' => 'Y',
      'postal_match' => 'N'
    })
  end

  def test_customer_can_be_specified
    stub_comms do
      @gateway.purchase(@amount, @credit_card, order_id: "3", customer: "Joe Jones")
    end.check_request do |endpoint, data, headers|
      assert_match(%r{cust_id>Joe Jones}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_customer_not_specified_card_name_used
    stub_comms do
      @gateway.purchase(@amount, @credit_card, order_id: "3")
    end.check_request do |endpoint, data, headers|
      assert_match(%r{cust_id>Longbob Longsen}, data)
    end.respond_with(successful_purchase_response)
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

  def xml_purchase_fixture
   '<request><store_id>store1</store_id><api_token>yesguy</api_token><purchase><amount>1.01</amount><pan>4242424242424242</pan><expdate>0303</expdate><crypt_type>7</crypt_type><order_id>order1</order_id></purchase></request>'
  end

  def xml_capture_fixture
   '<request><store_id>store1</store_id><api_token>yesguy</api_token><preauth><amount>1.01</amount><pan>4242424242424242</pan><expdate>0303</expdate><crypt_type>7</crypt_type><order_id>order1</order_id></preauth></request>'
  end
end
