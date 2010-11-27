require 'test_helper'

class AdyenNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @adyen = Adyen::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @adyen.complete?
    assert_equal "true", @adyen.status
    assert_equal "8512555599453931", @adyen.transaction_id
    assert_equal "10", @adyen.item_id
    assert_equal "1000", @adyen.gross
    assert_equal "USD", @adyen.currency
    assert_equal "2009-10-14T22%3A39%3A05.40Z", @adyen.received_at
    assert @adyen.test?
  end

  private
  def http_raw_data
    "eventDate=2009-10-14T22%3A39%3A05.40Z&reason=22295%3A1111%3A12%2F2012&originalReference=&merchantReference=10&currency=USD&pspReference=8512555599453931&merchantAccountCode=RazWar&eventCode=AUTHORISATION&value=1000&operations=CANCEL%2CCAPTURE%2CREFUND&success=true&paymentMethod=visa&live=false"
  end  
end
