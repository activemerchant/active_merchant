require 'test_helper'

class DokuNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @doku = Doku::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @doku.complete?
    assert_equal "Completed", @doku.status
    assert_equal "ORD12345", @doku.item_id
    assert_equal "165000", @doku.gross
    assert_equal "IDR", @doku.currency
  end

  private
  def http_raw_data
    "TRANSIDMERCHANT=ORD12345&AMOUNT=165000&RESULT=Success"
  end
end
