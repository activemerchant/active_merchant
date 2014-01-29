require 'test_helper'

class DokuHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @store_id = 'STORE123456'
    @shared_key = 'DOKU_SHARED_KEY'
    @transidmerchant = 'ORD12345'
    @amount = '165000.00'
    @words = Digest::SHA1.hexdigest "#{@amount}#{@shared_key}#{@transidmerchant}"
    @helper = Doku::Helper.new(@transidmerchant, @store_id, :amount => @amount, :currency => 'IDR', :credential2 => @shared_key)
  end

  def test_basic_helper_fields
    assert_field 'STOREID', @store_id
    assert_field 'AMOUNT', @amount
    assert_equal @transidmerchant, @helper.form_fields['TRANSIDMERCHANT']
  end

  def test_customer_fields
    @helper.customer :first_name        => 'Ismail',
                     :last_name         => 'Danuarta',
                     :email             => 'ismail.danuarta@gmail.com',
                     :mobile_phone      => '085779280093',
                     :working_phone     => '0215150555',
                     :phone             => '0215150555',
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
                            :address1 => 'Jl. Jendral Sudirman kav 59, Plaza Asia Office Park Unit 3',
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
                             :address1 => 'Jl. Jendral Sudirman kav 59, Plaza Asia Office Park Unit 3',
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
    assert_equal 2, @helper.fields.size
  end

  def test_basket
    assert_equal "Checkout #{@transidmerchant},#{@amount},1,#{@amount}", @helper.form_fields['BASKET']
  end

  def test_words
    assert_equal true, @helper.form_fields.include?('WORDS')
    assert_equal @words, @helper.form_fields['WORDS']
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
