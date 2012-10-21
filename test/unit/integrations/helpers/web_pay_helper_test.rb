require 'test_helper'

class WebPayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = WebPay::Helper.new('ORDER-12345678', '11111111', :amount => '21950', :currency => 'BYR', :secret => '12345678901234567890')
  end

  def assign_invoice
    @helper.add_line_item(:name => 'hammer', :quantity => '1', :price => '500')
  end

  def assign_signature_fields
    @helper.seed    = '1242649174'
    @helper.test    = '1'
    @helper.version = '2'
  end

  def test_basic_helper_fields
    assert_field 'wsb_storeid',     '11111111'
    assert_field 'wsb_order_num',   'ORDER-12345678'
    assert_field 'wsb_currency_id', 'BYR'
  end

  def test_signature_string
    assign_signature_fields

    assert_equal '124264917411111111ORDER-123456781BYR2195012345678901234567890', @helper.request_signature_string
  end

  def test_generated_signature
    assign_signature_fields

    assert_equal '7a0142975bc660d219b793c650346af7ffce2473', @helper.generate_signature(:request)
  end

  def test_invoice_form_fields
    assign_invoice

    assert_field 'wsb_invoice_item_name[0]', 'hammer'
    assert_field 'wsb_invoice_item_quantity[0]', '1'
    assert_field 'wsb_invoice_item_price[0]', '500'
  end

  def test_total_invoice_price
    assign_invoice

    @helper.tax            = '5'
    @helper.shipping_price = '10'
    @helper.discount_price = '10'

    assert_field 'wsb_tax', '5'
    assert_field 'wsb_shipping_price', '10'
    assert_field 'wsb_discount_price', '10'

    assert_equal 505, @helper.calculate_total
  end
end
