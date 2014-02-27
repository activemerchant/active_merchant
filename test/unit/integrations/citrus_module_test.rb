require 'test_helper'

class CitrusModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    ActiveMerchant::Billing::Base.integration_mode = :test
    @access_key = 'G0JW45KCS3630NX335YX'
    @secret_key = '2c71a4ea7d2b88e151e60d9da38b2d4552568ba9'
    @pmt_url = 'gqwnliur74'

    @options = {
      :credential2 => @secret_key,
      :credential3 => @pmt_url
    }
  end

  def test_helper_method
    assert_instance_of Citrus::Helper, Citrus.helper('ORD01','G0JW45KCS3630NX335YX', @options.merge(:amount => 10.0, :currency => 'USD'))
  end

  def test_return_method
    assert_instance_of Citrus::Return, Citrus.return('name=foo', {})
  end

  def test_notification_method
    assert_instance_of Citrus::Notification, Citrus.notification('name=cody')
  end

  def test_checksum_method
    citrus_load = @pmt_url+"10"+"ORD123"+"USD"
    assert_equal "ecf7eaafec270b9b91b898e7f8e794c30245eb7f", Citrus.checksum(@secret_key, citrus_load)
  end
end
