require "test_helper"

class Ipay88HelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Ipay88::Helper.new("order-500", "ipay88merchcode", :credential2 => "abc", :amount => 500, :currency => "MYR")
  end

  def test_basic_helper_fields
    assert_field "MerchantCode", "ipay88merchcode"
    assert_field "Amount",       "5.00"
    assert_field "RefNo",        "order-500"
    assert_field "Currency",     "MYR"
  end

  def test_customer_fields
    @helper.customer :first_name => "John", :last_name => "Doe", :email => "john@example.com", :phone => "+60128888888"
    assert_field "UserName",    "John Doe"
    assert_field "UserEmail",   "john@example.com"
    assert_field "UserContact", "+60128888888"
  end

  def test_product_fields
    @helper.description "TiC Store Purchase"
    assert_field "ProdDesc", "TiC Store Purchase"
  end

  def test_supported_currency
    %w[MYR USD CNY].each do |cur|
      @helper.currency cur
      assert_field "Currency", cur 
    end
  end

  def test_unsupported_currency
    assert_raise ArgumentError do
      @helper.currency "FOO"
    end
  end

  def test_remark
    @helper.remark "Remarkable remark"
    assert_field "Remark", "Remarkable remark"
  end

  def test_supported_lang
    %w[ISO-8859-1 UTF-8 GB2312 GD18030 BIG5].each do |lang|
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
    assert_field "ResponseURL", "http://www.example.com"
  end

  def test_supported_payment
    @helper.payment 6 # 6 => m2u
    assert_field "PaymentId", "6"
  end

  def test_unsupported_payment
    assert_raise ArgumentError do
      @helper.payment 999
    end
  end

  def test_signature
    assert_field "Signature", "vDwWN/XHvYnlReq3f1llHFCxDTY="
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
    assert_raise ActionViewHelperError do
      @helper.amount = -100
    end
  end

  def test_sig_components_amount_doesnt_include_decimal_points
    @helper.amount = 50
    assert_equal "abcipay88merchcodeorder-500050MYR", @helper.send(:sig_components)
    @helper.amount = 1234
    assert_equal "abcipay88merchcodeorder-5001234MYR", @helper.send(:sig_components)
    @helper.amount = 1000
    assert_equal "abcipay88merchcodeorder-5001000MYR", @helper.send(:sig_components)
    @helper.amount = Money.new(90)
    assert_equal "abcipay88merchcodeorder-500090MYR", @helper.send(:sig_components)
    @helper.amount = Money.new(1000)
    assert_equal "abcipay88merchcodeorder-5001000MYR", @helper.send(:sig_components)
  end

  def test_sign_method
    assert_equal "rq3VxZp9cjkiqiw4mHnZJH49MzQ=", Ipay88::Helper.sign("L3mn6Bpy4HM0605613619416109MYR")
  end
end
