# encoding: utf-8
require 'test_helper'
class RemoteCloudpaymentsTest < Test::Unit::TestCase

  def setup
    @gateway = CloudpaymentsGateway.new(fixtures(:cloudpayments))

    @currency = 'RUB'
    @token = "477bba133c182267fe5f086924abdc5db71f77bfc27f01f2843f2cdc69d89f05"
    @cryptogram = "014242424242201202arDlcyJxkV8PTPKbj0zd0R70/plKHDETIIWGAPqedKYF4lqj7b7LUfDqfd6FWiRREJhec7LdniRRoiwruMGK5jg0zRvqzuu9DmoBBF6P/VPJ4jtrMFxdVjvsXjmPa81zKCAfgL7g+2IOKg544KxPSisyRoqaTU91zzkHNj/wv9e/HS3QVGV9y7CfjKq0H0p6tHwkqRjU/LLOKhD7ZFjHxPKM1P5Gv4+DIu4lT3S5KX7FKSq8bsN/cCg+28fjVBCJPKZV42sOsiMi9wTFJttzNCK3odRxKgj914QKLk6t9YSi9uwU4QqUEOW1P3saG6FLuHgvfQofyyGVPxmTbrdwuQ=="

    @declined_cryptogram = "015105105100201202ZykNAeKBC+UkfOewUsIAQqIg6WUi1WFrx4NABLIAnMVb1DeMWTM9LPiIhTr5L5sIIpPwUe/L+KPeLVkQ/76skIrc/jqr6hDLB4FfoInA6OW2Y3xPtVlqX6uxwVTKHentY1I/trkUmfFY8UtR82DkHvBX99A0JKHnqqRrGHQ0lWK7SIK40GJukmFW2RrKT73/vPYm0CPe1a0/vXJchv9i3vRSovUVnpIdrx08jpLXnHj/dAqmWDNIGZOQIfPk4WO0b00VlR1/+Li6hQY9XsmyqROQcbKDvMJAIPYOCsi8a2cRa0sDmhHbcR1cbiNVOraR7W72qv3JFRL4MCvrgaauiQ=="

    @amount = 100

    @options = {
      :Currency => @currency,
      :Description => 'ActiveMerchant Test Purchase',
      :AccountId => 'wow@example.com',
      :Name => "ALEX",
      :IpAddreess => '127.0.0.1'
    }
    @subscription_options = {
      :AccountId => '1@1.com',
      :Description => "Subscription lpcloudapp.com",
      :Email => '1@1.com',
      :Currency => 'RUB',
      :RequireConfirmation => false,
      :StartDate => Time.now.utc.iso8601,
      :Interval => 'Month',
      :Period => 1
    }
  end

  def test_authorization_with_cryptogram
    assert authorization = @gateway.authorize(@cryptogram, @amount, @options)
    assert_success authorization
    assert_equal @amount.to_i, authorization.params["Amount"].to_i
  end

  def test_authorization_with_token
    assert authorization = @gateway.authorize(@token, @amount, @options, true)
    assert_success authorization
    assert_equal @amount.to_i, authorization.params["Amount"].to_i
  end

  def test_charge_with_cryptogram
    assert authorization = @gateway.purchase(@cryptogram, @amount, @options)
    assert_success authorization
    assert_equal @amount.to_i, authorization.params["Amount"].to_i
  end

  def test_charge_with_token
    assert authorization = @gateway.purchase(@token, @amount, @options, true)
    assert_success authorization
    assert_equal @amount.to_i, authorization.params["Amount"].to_i
  end

  def test_unsuccessful_charge_with_token
    assert response = @gateway.purchase(@declined_cryptogram, @amount, @options)
    assert_failure response
    assert_equal 'Declined', response.params['Status']
  end

  def test_successful_void
    assert response = @gateway.purchase(@cryptogram, @amount, @options)
    assert_success response
    assert void = @gateway.void(response.authorization)
    assert_success void
  end

  def test_unsuccessful_void
    assert void = @gateway.void("active_merchant_fake_charge")
    assert_failure void
    assert_match %r{active_merchant_fake_charge}, void.message
  end

  def test_successful_subscription
    assert response = @gateway.subscribe(@token, @amount, @subscription_options)
    assert_success response
    assert response.params['Id']
    assert_equal 'Active', response.params["Status"]
    assert_equal @amount, response.params["Amount"].to_i
  end
  def test_successful_void_subscription
    assert response = @gateway.subscribe(@token, @amount, @subscription_options)
    assert_success response
    assert void = @gateway.void_subscription(response.authorization)
    assert_success void
  end
end
