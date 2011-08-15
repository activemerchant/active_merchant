require 'test_helper'

class DwollaNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @dwolla = Dwolla::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @dwolla.complete?
    assert_equal "", @dwolla.status
    assert_equal "", @dwolla.transaction_id
    assert_equal "", @dwolla.item_id
    assert_equal "", @dwolla.gross
    assert_equal "", @dwolla.currency
    assert_equal "", @dwolla.received_at
    assert @dwolla.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @dwolla.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement    

  end

  def test_send_acknowledgement
  end

  def test_respond_to_acknowledge
    assert @dwolla.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    ""
  end  
end
