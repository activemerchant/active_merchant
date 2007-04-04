require File.dirname(__FILE__) + '/../../../test_helper'

class <%= class_name %>NotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @<%= file_name %> = <%= class_name %>::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @<%= file_name %>.complete?
    assert_equal "", @<%= file_name %>.status
    assert_equal "", @<%= file_name %>.transaction_id
    assert_equal "", @<%= file_name %>.item_id
    assert_equal "", @<%= file_name %>.gross
    assert_equal "", @<%= file_name %>.currency
    assert_equal "", @<%= file_name %>.received_at
    assert @<%= file_name %>.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @<%= file_name %>.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement    

  end

  def test_send_acknowledgement
  end

  def test_respond_to_acknowledge
    assert @<%= file_name %>.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    ""
  end  
end
