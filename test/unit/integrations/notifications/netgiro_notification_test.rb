require 'test_helper'

class NetgiroNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @netgiro = Netgiro::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @netgiro.complete?
    assert @netgiro.acknowledge
    assert_equal "Completed", @netgiro.status
    assert_equal "982as34-1ss23123-4asd12", @netgiro.transaction_id
    assert_equal "WEB-123", @netgiro.item_id
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement
    valid = Netgiro.notification(http_raw_data, :credential2 => 'password')
    assert valid.acknowledge
    assert valid.success?
    assert valid.complete?
    
    invalid = Netgiro.notification(http_raw_data, :credential2 => 'bogus')
    assert !invalid.acknowledge
    assert !invalid.success?
    assert !invalid.complete?
 end

  def test_respond_to_acknowledge
    assert @netgiro.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    "orderid=WEB-123&confirmationCode=982as34-1ss23123-4asd12&invoiceNumber=1234&signature=638980f3aa70e8c081e118f57269ebea123ee9ebef457ffa0a604957b33a78ca"
  end
end