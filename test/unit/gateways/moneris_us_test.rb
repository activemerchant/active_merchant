require 'test_helper'

class MonerisUsTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = MonerisUsGateway.new(
      :login => 'monusqa002',
      :password => 'qatoken'
    )

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = { :order_id => '1', :billing_address => address }
  end

  def test_default_options
    assert_equal 7, @gateway.options[:crypt_type]
    assert_equal "monusqa002", @gateway.options[:login]
    assert_equal "qatoken", @gateway.options[:password]
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

   assert data = @gateway.send(:post_data, 'us_preauth', params)
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

   assert data = @gateway.send(:post_data, 'us_purchase', params)
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

  def xml_purchase_fixture
   '<request><store_id>monusqa002</store_id><api_token>qatoken</api_token><us_purchase><amount>1.01</amount><pan>4242424242424242</pan><expdate>0303</expdate><crypt_type>7</crypt_type><order_id>order1</order_id></us_purchase></request>'
  end

  def xml_capture_fixture
   '<request><store_id>monusqa002</store_id><api_token>qatoken</api_token><us_preauth><amount>1.01</amount><pan>4242424242424242</pan><expdate>0303</expdate><crypt_type>7</crypt_type><order_id>order1</order_id></us_preauth></request>'
  end

end
