require 'test_helper'

class NetgiroHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Netgiro::Helper.new(
      'order-500',
      'cody@example.com', 
      :credential2 => 'abc123'
    )
  end
 
  def test_basic_helper_fields
    assert_field 'ApplicationID', 'cody@example.com'
    assert_field 'OrderId', 'order-500'

    #SecretKey OrderId TotalAmount ApplicationId
    assert_equal Digest::SHA256.hexdigest(['abc123', 'order-500', '0', 'cody@example.com'].join('')),
                 @helper.form_fields['Signature']

    assert_field 'TotalAmount', 0
  end
  
  def test_line_items
    @helper.add_line_item(:name => "Product one", :quantity => 1, :amount => 999, :unit_price => 999)
    
    assert_field 'Items[0].Name', 'Product one'
    assert_field 'Items[0].Quantity', '1000'
    assert_field 'Items[0].Amount', '999'
    assert_field 'Items[0].UnitPrice', '999'

    @helper.add_line_item(:name => "Product two", :quantity => 3, :amount => 1500, :unit_price => 500, :description => "Some description", :product_no => "SKU-123")

    assert_field 'Items[1].Name', 'Product two'
    assert_field 'Items[1].Quantity', '3000'
    assert_field 'Items[1].Amount', '1500'
    assert_field 'Items[1].UnitPrice', '500'
    assert_field 'Items[1].Description', 'Some description'
    assert_field 'Items[1].ProductNo', 'SKU-123'

    assert_equal Digest::SHA256.hexdigest(
      ['abc123', 'order-500', '2499', 'cody@example.com'].join('')),
      @helper.form_fields['Signature']
  end

  def test_shipping
    @helper.add_shipping(500)
    assert_field 'ShippingAmount', '500'
    assert_equal @helper.amount, 500
  end

  def test_handling
    @helper.add_handling(1000)
    assert_field 'HandlingAmount', '1000'
    assert_equal @helper.amount, 1000
  end

  def test_discount
    @helper.add_discount(1500)
    assert_field 'DiscountAmount', '1500'
    assert_equal @helper.amount, -1500
  end

  def test_line_items_with_shipping_handling_discount
    @helper.add_line_item(:name => "Product one", :quantity => 1, :amount => 999, :unit_price => 999)
    
    assert_field 'Items[0].Name', 'Product one'
    assert_field 'Items[0].Quantity', '1000'
    assert_field 'Items[0].Amount', '999'
    assert_field 'Items[0].UnitPrice', '999'

    @helper.add_shipping(500)
    @helper.add_handling(1000)
    @helper.add_discount(500)

    assert_equal @helper.amount, 1999

    assert_equal Digest::SHA256.hexdigest(
      ['abc123', 'order-500', '1999', 'cody@example.com'].join('')),
      @helper.form_fields['Signature']

  end

  def test_payment_option
    @helper.payment_option(1)
    assert_field 'PaymentOption', '1'
  end

  def test_return_customer_info
    @helper.return_customer_info(true)
    assert_field('ReturnCustomerInfo', 'true')
  end

  def test_line_item_options
    assert_nothing_raised do
      @helper.add_line_item(:name => "Product one", :amount => 500, :quantity => 1, :unit_price => 500)
    end

    assert_nothing_raised do
      @helper.add_line_item(:name => "Product one", :amount => 500, :quantity => 1, :unit_price => 500, :description => "Product description")
    end

    assert_nothing_raised do
      @helper.add_line_item(:name => "Product one", :amount => 500, :quantity => 1, :unit_price => 500, :description => "Product description", :product_no => "P-101")
    end

    assert_raise ArgumentError do
      @helper.add_line_item(:name => "Product one", :amount => 500, :quantity => 1)
    end

    assert_raise ArgumentError do
      @helper.add_line_item(:name => "Product one", :amount => 500, :unit_price => 500)
    end

    assert_raise ArgumentError do
      @helper.add_line_item(:amount => 500, :unit_price => 500, :quantity => 1)
    end
  end

  def test_invalid_options
    assert_raise ArgumentError do 
      @helper.payment_option(4)
    end

    assert_raise ArgumentError do
      @helper.return_customer_info("abc")
    end

    assert_raise ArgumentError do
      @helper.add_discount(-500)
    end
  end

  def test_missing_password
    @helper.instance_eval{@secret = nil}
    assert_raise ArgumentError do
      @helper.form_fields
    end
  end

  def test_urls

    @helper.return_url = 'http://example.com/return'
    assert_field 'PaymentSuccessfulURL', 'http://example.com/return'

    @helper.cancel_return_url = 'http://example.com/cancel'
    assert_field 'PaymentCancelledURL', 'http://example.com/cancel'

  end

end
