require 'test_helper'

class PlatronModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Platron::Notification, Platron.notification('name=cody')
  end

  def test_signature_string
    signature_string = Platron.generate_signature_string(
      {
        :amount => 200,
        :currency => 'USD',
        :description => 'payment description',
        :salt => 'salt',
        :merchant_id => 'test_account',
        :order_id => '123'
      },
      'payment.php',
      'secret'
    )
    assert_equal "payment.php;200;USD;payment description;test_account;123;salt;secret", signature_string
  end
end
