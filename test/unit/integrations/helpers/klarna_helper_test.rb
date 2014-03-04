require 'test_helper'

class KlarnaHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @order_id = 1
    @credential1 = "Example Merchant ID"
    @options = {
      :amount           =>  Money.new(10.00),
      :currency         => 'EUR',
      :country          => 'SE',
      :account_name     => 'Example Shop Name',
      :credential2      => 'Example shared secret',
      :test             => false,
      :cart_items       => [example_cart_item]
    }

    # For remote tests later
    # ActiveMerchant::Billing::Integrations::Klarna::Helper.application_id = 'a57b5192-7080-443c-9867-c5346b649dc0'

    @helper = Klarna::Helper.new(@order_id, @credential1, @options)
  end

  def test_basic_helper_fields
    assert_field 'purchase_country', @options[:country]
    assert_field 'purchase_currency', @options[:currency]

    assert_field 'locale', "Sv Se"
    
    assert_field 'merchant_id', @credential1
    assert_field 'platform_type', @helper.application_id

    assert_field 'merchant_digest', '74af1e1a5ec330c8536cb05eea5d0d81ab5983d444a0be5693ac5b8b096d2f5f'
  end

  def test_merchant_uri_fields
    example_cancel_url = "http://example-cancel-url"
    @helper.cancel_return_url("http://example-cancel-url")

    assert_field 'merchant_terms_uri', example_cancel_url
    assert_field 'merchant_checkout_uri', example_cancel_url
    assert_field 'merchant_base_uri', example_cancel_url
    assert_field 'merchant_confirmation_uri', example_cancel_url
  end

  def test_cart_items
    item = @helper.cart_items[0]

    assert_field 'cart_item-1_type', item.type.to_s
    assert_field 'cart_item-1_reference', item.reference.to_s
    assert_field 'cart_item-1_name', item.name.to_s
    assert_field 'cart_item-1_quantity', item.quantity.to_s
    assert_field 'cart_item-1_unit_price', item.unit_price.to_s
    assert_field 'cart_item-1_tax_rate', item.tax_rate.to_s
  end

  private

  Item = Struct.new(:type, :reference, :name, :quantity, :unit_price, :tax_rate)
  def example_cart_item(order_number = 1)
    item = Item.new('physical', "##{order_number}", 'example item description', 1, Money.new(1.00), 0)
  end
end
