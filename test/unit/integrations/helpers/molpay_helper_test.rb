require 'test_helper'

class MolpayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Molpay::Helper.new('order-500','cody@example.com', :amount => 500, :currency => 'USD', :credential2 => '1a2d20c7150f42e37cfe1b87879fe5cb')
  end
 
  def test_basic_helper_fields
    assert_field "MerchantCode", "test5620"
    assert_field "Amount",       "5.00"
    assert_field "RefNo",        "2"
    assert_field "Currency",     "MYR"
  end
  
  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com', :phone => "+60128888888"
    assert_field 'name', 'Cody'
    assert_field 'email', 'cody@example.com'
    assert_field 'phone', '+60128888888'
  end

  def test_supported_currency
    %w[MYR USD CNY TWD].each do |cur|
      @helper.currency cur
      assert_field "Currency", cur 
    end
  end

  def test_unsupported_currency
    assert_raise ArgumentError do
      @helper.currency "FOO"
    end
  end

  def test_supported_lang
    %w[en cn].each do |lang|
      @helper.language lang
      assert_field "Lang", lang
    end
  end

  def test_unsupported_lang
    assert_raise ArgumentError do
      @helper.language "KLINGON"
    end
  end

  def test_return_url
    @helper.return_url "http://www.example.com"
    assert_field "return_url", "http://www.example.com"
  end

  def test_valid_amount
    @helper.amount = 100
    assert_field "Amount", "1.00"
  end

  def test_invalid_amount_as_string
    assert_raise ArgumentError do
      @helper.amount = "1.00"
    end
  end

  def test_invalid_amount_as_negative_integer_in_cents
    assert_raise ArgumentError do
      @helper.amount = -100
    end
  end
  
end
