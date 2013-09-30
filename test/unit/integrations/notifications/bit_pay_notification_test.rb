require 'test_helper'

class BitPayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @bit_pay = BitPay::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @bit_pay.complete?
    assert_equal "", @bit_pay.status
    assert_equal "", @bit_pay.transaction_id
    assert_equal "", @bit_pay.item_id
    assert_equal "", @bit_pay.gross
    assert_equal "", @bit_pay.currency
    assert_equal "", @bit_pay.received_at
    assert @bit_pay.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @bit_pay.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement

  end

  def test_send_acknowledgement
  end

  def test_respond_to_acknowledge
    assert @bit_pay.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    ""
  end
end
