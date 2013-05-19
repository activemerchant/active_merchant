require 'test_helper'

class VerkkomaksutHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Verkkomaksut::Helper.new('2','13466', :amount => 500, :currency => 'EUR', :credential2 => "6pKF4jkv97zmqBJ3ZL8gUw5DfT2NMQ")
  end

  def test_basic_helper_fields
    assert_field 'MERCHANT_ID', '13466'
    assert_field 'ORDER_NUMBER', '2'
    assert_field 'CURRENCY', 'EUR'
  end

  def test_customer_fields
    @helper.customer :first_name => 'Antti', :last_name => 'Akonniemi', :email => 'antti@example.com', :phone => "0401234556", :tellno => "0401234557", :company => "Kisko Labs"
    assert_field 'CONTACT_FIRSTNAME', 'Antti'
    assert_field 'CONTACT_LASTNAME', 'Akonniemi'
    assert_field 'CONTACT_EMAIL', 'antti@example.com'
    assert_field 'CONTACT_CELLNO', '0401234556'
    assert_field 'CONTACT_TELLNO', '0401234557'
    assert_field 'CONTACT_COMPANY', 'Kisko Labs'
  end

  def test_address_mapping
    @helper.billing_address :address1 => '1 My Street',
                            :address2 => '',
                            :city => 'Helsinki',
                            :state => '-',
                            :zip => '00180',
                            :country  => 'Finland'

    assert_field 'CONTACT_ADDR_STREET', '1 My Street'
    assert_field 'CONTACT_ADDR_CITY', 'Helsinki'
    assert_field 'CONTACT_ADDR_ZIP', '00180'
    assert_field 'CONTACT_ADDR_COUNTRY', 'FI'
  end

  def test_authcode_generation
    @helper.customer :first_name => 'Antti', :last_name => 'Akonniemi', :email => 'antti@example.com', :phone => "0401234556", :tellno => "0401234557", :company => "Kisko Labs"
    @helper.billing_address :address1 => '1 My Street',
                            :address2 => '',
                            :city => 'Helsinki',
                            :state => '-',
                            :zip => '00180',
                            :country  => 'Finland'
    @helper.items = 1
    @helper.item_title_0 = "test"
    @helper.item_no_0 = "1"
    @helper.item_amount_0 = "1"
    @helper.item_price_0 = "30.00"
    @helper.item_tax_0 = "23.00"
    @helper.item_discount_0 = "0"


    @helper.include_vat '1'

    @helper.return_url "http://example.com"
    @helper.cancel_return_url "http://example.com"
    assert_equal @helper.generate_md5string, "AC7B763192D40886906E657E2ED26E17"
  end

  def test_unknown_address_mapping
    @helper.billing_address :farm => 'CA'
    assert_equal 4, @helper.fields.size
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
end
