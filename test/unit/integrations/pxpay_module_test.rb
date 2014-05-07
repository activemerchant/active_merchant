require 'test_helper'
require 'nokogiri'

class PxpayModuleTest < Test::Unit::TestCase
  include CommStub
  include ActionViewHelperTestHelper
  include ActiveMerchant::Billing::Integrations

  def setup
    super
    @options = fixtures(:pxpay)
    @username = @options[:login]
    @key = @options[:password]

    @service_options = {
      :service => :pxpay,
      :amount => 157.0,
      :return_url => "http://example.com/pxpay/return_url",
      :credential2 => @options[:password]
    }
  end

  def test_notification_method
    Pxpay::Notification.any_instance.stubs(:decrypt_transaction_result)

    assert_instance_of Pxpay::Notification, Pxpay.notification('name=cody&result=token', :credential1 => '', :credential2 => '')
  end

  def test_should_round_numbers
    Pxpay::Helper.any_instance.expects(:ssl_post).with { |_, request| request.include?('<AmountInput>157.00</AmountInput>') }.returns(valid_response)
    payment_service_for('44', @username, @service_options.merge(:amount => "157.003")) {}

    Pxpay::Helper.any_instance.expects(:ssl_post).with { |_, request| request.include?('<AmountInput>157.01</AmountInput>') }.returns(valid_response)
    payment_service_for('44', @username, @service_options.merge(:amount => "157.005")) {}
  end

  def test_amount_has_cent_precision
    Pxpay::Helper.any_instance.expects(:ssl_post).with { |_, request| request.include?('<AmountInput>157.00</AmountInput>') }.returns(valid_response)
    payment_service_for('44', @username, @service_options) {}
  end

  def test_all_fields
    Pxpay::Helper.any_instance.expects(:ssl_post).with do |_, request|
      assert_match "<MerchantReference>44</MerchantReference>", request
      assert_match "<PxPayUserId>#{@username}</PxPayUserId>", request
      assert_match "<PxPayKey>#{@key}</PxPayKey>", request
      assert_match "<TxnType>Purchase</TxnType>", request
      assert_match "<AmountInput>157.00</AmountInput>", request
      assert_match "<EnableAddBillCard>0</EnableAddBillCard>", request
      assert_match "<UrlSuccess>http://example.com/pxpay/return_url</UrlSuccess>", request
      assert_match "<UrlFail>http://example.com/pxpay/return_url</UrlFail>", request
    end.returns(valid_response)

    payment_service_for('44', @username, @service_options) {}
  end

  def test_created_form_is_invalid_when_credentials_are_wrong
    Pxpay::Helper.any_instance.stubs(:ssl_post).returns(invalid_response)

    assert_raise(ActionViewHelperError) do
      payment_service_for('44', @username, @service_options) {}
    end
  end

  def test_credential_based_url
    Pxpay::Helper.any_instance.expects(:ssl_post).returns(valid_response)

    helper = Pxpay::Helper.new('44', @username, @service_options.slice(:amount, :return_url, :credential2))
    assert_equal "https://sec.paymentexpress.com/pxpay/pxpay.aspx", helper.credential_based_url
    expected_params = {'userid' => ['PXPAY_USER'], 'request' => ['REQUEST_TOKEN']}
    assert_equal expected_params, helper.redirect_parameters
  end

  def test_credential_based_url_without_query
    Pxpay::Helper.any_instance.expects(:ssl_post).returns(valid_response_without_query)

    helper = Pxpay::Helper.new('44', @username, @service_options.slice(:amount, :return_url, :credential2))
    assert_equal "https://sec.paymentexpress.com/pxmi3/RANDOM_TOKEN", helper.credential_based_url
    assert helper.redirect_parameters.empty?
  end

  private

  def valid_response
    '<Request valid="1"><URI>https://sec.paymentexpress.com/pxpay/pxpay.aspx?userid=PXPAY_USER&amp;request=REQUEST_TOKEN</URI></Request>'
  end

  def valid_response_without_query
    '<Request valid="1"><URI>https://sec.paymentexpress.com/pxmi3/RANDOM_TOKEN</URI></Request>'
  end

  def invalid_response
    '<Request valid="1"><Reco>IP</Reco><ResponseText>Invalid Access Info</ResponseText></Request>'
  end
end
