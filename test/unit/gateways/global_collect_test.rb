require 'test_helper'

class GlobalCollectTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = GlobalCollectGateway.new(:merchant_id => '1')
    @credit_card = credit_card
    @amount = 100
    @authorization = "#{order_id}|1|1"

    @options = {
      :currency => 'CAD',
      :order_id => order_id,
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match %r(<ACTION>INSERT_ORDERWITHPAYMENT</ACTION>), data
      assert_match %r(<ORDERID>#{order_id}</ORDERID>), data
      assert_match %r(<ORDERTYPE>1</ORDERTYPE>), data
      assert_match %r(<AMOUNT>100</AMOUNT>), data
      assert_match %r(<CURRENCYCODE>CAD</CURRENCYCODE>), data
      assert_match %r(<EXPIRYDATE>#{"%.2i%.2i" % [@credit_card.month, @credit_card.year % 100]}</EXPIRYDATE>), data
      assert_match %r(<PAYMENTPRODUCTID>1</PAYMENTPRODUCTID>), data
      assert_match %r(<CREDITCARDNUMBER>4242424242424242</CREDITCARDNUMBER>), data
      assert_match %r(<CVV>123</CVV>), data
    end.respond_with(successful_authorize_response)
    assert_instance_of Response, response
    assert_success response
    assert_equal @authorization, response.authorization
    assert_equal "Success", response.message

    assert response.test?
  end

  def test_unsuccessful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.respond_with(failed_authorize_response)

    assert_instance_of Response, response
    assert_failure response
    assert response.test?
    assert_equal 'REQUEST 1212121 VALUE 4567350000427976 OF FIELD CREDITCARDNUMBER DID NOT PASS THE LUHNCHECK', response.message
  end

  def test_authorize_require_order_id
    assert_raise(ArgumentError) do
      @gateway.authorize(@amount, @credit_card)
    end
  end

  def test_purchase_require_order_id
    assert_raise(ArgumentError) do
      @gateway.purchase(@amount, @credit_card)
    end
  end

  def test_successful_capture
    response = stub_comms do
      @gateway.capture(@amount, @authorization, @options)
    end.check_request do |endpoint, data, headers|
      assert_match %r(<ACTION>SET_PAYMENT</ACTION>), data
      assert_match %r(<ORDERID>#{order_id}</ORDERID>), data
      assert_match %r(<PAYMENTPRODUCTID>1</PAYMENTPRODUCTID>), data
      assert_match %r(<AMOUNT>100</AMOUNT>), data
      assert_match %r(<CURRENCYCODE>CAD</CURRENCYCODE>), data
    end.respond_with(successful_empty_response)
    assert_instance_of Response, response
    assert_success response
    assert_equal "Success", response.message

    assert response.test?
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_authorize_response, successful_empty_response)
    assert_instance_of MultiResponse, response
    assert_success response
    assert_equal @authorization, response.authorization
    assert_equal 2, response.responses.size
    assert_equal 'Success', response.message

    assert response.test?
  end

  def test_successful_void
    response = stub_comms do
      @gateway.void(@authorization, @options)
    end.check_request do |endpoint, data, headers|
      assert_match %r(<ACTION>CANCEL_PAYMENT</ACTION>), data
      assert_match %r(<ORDERID>#{order_id}</ORDERID>), data
      assert_match %r(<EFFORTID>1</EFFORTID>), data
      assert_match %r(<ATTEMPTID>1</ATTEMPTID>), data
    end.respond_with(successful_empty_response)
    assert_instance_of Response, response
    assert_success response
    assert_equal "Success", response.message

    assert response.test?
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(@amount, @authorization, @options)
    end.check_request do |endpoint, data, headers|
      assert_match %r(<ACTION>DO_REFUND</ACTION>), data
      assert_match %r(<ORDERID>#{order_id}</ORDERID>), data
      assert_match %r(<AMOUNT>100</AMOUNT>), data
      assert_match %r(<CURRENCYCODE>CAD</CURRENCYCODE>), data
    end.respond_with(successful_empty_response)
    assert_instance_of Response, response
    assert_success response
    assert_equal "Success", response.message

    assert response.test?
  end

  def test_deprecated_credit
    @gateway.expects(:refund).with(@amount, "transaction_id", @options)
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE, @gateway) do
      @gateway.credit(@amount, "transaction_id", @options)
    end
  end

  def multiple_initial_purchase
    # should just call authorize
    @gateway.expects(:authorize).with(@amount, @credit_card, @options.merge(:order_type => 4))
    @gateway.multiple_initial_purchase(@amount, @credit_card, @options)
  end

  def multiple_append_purchase
    # should just call authorize
    @options[:effort_id] = '2'
    response = stub_comms do
      @gateway.multiple_append_purchase(@amount, @options)
    end.check_request do |endpoint, data, headers|
      assert_match %r(<ACTION>DO_PAYMENT</ACTION>), data
      assert_match %r(<ORDERID>#{order_id}</ORDERID>), data
      assert_match %r(<EFFORTID>2</EFFORTID>), data
      assert_match %r(<AMOUNT>100</AMOUNT>), data
      assert_match %r(<CURRENCYCODE>CAD</CURRENCYCODE>), data
    end

    assert_instance_of Response, response
    assert_success response
    assert_equal "Success", response.message
    assert response.test?
  end

  private

  def successful_empty_response
    build_response <<-RESPONSE
    <RESULT>OK</RESULT>
    <META>
      <RESPONSEDATETIME>20040718145902</RESPONSEDATETIME>
      <REQUESTID>123</REQUESTID>
    </META>
    RESPONSE
  end

  # Place raw successful response from gateway here
  def successful_authorize_response
    build_response <<-RESPONSE
      <RESULT>OK</RESULT>
      <META>
      </META>
      <ROW>
        <MERCHANTID>1</MERCHANTID>
        <ORDERID>#{order_id}</ORDERID>
        <EFFORTID>1</EFFORTID>
        <ATTEMPTID>1</ATTEMPTID>
        <STATUSID>800</STATUSID>
        <STATUSDATE>20030829171416</STATUSDATE>
        <PAYMENTREFERENCE>185800005380</PAYMENTREFERENCE>
        <ADDITIONALREFERENCE>19998990013</ADDITIONALREFERENCE>
      </ROW>
    RESPONSE
  end

  # Place raw failed response from gateway here
  def failed_authorize_response
    build_response <<-RESPONSE
      <RESULT>NOK</RESULT>
      <META>
        <RESPONSEDATETIME>20040718145902</RESPONSEDATETIME>
        <REQUESTID>245</REQUESTID>
      </META>
      <ERROR>
        <CODE>21000020</CODE>
        <MESSAGE>
          REQUEST 1212121 VALUE 4567350000427976 OF FIELD CREDITCARDNUMBER DID NOT PASS THE LUHNCHECK
        </MESSAGE>
      </ERROR>
    RESPONSE
  end

  def build_response response
    <<-RESPONSE
    <XML>
    <REQUEST>
      <ACTION>ACTION</ACTION>
      <META>
        <MERCHANTID>1</MERCHANTID>
        <IPADDRESS>123.123.123.123</IPADDRESS>
        <VERSION>1.0</VERSION>
        <REQUESTIPADDRESS>123.123.123.123</REQUESTIPADDRESS>
      </META>
      <PARAMS></PARAMS>
      <RESPONSE>
      #{response}
      </RESPONSE>
    </REQUEST>
    </XML>
    RESPONSE
  end

  def order_id
    '123456'
  end
end
