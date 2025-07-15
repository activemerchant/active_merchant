require 'test_helper'

class QuickpayTest < Test::Unit::TestCase
  def test_error_without_login_option
    assert_raise ArgumentError do
      QuickpayGateway.new
    end
  end

  def test_v4to7
    gateway = QuickpayGateway.new(login: 50000000, password: 'secret')
    assert_instance_of QuickpayV4to7Gateway, gateway
  end

  def test_v10
    gateway = QuickpayGateway.new(login: 100, api_key: 'APIKEY')
    assert_instance_of QuickpayV10Gateway, gateway
  end

  def test_factory_returns_v4to7_gateway_with_correct_url_and_version
    gateway = QuickpayGateway.new(login: 50000000, password: 'secret')
    assert_instance_of ActiveMerchant::Billing::QuickpayV4to7Gateway, gateway
    assert_equal 'https://secure.quickpay.dk/api', gateway.class.test_url
    assert_equal 7, gateway.class.fetch_version  # Expect integer version
  end

  def test_factory_returns_v10_gateway_with_correct_url_and_version
    gateway = QuickpayGateway.new(login: 100, api_key: 'APIKEY')
    assert_instance_of ActiveMerchant::Billing::QuickpayV10Gateway, gateway
    assert_equal 'https://api.quickpay.net', gateway.class.test_url
    assert_equal 10, gateway.class.fetch_version  # Expect integer version
  end
end
