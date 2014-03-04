require 'test_helper'

class KlarnaModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Klarna::Notification, Klarna.notification('name=cody')
  end

  def test_merchant_digest_fields
    fields = {}
    secret = 'Example secret'
    cart_items = [{'type' => 'physical',
                   'reference' => '#001',
                   'quantity' => 1,
                   'unit_price' => Money.new(1.00),
                   'tax_rate' => 0}]

    assert_equal 'fbe93ded85c3fda77dbb0764ae8697a6700d0f4a04dba05fa6c4bdee0117741c', Klarna.sign(fields, cart_items, secret)
  end
end
