require 'test_helper'

class FirstDataNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @first_data = FirstData::Notification.new(http_raw_data)
  end

  def test_accessors_when_not_set
    @first_data = FirstData::Notification.new("")
    assert !@first_data.complete?
    assert_equal [], @first_data.billing_address.values.compact
    assert_equal [], @first_data.ship_to_address.values.compact
    assert_equal({}, @first_data.all_custom_values_passed_in_and_now_passed_back_to_us)
    assert !@first_data.avs_code_matches?
    assert !@first_data.cavv_matches?

    assert !@first_data.test? # default is false
    [
      :customer_id, :auth_code, :po_num,
      :tax, :transaction_type, :method, :method_available, :invoice_num,
      :duty, :freight, :shipping, :description, :response_code_as_ruby_symbol,
      :response_reason_text, :response_reason_code,
      :response_subcode, :tax_exempt, :avs_code, :cvv2_resp_code, :cavv_response,
      :item_id, :transaction_id, :payer_email, :security_key, :gross
    ].each{|m| assert_equal nil, @first_data.send(m)}
  end

  def test_compositions
    assert_equal Money.new(12100, 'USD'), @first_data.amount
  end

  def test_accessors_when_set
    {
      :gross => "121.00", :auth_code => "000000",
      :payer_email => "test@test.com", :item_id => "441543269",
      :complete? => true, :duty => "0.0000", :customer_id => "10",
      :avs_code => "P", :cvv2_resp_code_matches? => false,
      :cvv2_resp_code => "", :tax_exempt => "FALSE",
      :billing_address => {
        :country => "United States of America", :fax => "",
        :email => "test@test.com", :address => "test", :first_name => "test",
        :company => "", :city => "test", :state => "UT", :zip => "84601",
        :last_name => "test"
      },
      :ship_to_address => {
        :country => "United States of America", :address => "test",
        :first_name => "test", :city => "test", :zip => "84601",
        :last_name => "test"
      },
      :test? => true,:response_reason_code => "1", :status => true,
      :security_key => "9B934370EE2378E844B0A6A6C6FC42E4",
      :response_code_as_ruby_symbol => :approved, :cavv_matches? => true,
      :po_num => "",
      :all_custom_values_passed_in_and_now_passed_back_to_us => {
        "commit" => "Pay securely with First Data"
      },
      :receiver_email => nil, :invoice_num => "441543269"
    }.each{|m, v| assert_equal(v, @first_data.send(m))}
  end

  def test_acknowledgement
    assert !@first_data.acknowledge('abc', 'def')
    assert @first_data.acknowledge('', '8wd65QSj')
  end

  def test_respond_to_acknowledge
    assert @first_data.respond_to?(:acknowledge)
  end

  private

  def http_raw_data
    "x_response_code=1&x_response_subcode=1&x_response_reason_code=1&x_response_reason_text=%28TESTMODE%29+This+transaction+has+been+approved%2E&x_auth_code=000000&x_avs_code=P&x_trans_id=0&x_invoice_num=441543269&x_description=&x_amount=121%2E00&x_method=CC&x_type=auth%5Fcapture&x_cust_id=10&x_first_name=test&x_last_name=test&x_company=&x_address=test&x_city=test&x_state=UT&x_zip=84601&x_country=United+States+of+America&x_phone=8013776152&x_fax=&x_email=test%40test%2Ecom&x_ship_to_first_name=test&x_ship_to_last_name=test&x_ship_to_company=&x_ship_to_address=test&x_ship_to_city=test&x_ship_to_state=UT&x_ship_to_zip=84601&x_ship_to_country=United+States+of+America&x_tax=0%2E0000&x_duty=0%2E0000&x_freight=25%2E0000&x_tax_exempt=FALSE&x_po_num=&x_MD5_Hash=9B934370EE2378E844B0A6A6C6FC42E4&x_cvv2_resp_code=&x_cavv_response=&x_test_request=true&commit=Pay+securely+with+First+Data&x_method_available=true"
  end
end
