require 'test_helper'

class DotpayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Dotpay::Helper.new('order-500', '42655', :amount => 500)
    @url = 'http://someuri.com/return.html'
  end
 
  def test_basic_helper_fields
    assert_field 'id', '42655'
    assert_field 'lang', 'PL'
    assert_field 'description', 'order-500'
    assert_field 'currency', 'PLN'
  end
  
  def test_customer_fields
    @helper.customer :firstname => 'Przemyslaw', :lastname => 'Ciacka', :email => 'przemek@example.com'
    assert_field 'firstname', 'Przemyslaw'
    assert_field 'lastname', 'Ciacka'
    assert_field 'email', 'przemek@example.com'
  end

  def test_address_mapping
    @helper.billing_address :street => 'Malborska',
                            :street_n1 => '130',
                            :city => 'Cracow',
                            :postcode => '30-624'
   
    assert_field 'street', 'Malborska'
    assert_field 'street_n1', '130'
    assert_field 'city', 'Cracow'
    assert_field 'postcode', '30-624'
    assert_field 'country', 'POL'
  end

  def test_description
    @helper.description = 'Order 500/2012'
    assert_field 'description', 'Order 500/2012'
  end

  def test_channel
    assert_field 'channel', '0'
    @helper.channel = '2'
    assert_field 'channel', '2'
  end

  def test_ch_lock
    assert_field 'ch_lock', '0'
    @helper.ch_lock = '1'
    assert_field 'ch_lock', '1'
  end

  def test_onlinetransfer
    assert_field 'onlinetransfer', '0'
    @helper.onlinetransfer = 1
    assert_field 'onlinetransfer', '1'
  end

  def test_url
    @helper.url = @url
    assert_field 'url', @url
  end

  def test_urlc
    @helper.urlc = @url
    assert_field 'urlc', @url
  end

  def test_type
    assert_field 'type', '2'
    @helper.type = '3'
    assert_field 'type', '3'
  end

  def test_buttontext
    @helper.buttontext = 'Return to the shop'
    assert_field 'buttontext', 'Return to the shop'
  end

  def test_control
    @helper.control = 'ThisISSOMEControlP@rameter'
    assert_field 'control', 'ThisISSOMEControlP@rameter'
  end

  def test_code
    @helper.code = 'somecode'
    assert_field 'code', 'somecode'
  end

  def test_p_info
    @helper.p_info = 'Company Name'
    assert_field 'p_info', 'Company Name'
  end

  def test_p_email
    @helper.p_email = 'company@email.com'
    assert_field 'p_email', 'company@email.com'
  end

  def test_tax
    assert_field 'tax', '0'
    @helper.tax = '1'
    assert_field 'tax', '1'
  end
end
