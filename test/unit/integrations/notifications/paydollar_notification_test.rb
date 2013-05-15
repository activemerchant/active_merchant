require 'test_helper'

class PaydollarNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @payment_status = "PAID"
    @paydollar = Paydollar::Notification.new(http_raw_data)
    #@paydollar.set_payment_status(@payment_status)
  end

  def test_accessors
    assert_equal @payment_status, @paydollar.status
    assert_equal "000000000014", @paydollar.item_id
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement
    assert @paydollar.acknowledge("000000000014")
  end

  private
  def http_raw_data
    "Ref=000000000014"
  end
end
