require 'test_helper'

class MolpayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Molpay::Helper.new('order-5.00','molpaytech', :amount => 5.00, :currency => 'MYR', :credential2 => 'testcredential')
  end
 
 def test_basic_helper_fields
    assert_field "merchantid", "molpaytech"
    assert_field "amount",       "5.00"
    assert_field "orderid",        "order-5.00"
    assert_field "cur",     "MYR"
  end

  def test_credential_based_url
    assert_equal 'https://www.onlinepayment.com.my/MOLPay/pay/molpaytech/', @helper.credential_based_url
  end

  def test_credential_based_url_optional
    molpay = Molpay::Helper.new('order-5.00','molpaytech', :amount => 5.00, :currency => 'MYR', :credential2 => 'testcredential', :channel => 'maybank2u.php')
    assert_equal 'https://www.onlinepayment.com.my/MOLPay/pay/molpaytech/maybank2u.php', molpay.credential_based_url 
  end

  def test_customer_fields
    @helper.customer :name => "John Doe", :email => "john@example.com", :phone => "60355218438"
    assert_field "bill_name",    "John Doe"
    assert_field "bill_email",   "john@example.com"
    assert_field "bill_mobile", "60355218438"
  end

  def test_product_fields
    @helper.description "My Store Purchase"
    assert_field "bill_desc", "My Store Purchase"
  end

  def test_supported_currency
    [ 'MYR', 'USD', 'SGD', 'PHP', 'VND', 'IDR', 'AUD'].each do |cur|
      @helper.currency cur
      assert_field "cur", cur 
    end
  end

  def test_unsupported_currency
    assert_raise ArgumentError do
      @helper.currency "BITCOIN"
    end
  end

  def test_supported_lang
    ['en', 'cn'].each do |lang|
      @helper.language lang
      assert_field "langcode", lang
    end
  end

  def test_unsupported_lang
    assert_raise ArgumentError do
      @helper.language "AVATAR"
    end
  end

  def test_return_url
    @helper.return_url "http://www.example.com"
    assert_field "returnurl", "http://www.example.com"
  end

  def test_signature
    assert_equal '16d122e1cf4d4fac19f3c839db12b6a5', @helper.form_fields["vcode"]
  end

  def test_valid_amount
    @helper.amount = 5.00
    assert_field "amount", "5.00"
  end

  def test_invalid_amount_as_string
    assert_raise ArgumentError do
      @helper.amount = "5.00"
    end
  end

  def test_invalid_amount_below_min_amount
    assert_raise ArgumentError do
      @helper.amount = 1.00
    end
  end

end
