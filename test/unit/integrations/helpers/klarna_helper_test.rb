require 'test_helper'

class KlarnaHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @order_id = 1
    @credential1 = "Example Merchant ID"
    @options = {
      :amount           =>  Money.new(10.00),
      :currency         => 'SEK',
      :country          => 'SE',
      :account_name     => 'Example Shop Name',
      :credential2      => 'Example shared secret',
      :test             => false
    }

    # For remote tests later
    # ActiveMerchant::Billing::Integrations::Klarna::Helper.application_id = 'a57b5192-7080-443c-9867-c5346b649dc0'

    @helper = Klarna::Helper.new(@order_id, @credential1, @options)
  end

  def test_basic_helper_fields
    assert_field 'purchase_country', @options[:country]
    assert_field 'purchase_currency', @options[:currency]

    assert_field 'locale', "sv-se"
    
    assert_field 'merchant_id', @credential1
    assert_field 'platform_type', @helper.application_id
  end

  def test_merchant_digest
    item = example_line_item
    @helper.line_item(item)

    @helper.cancel_return_url("http://example-cancel-url")

    # Call hook to populate merchant_digest field
    @helper.form_fields

    assert_field 'merchant_digest', "YEmynIXEziC4IKkCnsRXOhyA5HSihUVFZsxwqFBCjdk="
  end

  def test_line_item
    item = example_line_item
    @helper.line_item(item)

    assert_field 'cart_item-0_type', item[:type].to_s
    assert_field 'cart_item-0_reference', item[:reference].to_s
    assert_field 'cart_item-0_name', item[:name].to_s
    assert_field 'cart_item-0_quantity', item[:quantity].to_s
    assert_field 'cart_item-0_unit_price', item[:unit_price].to_s
    assert_field 'cart_item-0_tax_rate', item[:tax_rate].to_s
  end

  def test_merchant_uri_fields
    example_cancel_url = "http://example-cancel-url"
    @helper.cancel_return_url("http://example-cancel-url")

    assert_field 'merchant_terms_uri', example_cancel_url
    assert_field 'merchant_checkout_uri', example_cancel_url
    assert_field 'merchant_base_uri', example_cancel_url
    assert_field 'merchant_confirmation_uri', example_cancel_url
  end

  private

  CartItem = Struct.new(:type, :reference, :name, :quantity, :unit_price, :tax_rate)
  def example_cart_item(order_number = 1)
    item = CartItem.new('physical', "##{order_number}", 'example item description', 1, Money.new(1.00), 0)
  end

  def example_line_item(order_number = 1)
    cart_item = example_cart_item(order_number)
    item = {
      :type => cart_item.type,
      :reference => cart_item.reference,
      :name => cart_item.name,
      :quantity => cart_item.quantity,
      :unit_price => cart_item.unit_price,
      :discount_rate => (cart_item.respond_to?(:discount_rate) ? cart_item.discount_rate : nil),
      :tax_rate => cart_item.tax_rate
    }
  end
end
