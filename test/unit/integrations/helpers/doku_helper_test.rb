require 'test_helper'

class DokuHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Doku::Helper.new('ORD12345', 'STORE123456', :amount => 165000, :currency => 'IDR', :shared_key => 'DOKU_SHARED_KEY')
  end

  def test_basic_helper_fields
    assert_field 'STOREID', 'STORE123456'

    assert_field 'AMOUNT', '165000.00'
    assert_field 'TRANSIDMERCHANT', 'ORD12345'
  end

  def test_customer_fields
    @helper.customer :name              => 'Ismail Danuarta',
                     :email             => 'ismail.danuarta@gmail.com',
                     :mobile_phone      => '085779280093',
                     :working_phone     => '0215150555',
                     :home_phone        => '0215150555',
                     :birth_date        => '1991-09-11'

    assert_field 'CNAME', 'Ismail Danuarta'
    assert_field 'CEMAIL', 'ismail.danuarta@gmail.com'
    assert_field 'CMPHONE', '085779280093'
    assert_field 'CWPHONE', '0215150555'
    assert_field 'CHPHONE', '0215150555'
    assert_field 'BIRTHDATE', '1991-09-11'
  end

  def test_address_mapping
    @helper.billing_address :city     => 'Jakarta Selatan',
                            :address  => 'Jl. Jendral Sudirman kav 59, Plaza Asia Office Park Unit 3',
                            :state    => 'DKI Jakarta',
                            :zip      => '12190',
                            :country  => 'ID'

    assert_field 'CCITY', 'Jakarta Selatan'
    assert_field 'CADDRESS', 'Jl. Jendral Sudirman kav 59, Plaza Asia Office Park Unit 3'
    assert_field 'CSTATE', 'DKI Jakarta'
    assert_field 'CZIPCODE', '12190'
    assert_field 'CCOUNTRY', '360'
  end

  def test_shipping_mapping
    @helper.shipping_address :city     => 'Jakarta Selatan',
                             :address  => 'Jl. Jendral Sudirman kav 59, Plaza Asia Office Park Unit 3',
                             :state    => 'DKI Jakarta',
                             :zip      => '12190',
                             :country  => 'ID'

    assert_field 'SCITY', 'Jakarta Selatan'
    assert_field 'SADDRESS', 'Jl. Jendral Sudirman kav 59, Plaza Asia Office Park Unit 3'
    assert_field 'SSTATE', 'DKI Jakarta'
    assert_field 'SZIPCODE', '12190'
    assert_field 'SCOUNTRY', '360'
  end

  def test_unknown_address_mapping
    @helper.billing_address :farm => 'CA'
    assert_equal 3, @helper.fields.size
  end

  def test_basket
    @helper.add_item(:name => 'Item 1', :quantity => 2, :price => 70_000)
    @helper.add_item(:name => 'Item 2', :quantity => 1, :price => 25_000)
    assert_equal true, @helper.form_fields.include?('BASKET')
    assert_equal 'Item 1,70000.00,2,140000.00;Item 2,25000.00,1,25000.00', @helper.form_fields['BASKET']
  end

  def test_words
    assert_equal true, @helper.form_fields.include?('WORDS')
    assert_equal '9bce0d4b77799c22f4f14e3c949a2a25dd6c33e2', @helper.form_fields['WORDS']
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
