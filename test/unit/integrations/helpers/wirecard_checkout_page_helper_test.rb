require 'test_helper'

class WirecardCheckoutPageHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @options = fixtures(:wirecard_checkout_page)
    @helper = WirecardCheckoutPage::Helper.new('13', 'D200001', @options)

    @helper.max_retries = 3
    @helper.auto_deposit = true
    @helper.add_version('Some Shopsystem', '0.0.1')

    @helper.language 'de'
    @helper.description 'Order Number 13'
    @helper.shop_service_url 'http://www.example.com/imprint'
    @helper.notify_url "https://www.example.com/payment/confirm"
    @helper.return_url "http://www.example.com/payment/return"
    @helper.cancel_return_url "http://www.example.com/payment/return"
    @helper.pending_url "http://www.example.com/payment/return"
    @helper.failure_url "http://www.example.com/payment/return"
  end

  def test_basic_helper_fields
    assert_field 'language', 'de'
    assert_field 'orderDescription', 'Order Number 13'
    assert_field 'serviceUrl', 'http://www.example.com/imprint'
    assert_field 'autoDeposit', "true"
    assert_field 'confirmUrl', "https://www.example.com/payment/confirm"
    assert_field 'successUrl', "http://www.example.com/payment/return"
    assert_field 'cancelUrl', "http://www.example.com/payment/return"
    assert_field 'pendingUrl', "http://www.example.com/payment/return"
    assert_field 'failureUrl', "http://www.example.com/payment/return"
    assert_field 'maxRetries', "3"
    assert @helper.secret == 'B8AKTPWBRMNBV455FG6M2DANE99WU2'
    assert @helper.customer_id == 'D200001'
    assert @helper.shop_id == ''
  end
  
  def test_customer_fields
    @helper.customer :first_name => 'Sepp',
                     :last_name => 'Maier',
                     :ipaddress => '127.0.0.1',
                     :user_agent => 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:24.0) Gecko/20100101 Firefox/24.0',
                     :email => 'foo@bar.com'

    assert_field 'consumerBillingFirstName', 'Sepp'
    assert_field 'consumerBillingLastName', 'Maier'
    assert_field 'consumerIpAddress', '127.0.0.1'
    assert_field 'consumerUserAgent', 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:24.0) Gecko/20100101 Firefox/24.0'
    assert_field 'consumerEmail', 'foo@bar.com'
  end

  def test_address_mapping
    @helper.billing_address(:address1 => 'Daham 99',
                            :zip => '8010',
                            :city => 'Graz',
                            :state => 'Steiermark',
                            :country => 'Austria')

    assert_field 'consumerBillingAddress1', 'Daham 99'
    assert_field 'consumerBillingZipCode', '8010'
    assert_field 'consumerBillingCity', 'Graz'
    assert_field 'consumerBillingState', 'Steiermark'
    assert_field 'consumerBillingCountry', 'AT'

    @helper.shipping_address(:first_name => 'Arnold',
                             :last_name => 'Schwarzenegger',
                             :address1 => 'Broadway 128',
                             :city => 'Los Angeles',
                             :state => 'NY',
                             :country => 'USA',
                             :zip => '10890',
                             :phone => '192634520',
                             :fax => '1926345202')

    assert_field 'consumerShippingFirstName', 'Arnold'
    assert_field 'consumerShippingLastName', 'Schwarzenegger'
    assert_field 'consumerShippingAddress1', 'Broadway 128'
    assert_field 'consumerShippingZipCode', '10890'
    assert_field 'consumerShippingCity', 'Los Angeles'
    assert_field 'consumerShippingState', 'NY'
    assert_field 'consumerShippingCountry', 'US'
    assert_field 'consumerShippingPhone', '192634520'
    assert_field 'consumerShippingFax', '1926345202'

  end

end
