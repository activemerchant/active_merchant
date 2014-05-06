require 'test_helper'

class CybersourceSecureAcceptanceHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = CybersourceSecureAcceptance::Helper.new('order-500','accesskey',
      :amount => 500, :currency => 'USD', :credential2 => 'SAMPLE1', :credential3 => 'secret_key',
      :transaction_uuid_override => '3ca30b6f20815bbc4e7981b1bddc2a39',
      :signed_date_time_override => '2014-05-05T15:12:23Z')
  end

  def test_default_endpoint
    assert_equal 'https://testsecureacceptance.cybersource.com/pay', @helper.credential_based_url
  end

  def test_silent_order_endpoint
    @helper = CybersourceSecureAcceptance::Helper.new('order-500','accesskey',
      :amount => 500, :currency => 'USD', credential2: 'SAMPLE1', endpoint: :silent_order)
    assert_equal 'https://testsecureacceptance.cybersource.com/silent/pay', @helper.credential_based_url
  end

  def test_return_url
    @helper.return_url 'http://localhost/test'
    assert_field 'override_custom_receipt_page', 'http://localhost/test'
  end

  def test_payment_token
    @helper.payment_token 'token'
    assert_field 'payment_token', 'token'
  end

  def test_basic_helper_fields
    assert_field 'access_key', 'accesskey'
    assert_field 'profile_id', 'SAMPLE1'

    assert_field 'amount', '5.00'
    assert_field 'reference_number', 'order-500'
  end

  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com'
    assert_field 'bill_to_forename', 'Cody'
    assert_field 'bill_to_surname', 'Fauser'
    assert_field 'bill_to_email', 'cody@example.com'
  end

  def test_address_mapping
    @helper.billing_address :address1 => '1 My Street',
                            :address2 => '',
                            :city => 'Leeds',
                            :state => 'Yorkshire',
                            :zip => 'LS2 7EE',
                            :country  => 'CA'

    assert_field 'bill_to_address_line1', '1 My Street'
    assert_field 'bill_to_address_city', 'Leeds'
    assert_field 'bill_to_address_state', 'Yorkshire'
    assert_field 'bill_to_address_postal_code', 'LS2 7EE'
  end

  def test_unknown_address_mapping
    @helper.billing_address :farm => 'CA'
    assert_equal 9, @helper.fields.size
  end

  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '500 Dwemthy Fox Road'
    end
  end

  def test_setting_invalid_address_field
    fields = @helper.fields.dup
    @helper.billing_address :street => 'My Street'
    assert_equal fields, @helper.fields
  end

  def test_invalid_transaction_type
    assert_raise ArgumentError do
      @helper = CybersourceSecureAcceptance::Helper.new('order-500','accesskey',
        :amount => 500, :currency => 'USD', credential2: 'SAMPLE1', transaction_type: 'bad')
    end
  end

  def test_get_signature
    assert_equal '5H68czMihGmb+p0ALMeRekWEJM8KfK7CL1mD/jlVa0M=', @helper.get_signature
  end

  def test_line_item_mapping
    @helper.add_line_item :code => 'default', :name => 'orange', :sku => 'ORA1', :unit_price => 30, :tax_amount => 5, :quantity => 3

    assert_field 'item_0_name', 'orange'
    assert_field 'item_0_tax_amount', "0.05"
    assert_field 'item_0_unit_price', "0.30"
    assert_field 'item_0_code', "default"
    assert_field 'item_0_quantity', "3"
    assert_field 'item_0_sku', "ORA1"
  end

  def test_simple_line_item
    @helper.add_line_item :name => 'orange'

    assert_field 'item_0_name', 'orange'

    assert_false @helper.fields['item_0_tax_amount']
    assert_false @helper.fields['item_0_unit_price']
    assert_false @helper.fields['item_0_code']
    assert_false @helper.fields['item_0_quantity']
    assert_false @helper.fields['item_0_sku']
  end

  def test_invalid_line_code
    assert_raise ArgumentError do
      @helper.add_line_item :code => 'bad', :name => 'orange'
    end
  end

  def test_missing_quantity_or_sku
    assert_raise ArgumentError do
      @helper.add_line_item :code => 'electronic_software', :name => 'orange'
    end
  end

  def test_max_items
    51.times do
      @helper.add_line_item :code => 'default', :name => 'orange', :sku => 'ORA1', :unit_price => 30, :tax_amount => 5, :quantity => 3
    end
    assert_field 'item_49_name', "There are 2 additional line item(s)..."
    assert_field 'item_49_unit_price', "1.80"
    assert_field 'item_49_tax_amount', "0.30"
    assert_field 'item_49_quantity', "1"
    assert_field 'item_49_code', "default"
    assert_equal 50, @helper.line_item_count
  end
end
