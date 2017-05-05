require 'test_helper'

class DirecPayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = DirecPay::Helper.new('#1234', 'account id', :amount => 500, :currency => 'INR')
  end

  def test_basic_helper_fields
    assert_field 'MID', 'account id'
    assert_field 'Merchant Order No', '#1234'

    assert_field 'Amount', '5.00'
    assert_field 'Currency', 'INR'
    assert_field 'Country', 'IND'
  end

  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com'
    assert_field 'custName', 'Cody Fauser'
    assert_field 'custEmailId', 'cody@example.com'
  end

  def test_billing_address_mapping
    @helper.billing_address :address1 => '1 My Street',
                            :address2 => 'apartment 8',
                            :city => 'Leeds',
                            :state => 'Yorkshire',
                            :zip => 'LS2 7EE',
                            :country  => 'IN'

    assert_field 'custAddress', '1 My Street apartment 8'
    assert_field 'custCity', 'Leeds'
    assert_field 'custState', 'Yorkshire'
    assert_field 'custPinCode', 'LS2 7EE'
    assert_field 'custCountry', 'IN'
  end

  def test_address_with_a_single_street_address_field
    @helper.billing_address :address1 => "1 My Street"
    @helper.shipping_address :address1 => "1 My Street"
    assert_field "custAddress", "1 My Street"
    assert_field "deliveryAddress", "1 My Street"
  end

  def test_address_with_two_street_address_fields
    @helper.customer :first_name => "Bob", :last_name => "Biller"
    @helper.billing_address :address1 => "1 Bill Street", :address2 => "Bill Address 2"
    @helper.shipping_address :first_name => "Stan", :last_name => "Shipper", :address1 => "1 Ship Street", :address2 => "Ship Address 2"
    assert_field 'custName', 'Bob Biller'
    assert_field "custAddress", "1 Bill Street Bill Address 2"
    assert_field 'deliveryName', 'Stan Shipper'
    assert_field "deliveryAddress", "1 Ship Street Ship Address 2"
  end

  def test_phone_number_for_billing_address
    @helper.billing_address :phone => "+91 022 28000000"
    assert_field 'custMobileNo', '91 022 28000000'
  end

  def test_phone_number_for_shipping_address
    @helper.shipping_address :phone => "+91 022 28000000"
    assert_field 'deliveryMobileNo', '91 022 28000000'
  end

  def test_land_line_phone_number_mapping_for_india
    @helper.billing_address :phone2 => "+91 022 28000000", :country => 'IN'

    assert_field 'custPhoneNo1', '91'
    assert_field 'custPhoneNo2', '022'
    assert_field 'custPhoneNo3', '28000000'
  end

  def test_land_line_phone_number_mapping_for_america
    @helper.billing_address :phone2 => "6131234567", :country => 'CA'

    assert_field 'custPhoneNo1', '01'
    assert_field 'custPhoneNo2', '613'
    assert_field 'custPhoneNo3', '1234567'
  end

  def test_land_line_phone_number_mapping_for_germany
    @helper.billing_address :phone2 => "+49 2628 12345", :country => 'DE'

    assert_field 'custPhoneNo1', '49'
    assert_field 'custPhoneNo2', '2628'
    assert_field 'custPhoneNo3', '12345'
  end

  def test_shipping_address_mapping
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com'
    @helper.shipping_address :address1 => '1 My Street',
                             :address2 => 'apartment 8',
                             :city => 'Leeds',
                             :state => 'Yorkshire',
                             :zip => 'LS2 7EE',
                             :country  => 'IN'

    assert_field 'deliveryAddress', '1 My Street apartment 8'
    assert_field 'deliveryCity', 'Leeds'
    assert_field 'deliveryState', 'Yorkshire'
    assert_field 'deliveryPinCode', 'LS2 7EE'
    assert_field 'deliveryCountry', 'IN'
    assert_field 'deliveryName', 'Cody Fauser'
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

  def test_add_request_parameters
    fill_in_transaction_details!(@helper)

    transaction_params = ['account id', 'DOM', 'IND', 'INR', '5.00', "#1234", 'NULL', "http://localhost/return", "http://localhost/return", "TOML"]
    @helper.expects(:encode_value).with(transaction_params.join('|')).returns("dummy encoded value").twice

    @helper.form_fields
    @helper.send(:add_request_parameters)
    assert_field 'requestparameter', "dummy encoded value"
  end

  def test_parameters_do_not_contain_special_characters
    @helper.customer :first_name => "Bob", :last_name => "B & Ob", :email => 'bob@example.com'
    @helper.description "50% discount for bob's order"

    @helper.form_fields.each do |name, value|
      assert_no_match %r/[~'"&#%]/, value
    end
  end


  def test_exported_form_fields
    fill_in_transaction_details!(@helper)

    exported_fields = [
      "custAddress",
      "custCity",
      "custCountry",
      "custEmailId",
      "custMobileNo",
      "custName",
      "custPhoneNo1",
      "custPhoneNo2",
      "custPhoneNo3",
      "custPinCode",
      "custState",
      "deliveryAddress",
      "deliveryCity",
      "deliveryCountry",
      "deliveryMobileNo",
      "deliveryName",
      "deliveryPhNo1",
      "deliveryPhNo2",
      "deliveryPhNo3",
      "deliveryPinCode",
      "deliveryState",
      "editAllowed",
      "otherNotes",
      "requestparameter"
    ]
    assert_equal exported_fields, @helper.form_fields.keys.sort
  end

  def test_encode_value
    # outofdate_expected = 'TVRqQXdPVEEwTWpneE1EQXdNREF4ZkVSUFRYeEpUa1I4U1U1U2ZEVTRMakF3ZkRJeWZERjhhSFIwY0RvdkwyeHZZMkZzYUc5emREb3pNREF3TDI5eVpHVnljeTh4TDJWa05USXpNRFk1Tm1Ga05USTFZamxsTXpJeVlUWmhOalJpTlRZek1qSmxMMlJ2Ym1VL2RYUnRYMjV2YjNabGNuSnBaR1U5TVh4b2RIUndPaTh2YUdGeVpHTnZjbVZuWVcxbGNpNXNiMk5oYkdodmMzUTZNekF3TUh4VVQwMU0='
    expected = 'TVRqQXdPVEEwTWpneE1EQXdNREF4ZkVSUFRYeEpUa1I4U1U1U2ZEVTRMakF3ZkRJeWZFNVZURXg4YUhSMGNEb3ZMMnh2WTJGc2FHOXpkRG96TURBd0wyOXlaR1Z5Y3k4eEwyVmtOVEl6TURZNU5tRmtOVEkxWWpsbE16SXlZVFpoTmpSaU5UWXpNakpsTDJSdmJtVS9kWFJ0WDI1dmIzWmxjbkpwWkdVOU1YeG9kSFJ3T2k4dmFHRnlaR052Y21WbllXMWxjaTVzYjJOaGJHaHZjM1E2TXpBd01IeFVUMDFN'
    decoded  = '200904281000001|DOM|IND|INR|58.00|22|NULL|http://localhost:3000/orders/1/ed5230696ad525b9e322a6a64b56322e/done?utm_nooverride=1|http://hardcoregamer.localhost:3000|TOML'

    encoded = @helper.send(:encode_value, decoded)
    assert_equal expected, encoded
  end

  def test_decode_value
    expected = '200904281000001|DOM|IND|INR|58.00|22|1|http://localhost:3000/orders/1/ed5230696ad525b9e322a6a64b56322e/done?utm_nooverride=1|http://hardcoregamer.localhost:3000|TOML'
    encoded = 'TVRqQXdPVEEwTWpneE1EQXdNREF4ZkVSUFRYeEpUa1I4U1U1U2ZEVTRMakF3ZkRJeWZERjhhSFIwY0RvdkwyeHZZMkZzYUc5emREb3pNREF3TDI5eVpHVnljeTh4TDJWa05USXpNRFk1Tm1Ga05USTFZamxsTXpJeVlUWmhOalJpTlRZek1qSmxMMlJ2Ym1VL2RYUnRYMjV2YjNabGNuSnBaR1U5TVh4b2RIUndPaTh2YUdGeVpHTnZjbVZuWVcxbGNpNXNiMk5oYkdodmMzUTZNekF3TUh4VVQwMU0='

    decoded = @helper.send(:decode_value, encoded)
    assert_equal expected, decoded
  end

  def test_failure_url
    @helper.return_url = "http://localhost/return"
    @helper.failure_url = "http://localhost/fail"

    assert_field 'Failure URL', "http://localhost/fail"
  end

  def test_failure_url_is_set_to_return_url_if_not_provided
    @helper.return_url = "http://localhost/return"
    @helper.form_fields
    assert_field 'Failure URL', "http://localhost/return"
  end


  def test_status_supports_ssl_get
    assert DirecPay::Status.new('dummy-account').respond_to?(:ssl_get)
  end

  def test_status_update_in_production_mode
    ActiveMerchant::Billing::Base.integration_mode = :production
    params = "dummy-authorization|1234|http://localhost/notify"
    DirecPay::Status.any_instance.expects(:ssl_get).with("https://www.timesofmoney.com/direcpay/secure/dpPullMerchAtrnDtls.jsp?requestparams=#{CGI.escape(params)}")

    DirecPay::Status.new(1234, :test => false).update("dummy-authorization", "http://localhost/notify")
    ActiveMerchant::Billing::Base.integration_mode = :test
  end

  def test_status_update_in_test_mode
    params = "dummy-authorization|1234|http://localhost/notify"
    DirecPay::Status.any_instance.expects(:ssl_get).with("https://test.direcpay.com/direcpay/secure/dpMerchantTransaction.jsp?requestparams=#{CGI.escape(params)}")

    DirecPay::Status.new(1234, :test => true).update("dummy-authorization", "http://localhost/notify")
  end



  private

  def fill_in_transaction_details!(helper)
    helper.customer :first_name => 'Carl', :last_name => 'Carlton', :email => 'carlton@example.com'
    helper.description = "blabla"

    indian_address = address(:country => "India", :phone => "9122028000000", :phone2 => '+1 613 123 4567')
    helper.shipping_address(indian_address)
    helper.billing_address(indian_address)

    helper.return_url = "http://localhost/return"
  end
end
