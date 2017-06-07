require 'test_helper'

class PaytabTest < Test::Unit::TestCase
  def setup
    @gateway = PaytabGateway.new(
 	merchant_id : 'nagrawal@hitaishin.com',
        merchant_email : 'nagrawal@hitaishin.com',
        merchant_password : 'Hitaishin15',       
    )

    @credit_card = credit_card
    @amount = 145

	@options = {
          :merchant_email => "nagrawal@hitaishin.com",
          :secret_key => "QI94KXCafZuKnoxVFOr1t7TTiYcuRMJHvSMgQoq5nVQKknGZc80FgUzyTM2LyMs4FfkvDLA0GqL0Or01z1HQWhoP3rACd3GSi0oV",
          :site_url => "www.hitaishin.com",
          :cc_first_name => "Prakash",
          :cc_last_name => "Sharma",
          :phone_number => "9993247972",
          :cc_phone_number => "00973",
          :billing_address => "Flat 11 Building 222",
          :city => "indore",
          :state => "MP",
          :postal_code => "12345",
          :country => "BHR",
          :email => "sbawaniya@hitaishin.com",
          :amount => "145.00",
          :discount => "0",
          :reference_no => "pay",
          :currency => "INR",
          :title => "Test payment",
          :ip_customer => "123.123.12.2",
          :ip_merchant => "11.11.22.22",
          :return_url => "http://127.0.0.1:3000/Response",
          :address_shipping => "Flat 11 Building 222",
          :state_shipping => "MP",
          :city_shipping => "indore",
          :postal_code_shipping  => "450002",
          :country_shipping  => "BHR",
          :quantity => " 1 || 1 || 1 ",
          :unit_price  => " 10 || 8 || 2 ",
          :products_per_title  => " IPhone || Samsung S5 || Samsung S4 ",
          :ChannelOfOperations => "test",
          :ProductCategory => "Mobile",
          :ProductName => " IPhone || Samsung S5 || Samsung S4 ",
          :ShippingMethod => "Post",
          :DeliveryType => "Quick",
          :CustomerId => "1",
          :msg_lang => "English",
          :other_charges => "125.00",
          :shipping_first_name => "John",
          :shipping_last_name =>"smith",
          :cms_with_version =>"Magento 0.1.9"
      }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @options)
    assert_success response

    assert_equal 'REPLACE', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @options)
    assert_failure response
  end

  def test_successful_authorize
  end

  def test_failed_authorize
  end

  def test_successful_capture
  end

  def test_failed_capture
  end

  def test_successful_refund
  end

  def test_failed_refund
  end

  def test_successful_void
  end

  def test_failed_void
  end

  def test_successful_verify
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
  end

  private

  def successful_purchase_response
    %(
      Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      to "true" when running remote tests:

      $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
        test/remote/gateways/remote_paytab_test.rb \
        -n test_successful_purchase
    )
  end

  def failed_purchase_response
  end

  def successful_authorize_response
  end

  def failed_authorize_response
  end

  def successful_capture_response
  end

  def failed_capture_response
  end

  def successful_refund_response
  end

  def failed_refund_response
  end

  def successful_void_response
  end

  def failed_void_response
  end
end
