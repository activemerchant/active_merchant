require 'test_helper'

class UniversalHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @order = 'order-500'
    @account = 'zork'
    @key = 'TO78ghHCfBQ6ZBw2Q2fJ3wRwGkWkUHVs'
    @amount = 123.45
    @currency = 'USD'
    @test = false
    @country = 'US'
    @account_name = 'Widgets Inc'
    @transaction_type = 'sale'
    @forward_url = 'https://bork.com/pay'
    @options = {:amount => @amount,
                :currency => @currency,
                :test => @test,
                :credential2 => @key,
                :country => @country,
                :account_name => @account_name,
                :transaction_type => @transaction_type,
                :forward_url => @forward_url}
    @helper = Universal::Helper.new(@order, @account, @options)
  end

  def test_credential_based_url
    assert_equal @forward_url, @helper.credential_based_url
  end

  def test_core_fields
    @helper.shipping 6.78
    @helper.tax 0
    @helper.description 'Box of Red Wine'
    @helper.invoice 'Invoice #1A'

    assert_field 'x_account_id', @account
    assert_field 'x_currency', @currency
    assert_field 'x_amount', '123.45'
    assert_field 'x_amount_shipping', '6.78'
    assert_field 'x_amount_tax', '0.00'
    assert_field 'x_reference', @order
    assert_field 'x_shop_country', @country
    assert_field 'x_shop_name', @account_name
    assert_field 'x_transaction_type', @transaction_type
    assert_field 'x_description', 'Box of Red Wine'
    assert_field 'x_invoice', 'Invoice #1A'
    assert_field 'x_test', @test.to_s
  end

  def test_special_currency_formatting
    @options[:currency] = 'COU'
    @helper = Universal::Helper.new(@order, @account, @options)
    @helper.shipping 6.78
    @helper.tax 0

    assert_field 'x_currency', 'COU'
    assert_field 'x_amount', '123.4500'
    assert_field 'x_amount_shipping', '6.7800'
    assert_field 'x_amount_tax', '0.0000'
  end

  def test_customer_fields
    @helper.customer :first_name => 'Cody',
                     :last_name  => 'Fauser',
                     :email      => 'cody@example.com',
                     :phone      => '(613) 456-7890'

    assert_field 'x_customer_first_name', 'Cody'
    assert_field 'x_customer_last_name',  'Fauser'
    assert_field 'x_customer_email',      'cody@example.com'
    assert_field 'x_customer_phone',      '(613) 456-7890'
  end

  def test_shipping_address_fields
    @helper.shipping_address :first_name => 'John',
                             :last_name  => 'Doe',
                             :city       => 'Toronto',
                             :company    => 'Shopify Toronto',
                             :address1   => '241 Spadina Ave',
                             :address2   => 'Front Entrance',
                             :state      => 'ON',
                             :zip        => 'M5T 3A8',
                             :country    => 'CA',
                             :phone      => '(416) 123-4567'

    assert_field 'x_customer_shipping_first_name', 'John'
    assert_field 'x_customer_shipping_last_name',  'Doe'
    assert_field 'x_customer_shipping_city',       'Toronto'
    assert_field 'x_customer_shipping_company',    'Shopify Toronto'
    assert_field 'x_customer_shipping_address1',   '241 Spadina Ave'
    assert_field 'x_customer_shipping_address2',   'Front Entrance'
    assert_field 'x_customer_shipping_state',      'ON'
    assert_field 'x_customer_shipping_zip',        'M5T 3A8'
    assert_field 'x_customer_shipping_country',    'CA'
    assert_field 'x_customer_shipping_phone',      '(416) 123-4567'
  end

  def test_url_fields
    @helper.notify_url 'https://zork.com/notify'
    @helper.return_url 'https://zork.com/return'
    @helper.cancel_return_url 'https://zork.com/cancel'

    assert_field 'x_url_callback', 'https://zork.com/notify'
    assert_field 'x_url_complete', 'https://zork.com/return'
    assert_field 'x_url_cancel', 'https://zork.com/cancel'
  end

  def test_signature
    expected_signature = Digest::HMAC.hexdigest('x_account_idzorkx_amount123.45x_currencyUSDx_referenceorder-500x_shop_countryUSx_shop_nameWidgets Incx_testfalsex_transaction_typesale', @key, Digest::SHA256)
    @helper.sign_fields

    assert_field 'x_signature', expected_signature
  end
end
