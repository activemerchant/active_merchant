require 'test_helper'

class DengionlineNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @dengionline = Dengionline::Notification.new(http_raw_data, :secret => 'secret')
  end

  def test_accessors
    assert_equal "500", @dengionline.gross
    assert_equal "user", @dengionline.nickname
    assert_equal "11123", @dengionline.payment_id
  end

  def test_compositions
    assert_equal Money.new(50000, 'USD'), @dengionline.amount
  end

  def test_acknowledgement
    assert @dengionline.acknowledged?
  end

  def test_wrong_signature
    @dengionline = Dengionline::Notification.new(http_raw_data_with_wrong_signature, :secret => 'secret')
    assert_false @dengionline.acknowledged?
  end

  private
  def http_raw_data
    # key = Digest::MD5.hexdigest "500user11123secret"
    "amount=500&userid=user&paymentid=11123&key=63a61ae68129aeb03a832458cc23e891"
  end

  def http_raw_data_with_wrong_signature
    "amount=500&userid=user&paymentid=11123&key=wrong"
  end
end
