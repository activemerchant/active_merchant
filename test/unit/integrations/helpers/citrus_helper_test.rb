require 'test_helper'

class CitrusHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Citrus::Helper.new('ORD123','G0JW45KCS3630NX335YX', :amount => 10, :currency => 'USD', :credential2 => '2c71a4ea7d2b88e151e60d9da38b2d4552568ba9', :credential3 => 'gqwnliur74')
  end

  def test_basic_helper_fields
    assert_equal '10', @helper.fields['orderAmount']
    assert_equal 'ORD123', @helper.fields['merchantTxnId']
    assert_equal 'G0JW45KCS3630NX335YX', @helper.fields['merchantAccessKey']
    assert_equal '2c71a4ea7d2b88e151e60d9da38b2d4552568ba9', @helper.fields['secret_key']
    assert_equal 'USD', @helper.fields['currency']
    assert_equal 'gqwnliur74', @helper.fields['pmt_url']
    assert_equal 'NET_BANKING', @helper.fields['paymentMode']
  end

  def test_customer_fields
    @helper.customer :first_name => 'Amit', :last_name => 'Pandey', :email => 'support@viatechs.in', :phone => '9832120202'
    assert_field 'firstName', 'Amit'
    assert_field 'lastName', 'Pandey'
    assert_field 'email', 'support@viatechs.in'
  end

  def test_address_mapping
    @helper.billing_address :address1 => '22 Avenue',
                            :address2 => 'South',
                            :city => 'Albany',
                            :state => 'New York',
                            :zip => 'NY 12207',
                            :country  => 'US'

    assert_field 'addressStreet1', '22 Avenue'
    assert_field 'addressStreet2', 'South'
    assert_field 'addressCity', 'Albany'
    assert_field 'addressState', 'New York'
    assert_field 'addressZip', 'NY 12207'
    assert_field 'addressCountry', 'US'
  end

  def test_unknown_address_mapping
    @helper.billing_address :farm => 'CA'
    assert_equal 8, @helper.fields.size
  end

  def test_form_fields
   	assert_equal 'ecf7eaafec270b9b91b898e7f8e794c30245eb7f', @helper.form_fields["secSignature"]
    rt = (Time.now.to_i * 1000).to_s
  	assert_equal rt, @helper.fields['reqtime']
  end

  def test_return_url_fields
    @helper.return_url 'some_return_url'
    assert_equal 'some_return_url', @helper.fields['returnUrl']
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

  def test_credential_based_url_method
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal 'https://sandbox.citruspay.com/gqwnliur74', @helper.credential_based_url
  end

  def test_production_service_url_method
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal 'https://www.citruspay.com/gqwnliur74', @helper.credential_based_url
  end
end
