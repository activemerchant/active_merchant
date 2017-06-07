require 'test_helper'

class WebPay3ModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of WebPay3::Helper, WebPay3.helper('order', 'merchant', {})
  end

  def test_return_method
    assert_instance_of WebPay3::Return, WebPay3.return('http_raw_data', {})
  end

  def test_server_urls
    assert WebPay3.test_url, 'https://ipgtest.webteh.hr/form'
    assert WebPay3.development_url, 'https://ipgtest.webteh.hr/form'
    assert WebPay3.production_url, 'https://ipg.webteh.hr/form'
  end
end
