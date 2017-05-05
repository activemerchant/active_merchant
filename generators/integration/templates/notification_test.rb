require 'test_helper'

class <%= class_name %>NotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @<%= identifier %> = <%= class_name %>::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @<%= identifier %>.complete?
    assert_equal "", @<%= identifier %>.status
    assert_equal "", @<%= identifier %>.transaction_id
    assert_equal "", @<%= identifier %>.item_id
    assert_equal "", @<%= identifier %>.gross
    assert_equal "", @<%= identifier %>.currency
    assert_equal "", @<%= identifier %>.received_at
    assert @<%= identifier %>.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @<%= identifier %>.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement

  end

  def test_send_acknowledgement
  end

  def test_respond_to_acknowledge
    assert @<%= identifier %>.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    ""
  end
end
