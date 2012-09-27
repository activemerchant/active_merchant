# encoding: utf-8

require 'test_helper'

class SagePayFormHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @key = 'EncryptionKey123'
    @helper = SagePayForm::Helper.new('order-500', 'cody@example.com',
      :amount => '5.00',
      :currency => 'USD',
      :credential2 => @key
    )
    @helper.credential2
  end

  def test_basic_helper_fields
    assert_equal 5, @helper.fields.size
    assert_field 'Vendor', 'cody@example.com'
    assert_field 'Amount', '5.00'
    assert_field 'VendorTxCode', 'order-500'
  end

  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com'
    assert_equal 8, @helper.fields.size
    assert_field 'BillingFirstnames', 'Cody'
    assert_field 'BillingSurname', 'Fauser'
    assert_field 'CustomerEMail', 'cody@example.com'
  end

  def test_customer_send_email
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com', :send_email_confirmation => true
    with_crypt_plaintext do |plain|
      assert plain.include?('cody@example.com')
    end
  end

  def test_customer_default_no_email
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com'
    with_crypt_plaintext do |plain|
      assert !plain.include?('cody@example.com')
    end
  end

  def test_us_address_mapping
    @helper.billing_address(
      :address1 => '1 My Street',
      :address2 => '',
      :city => 'Chicago',
      :state => 'IL',
      :zip => '60606',
      :country  => 'US'
    )

    assert_equal 10, @helper.fields.size
    assert_field 'BillingAddress1', '1 My Street'
    assert_field 'BillingCity', 'Chicago'
    assert_field 'BillingState', 'IL'
    assert_field 'BillingPostCode', '60606'
    assert_field 'BillingCountry', 'US'

    with_crypt_plaintext do |plain|
      assert plain.include?('&BillingState=IL')
    end
  end

  def test_non_us_address_mapping
    @helper.billing_address(
      :address1 => '1 My Street',
      :address2 => '',
      :city => 'Leeds',
      :state => 'Yorkshire', # ignored
      :zip => 'LS23',
      :country  => 'GB'
    )

    assert_equal 10, @helper.fields.size
    assert_field 'BillingAddress1', '1 My Street'
    assert_field 'BillingCity', 'Leeds'
    assert_field 'BillingPostCode', 'LS23'
    assert_field 'BillingCountry', 'GB'

    with_crypt_plaintext do |plain|
      assert !plain.include?('&BillingState=')
      assert !plain.include?('Yorkshire')
    end
  end

  def test_shipping_address_falls_back_to_billing_address
    @helper.billing_address(
      :address1 => '1 My Street',
      :address2 => '',
      :city => 'Chicago',
      :state => 'IL',
      :zip => '60606',
      :country  => 'US'
    )

    @helper.form_fields
    assert_equal 19, @helper.fields.size
    assert_field 'DeliveryAddress1', '1 My Street'
    assert_field 'DeliveryCity', 'Chicago'
    assert_field 'DeliveryState', 'IL'
    assert_field 'DeliveryPostCode', '60606'
    assert_field 'DeliveryCountry', 'US'

    with_crypt_plaintext do |plain|
      assert plain.include?('&DeliveryState=IL')
    end
  end

  def test_description_should_truncate
    description = 'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut la'
    assert_equal 101, description.size
    @helper.add_field('Description', description)

    with_crypt_plaintext do |plain|
      assert plain.include?('Description=Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut l')
    end

    description = 'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut'
    assert_equal 98, description.size
    @helper.add_field('Description', description)

    with_crypt_plaintext do |plain|
      assert plain.include?('Description=Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut')
    end
  end

  def test_set_shipping_address_wont_be_overridden_by_billing_address
    @helper.billing_address(
      :address1 => '1 My Street',
      :address2 => '',
      :city => 'Chicago',
      :state => 'IL',
      :zip => '60606',
      :country  => 'US'
    )
    @helper.shipping_address(
      :address1 => '1 Shipping Street',
      :address2 => '',
      :city => 'Chicago Shipping',
      :state => 'NY',
      :zip => '123123',
      :country  => 'US'
    )

    @helper.form_fields
    assert_equal 18, @helper.fields.size
    assert_field 'DeliveryAddress1', '1 Shipping Street'
    assert_field 'DeliveryCity', 'Chicago Shipping'
    assert_field 'DeliveryState', 'NY'
    assert_field 'DeliveryPostCode', '123123'
    assert_field 'DeliveryCountry', 'US'
  end

  def test_unknown_address_mapping
    @helper.billing_address :farm => 'CA'
    assert_equal 5, @helper.fields.size
  end

  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '500 Dwemthy Fox Road'
    end
    assert_equal 5, @helper.fields.size
  end

  def test_setting_invalid_address_field
    fields = @helper.fields.dup
    @helper.billing_address :street => 'My Street'
    assert_equal fields, @helper.fields
  end

  def test_basic_form_fields
    params = @helper.form_fields

    assert_equal '2.23', params['VPSProtocol']
    assert_equal 'PAYMENT', params['TxType']
    assert_equal 'cody@example.com', params['Vendor']
    assert_not_nil params['Crypt']
  end

  def test_unicode_fields
    @helper.customer :first_name => 'Tobias', :last_name => "Lütke", :email => 'cody@example.com'
    params = @helper.form_fields

    assert_equal '2.23', params['VPSProtocol']
    assert_equal 'PAYMENT', params['TxType']
    assert_equal 'cody@example.com', params['Vendor']
    assert_not_nil params['Crypt']
  end

  def test_crypt_field_is_base64
    crypt = @helper.form_fields['Crypt']
    assert_match /^[A-Za-z0-9\+\/]+=*$/, crypt
  end

  def test_crypt_field_salt
    random = 'ExpectSomePartOfThisSalt'
    SecureRandom.expects(:base64).returns(random)

    with_crypt_plaintext do |plain|
      salt = plain.split('&').first
      assert random.start_with?(salt)
    end
  end

  def test_crypt_field_is_salted_uniq
    crypts = (1..5).map { @helper.dup.form_fields['Crypt'] }
    assert_equal 5, crypts.uniq.count
  end

  private

  def with_crypt_plaintext
    crypt = @helper.dup.form_fields['Crypt']
    yield @helper.sage_decrypt(crypt, @key)
  end
end
