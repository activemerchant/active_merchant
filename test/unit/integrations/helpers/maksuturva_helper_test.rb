require "test_helper"

class MaksuturvaHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Maksuturva::Helper.new("2","testikauppias", :amount => "200,00", :currency => "EUR", :credential2 => "11223344556677889900")
  end

  def test_basic_helper_fields
    assert_field "pmt_id", "2"

    assert_field "pmt_amount", "200,00"
    assert_field "pmt_currency", "EUR"
    assert_field "pmt_action", "NEW_PAYMENT_EXTENDED"
    assert_field "pmt_sellerid", "testikauppias"
  end

  def test_customer_fields
    @helper.customer :first_name => "Cody", :last_name => "Fauser", :email => "cody@example.com"
    assert_field "pmt_buyeremail", "cody@example.com"
  end

  def test_address_mapping
    @helper.billing_address :address1 => "1 My Street",
                            :address2 => "",
                            :city => "Leeds",
                            :zip => "LS2 7EE",
                            :country  => "CA"

    assert_field "pmt_buyeraddress", "1 My Street"
    assert_field "pmt_buyercity", "Leeds"
    assert_field "pmt_buyerpostalcode", "LS2 7EE"
    assert_field "pmt_buyercountry", "CA"
  end

  def test_authcode_generation
    @helper.customer :email => 'antti@example.com', :phone => "0401234556"
    @helper.billing_address :address1 => '1 My Street',
                            :address2 => '',
                            :city => 'Helsinki',
                            :state => '-',
                            :zip => '00180',
                            :country  => 'Finland'
    @helper.pmt_reference = "134662"
    @helper.pmt_duedate = "24.06.2012"
    @helper.pmt_reference = "134662"
    @helper.pmt_duedate = "24.06.2012"

    @helper.pmt_orderid = "2"
    @helper.pmt_buyername = "Antti Akonniemi"
    @helper.pmt_deliveryname = "Antti Akonniemi"
    @helper.pmt_deliveryaddress = "1 My Street"
    @helper.pmt_deliverypostalcode = "00180"
    @helper.pmt_deliverycity = "Helsinki"
    @helper.pmt_deliverycountry = "FI"
    @helper.pmt_rows = 1
    @helper.pmt_row_name1 = "testi"
    @helper.pmt_row_desc1 = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    @helper.pmt_row_articlenr1 = "1"
    @helper.pmt_row_quantity1 = "1"
    @helper.pmt_row_deliverydate1 = "26.6.2012"
    @helper.pmt_row_price_gross1 = "200,00"
    @helper.pmt_row_vat1= "23,00"
    @helper.pmt_row_discountpercentage1 = "0,00"
    @helper.pmt_row_type1 = "1"
    @helper.pmt_charset = "UTF-8"
    @helper.pmt_charsethttp = "UTF-8"

    @helper.return_url "http://localhost/pages/process"
    @helper.cancel_return_url "http://example.com"
    @helper.pmt_errorreturn "http://example.com"

    @helper.pmt_delayedpayreturn "http://example.com"
    @helper.pmt_escrow "N"
    @helper.pmt_escrowchangeallowed "N"
    @helper.pmt_sellercosts "0,00"
    @helper.pmt_keygeneration "001"
    assert_equal @helper.generate_md5string, "DD27A6D63F47FEFE7743EFA68D1C397D"
  end

  def test_unknown_address_mapping
    @helper.billing_address :farm => "CA"
    assert_equal 7, @helper.fields.size
  end

  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => "500 Dwemthy Fox Road"
    end
  end

  def test_setting_invalid_address_field
    fields = @helper.fields.dup
    @helper.billing_address :street => "My Street"
    assert_equal fields, @helper.fields
  end
end
