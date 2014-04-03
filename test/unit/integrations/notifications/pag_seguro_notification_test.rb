require 'test_helper'

class PagSeguroNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @pag_seguro = PagSeguro::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @pag_seguro.complete?
    assert_equal "", @pag_seguro.status
    assert_equal "", @pag_seguro.transaction_id
    assert_equal "", @pag_seguro.item_id
    assert_equal "", @pag_seguro.gross
    assert_equal "", @pag_seguro.currency
    assert_equal "", @pag_seguro.received_at
    assert @pag_seguro.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @pag_seguro.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement

  end

  def test_send_acknowledgement
  end

  def test_respond_to_acknowledge
    assert @pag_seguro.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    ""
  end
end
