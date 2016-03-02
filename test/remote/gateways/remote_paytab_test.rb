require 'test_helper'

class RemotePaytabTest < Test::Unit::TestCase
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
    response = @gateway.purchase(@amount, @options)
    assert_success response
    assert_equal 'Payment Success', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @options)
    assert_failure response
    assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(nil, '')
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(nil, purchase.authorization)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{REPLACE WITH SUCCESS MESSAGE}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{REPLACE WITH FAILED PURCHASE MESSAGE}, response.message
  end

  def test_invalid_login
    gateway = PaytabGateway.new(
      login: '',
      password: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
