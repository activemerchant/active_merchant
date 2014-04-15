require 'test_helper'

class PagSeguroHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = PagSeguro::Helper.new('order-500','cody@example.com', :credential2 => "USER_TOKEN", :amount => 55)
  end

  def test_basic_helper_fields
    assert_field 'email', 'cody@example.com'
    assert_field 'token', 'USER_TOKEN'

    assert_field 'itemAmount1', '55.00'
    assert_field 'reference', 'order-500'
    assert_field 'itemId1', '1'
    assert_field 'itemQuantity1', '1'
    assert_field 'shippingType', '3'
    assert_field 'currency', 'BRL'
  end

  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com', phone: "71 99223522"
    assert_field 'senderName', 'Cody Fauser'
    assert_field 'senderAreaCode', '71'
    assert_field 'senderPhone', '99223522'
    assert_field 'senderEmail', 'cody@example.com'
  end

  def test_area_code_and_number_formats_1
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com', phone: "71 99223522"
    assert_field 'senderAreaCode', '71'
    assert_field 'senderPhone', '99223522'
  end

  def test_area_code_and_number_formats_2
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com', phone: "71 99223522"
    assert_field 'senderAreaCode', '71'
    assert_field 'senderPhone', '99223522'
  end

  def test_area_code_and_number_formats_3
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com', phone: "71 99223522"
    assert_field 'senderAreaCode', '71'
    assert_field 'senderPhone', '99223522'
  end

  def test_area_code_and_number_formats_4
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com', phone: "71 99223522"
    assert_field 'senderAreaCode', '71'
    assert_field 'senderPhone', '99223522'
  end

  def test_area_code_and_number_formats_5
    @helper.customer :first_name => 'Cody', :last_name => "Fauser", :email => 'cody@example.com', phone: "(11) 99552345"
    assert_field 'senderAreaCode', "11"
    assert_field 'senderPhone', "99552345"
  end

  def test_area_code_and_number_formats_6
    @helper.customer :first_name => 'Cody', :last_name => "Fauser", :email => 'cody@example.com', phone: "(11) 9955-2345"
    assert_field 'senderAreaCode', "11"
    assert_field 'senderPhone', "99552345"
  end

  def test_area_code_and_number_formats_7
    @helper.customer :first_name => 'Cody', :last_name => "Fauser", :email => 'cody@example.com', phone: "(11) 99955-2345"
    assert_field 'senderAreaCode', "11"
    assert_field 'senderPhone', "999552345"
  end

  def test_area_code_and_number_formats_8
    @helper.customer :first_name => 'Cody', :last_name => "Fauser", :email => 'cody@example.com', phone: "(11) 9995-52345"
    assert_field 'senderAreaCode', "11"
    assert_field 'senderPhone', "999552345"
  end

  def test_area_code_and_number_formats_9
    @helper.customer :first_name => 'Cody', :last_name => "Fauser", :email => 'cody@example.com', phone: "11 99552345"
    assert_field 'senderAreaCode', "11"
    assert_field 'senderPhone', "99552345"
  end

  def test_area_code_and_number_formats_10
    @helper.customer :first_name => 'Cody', :last_name => "Fauser", :email => 'cody@example.com', phone: "11 9955-2345"
    assert_field 'senderAreaCode', "11"
    assert_field 'senderPhone', "99552345"
  end

  def test_area_code_and_number_formats_11
    @helper.customer :first_name => 'Cody', :last_name => "Fauser", :email => 'cody@example.com', phone: "11 99955-2345"
    assert_field 'senderAreaCode', "11"
    assert_field 'senderPhone', "999552345"
  end

  def test_area_code_and_number_formats_12
    @helper.customer :first_name => 'Cody', :last_name => "Fauser", :email => 'cody@example.com', phone: "11 9995-52345"
    assert_field 'senderAreaCode', "11"
    assert_field 'senderPhone', "999552345"
  end

  def test_area_code_and_number_formats_13
    @helper.customer :first_name => 'Cody', :last_name => "Fauser", :email => 'cody@example.com', phone: "9995-52345"
    assert_field 'senderAreaCode', "99"
    assert_field 'senderPhone', "9552345"
  end

  def test_area_code_and_number_formats_13
    @helper.customer :first_name => 'Cody', :last_name => "Fauser", :email => 'cody@example.com', phone: "1234"
    assert_field 'senderAreaCode', "12"
    assert_field 'senderPhone', "34"
  end

  def test_address_mapping
    @helper.billing_address :address1 => '1 My Street',
                            :address2 => '',
                            :city => 'Leeds',
                            :state => 'SP',
                            :zip => 'LS2 7EE',
                            :country  => 'CA'

    assert_field 'shippingAddressStreet', '1 My Street'
    assert_field 'shippingAddressCity', 'Leeds'
    assert_field 'shippingAddressState', 'SP'
    assert_field 'shippingAddressPostalCode', 'LS2 7EE'
    assert_field 'shippingAddressCountry', 'CA'
  end

  def test_unknown_address_mapping
    @helper.billing_address :farm => 'CA'
    assert_equal 8, @helper.fields.size
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

  def test_notification_mapping
    @helper.notify_url "https://notify_url.com"
    @helper.return_url "https://return_url.com"

    assert_field 'notificationURL', 'https://notify_url.com'
    assert_field 'redirectURL', 'https://return_url.com'
  end

  def test_description_mapping
    @helper.description "Some description"

    assert_field 'itemDescription1', 'Some description'
  end

  def test_get_token_should_get_the_token
    Net::HTTP.any_instance.expects(:request).returns(stub(code: "200" , body: '<?xml version=\"1.0\" encoding=\"ISO-8859-1\" standalone=\"yes\"?><checkout><code>E20521EF6C6C159994DFFF8F5A4C3ED7</code><date>2014-02-12T02:10:25.000-02:00</date></checkout>"'))
    assert "E20521EF6C6C159994DFFF8F5A4C3ED7", @helper.fetch_token
  end

  def test_fetch_token_raises_error_if_400_error_present
    Net::HTTP.any_instance.expects(:request).returns(stub(code: "400" , body: '<?xml version="1.0" encoding="ISO-8859-1" standalone="yes"?><errors><error><code>11014</code><message>senderPhone invalid value: 1232312356273440</message></error></errors>'))

    assert_raise StandardError do
      @helper.fetch_token
    end
  end

  def test_fetch_token_raises_error_if_401_error_present
    Net::HTTP.any_instance.expects(:request).returns(stub(code: "401" , body: '<?xml version="1.0" encoding="ISO-8859-1" standalone="yes"?><errors><error><code>11014</code><message>senderPhone invalid value: 1232312356273440</message></error></errors>'))

    assert_raise StandardError do
      @helper.fetch_token
    end
  end

  def test_fetch_token_raises_error_if_pagseguro_fails
    Net::HTTP.any_instance.expects(:request).returns(stub(code: "500", body: ""))

    assert_raise ActiveMerchant::ResponseError do
      @helper.fetch_token
    end
  end
end
