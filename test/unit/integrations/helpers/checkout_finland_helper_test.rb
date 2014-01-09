require 'test_helper'

class CheckoutFinlandHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = CheckoutFinland::Helper.new('1389003386','375917', :amount => 200, :currency => 'EUR', :credential2 => "SAIPPUAKAUPPIAS")
  end
 
  def test_basic_helper_fields
    assert_field 'MERCHANT', '375917'

    assert_field 'AMOUNT', '200'
    assert_field 'STAMP', '1389003386'
  end
  
  def test_customer_fields
    @helper.customer :first_name => 'Tero', :last_name => 'Testaaja', :phone => '0800 552 010', :email => 'support@checkout.fi'
    assert_field 'FIRSTNAME', 'Tero'
    assert_field 'FAMILYNAME', 'Testaaja'
    assert_field 'PHONE', '0800 552 010'
    assert_field 'EMAIL', 'support@checkout.fi'
  end

  def test_address_mapping
    @helper.billing_address :address1 => 'Testikatu 1 A 10',
                            :city => 'Helsinki',
                            :zip => '00100',
                            :country  => 'FIN'
   
    assert_field 'ADDRESS', 'Testikatu 1 A 10'
    assert_field 'POSTOFFICE', 'Helsinki'
    assert_field 'POSTCODE', '00100'
    assert_field 'COUNTRY', 'FIN'
  end

  def test_authcode_generation
    @helper.customer :first_name => 'Tero', :last_name => 'Testaaja', :phone => '0800 552 010', :email => 'support@checkout.fi'
    @helper.billing_address :address1 => 'Testikatu 1 A 10',
                            :city => 'Helsinki',
                            :zip => '00100',
                            :country  => 'FIN'

    @helper.reference = "474738238"
    @helper.language = "FI"
    @helper.content = "1"
    @helper.delivery_date = "20140110"
    @helper.description = "Some items"

    @helper.notify_url = "http://www.example.com/notify"
    @helper.reject_url = "http://www.example.com/reject"
    @helper.return_url = "http://www.example.com/return"
    @helper.cancel_return_url = "http://www.example.com/cancel"

    assert_equal @helper.generate_md5string, "0968BCF2A747F4A9118A889C8EC5CDA3"

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

  def test_xml_response_parsing
    payment_array = @helper.parse_xml_response(mock_xml_response_data)
    assert_equal payment_array.size, 1
    assert_equal payment_array[0]["name"], "Danske Bank"
    assert_equal payment_array[0]["url"], "https://verkkopankki.danskebank.fi/SP/vemaha/VemahaApp"
    assert_equal payment_array[0]["icon"], "https://payment.checkout.fi/static/img/danskebank.png"
    assert_equal payment_array[0]["fields"].size, 11
    assert_equal payment_array[0]["fields"]["SUMMA"], "2.00"
    assert_equal payment_array[0]["fields"]["VIITE"], "123696650"
    assert_equal payment_array[0]["fields"]["KNRO"], "000000000000"
    assert_equal payment_array[0]["fields"]["VALUUTTA"], "EUR"
    assert_equal payment_array[0]["fields"]["VERSIO"], "3"
    assert_equal payment_array[0]["fields"]["OKURL"], "https://payment.checkout.fi/07mhA0Uybd/fi/confirm?ORDER=11831869&ORDERMAC=A33F99E42E465A8D598BD8FD46F71CAE"
    assert_equal payment_array[0]["fields"]["VIRHEURL"], "https://payment.checkout.fi/07mhA0Uybd/fi/back"
    assert_equal payment_array[0]["fields"]["TARKISTE"], "4031b379fb6f26df277fc64d77baa42d9d96844040275544c15364b6ec46c36b"
    assert_equal payment_array[0]["fields"]["ERAPAIVA"], "09.01.2014"
    assert_equal payment_array[0]["fields"]["ALG"], ""
    assert_equal payment_array[0]["fields"]["lng"], "1"
  end

  def mock_xml_response_data
    '<?xml version="1.0" encoding="utf-8"?><trade><id>11831869</id><description>Joku Tilaus</description><status>-1</status><returnURL>http://www.example.com</returnURL><returnMAC/><cancelURL>http://www.example.com</cancelURL><cancelMAC>FD7A4506D32D21080C17F71489C1085ABA0349A560186C36E41519EC41CFA675</cancelMAC><rejectURL>http://www.example.com</rejectURL><delayedURL>http://www.example.com</delayedURL><delayedMAC>4902B8EECD1CD92E24E1D9B4496B5AE27422899BF1A19512059540F27123346D</delayedMAC><stamp>1389270899</stamp><version>0001</version><reference>474738238</reference><language>FI</language><content>1</content><deliveryDate>20140110</deliveryDate><firstname>Tero</firstname><familyname>Testaaja</familyname><address>Testikatu 1 A 10</address><postcode>00100</postcode><postoffice>Helsinki</postoffice><country>FIN</country><device>10</device><algorithm>3</algorithm><paymentURL>https://payment.checkout.fi/p/11831869/AE6FCD73-664C869D-FAF1F697-3E89389B</paymentURL><merchant><id>375917</id><company>Testi Oy</company><name>Markkinointinimi</name><email>testi@checkout.fi</email><address>Testikuja 1&#13;12345 Testilä</address><vatId>123456-7</vatId><helpdeskNumber>012-345 678</helpdeskNumber></merchant><payments><payment><id>12369665</id><amount>200</amount><stamp>1389270899</stamp><banks><sampo url="https://verkkopankki.danskebank.fi/SP/vemaha/VemahaApp" icon="https://payment.checkout.fi/static/img/danskebank.png" name="Danske Bank"><SUMMA>2.00</SUMMA><VIITE>123696650</VIITE><KNRO>000000000000</KNRO><VALUUTTA>EUR</VALUUTTA><VERSIO>3</VERSIO><OKURL>https://payment.checkout.fi/07mhA0Uybd/fi/confirm?ORDER=11831869&amp;ORDERMAC=A33F99E42E465A8D598BD8FD46F71CAE</OKURL><VIRHEURL>https://payment.checkout.fi/07mhA0Uybd/fi/back</VIRHEURL><TARKISTE>4031b379fb6f26df277fc64d77baa42d9d96844040275544c15364b6ec46c36b</TARKISTE><ERAPAIVA>09.01.2014</ERAPAIVA><ALG/><lng>1</lng></sampo></banks></payment></payments></trade>'
  end
end
