require 'test_helper'

class RbkmoneyNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @rbkmoney = Rbkmoney::Notification.new(https_raw_data, :secret => 'myKey')
  end

  def test_accessors
    assert @rbkmoney.complete?
    assert_equal 'completed', @rbkmoney.status
    assert_equal '100500', @rbkmoney.transaction_id
    assert_equal '1234', @rbkmoney.item_id
    assert_equal '12.30', @rbkmoney.gross
    assert_equal 'RUR', @rbkmoney.currency
    assert_equal '2007-10-28 14:22:35', @rbkmoney.received_at
    assert_false @rbkmoney.test?
  end

  def test_https_acknowledgement
    assert @rbkmoney.acknowledge
  end

  def test_respond_to_acknowledge
    assert @rbkmoney.respond_to?(:acknowledge)
  end

  def test_user_fields
    expected = {
      'userField_1' => 'user field 1'
      }
    assert_equal expected, @rbkmoney.user_fields
  end

  private

  def https_raw_data
    "eshopId=12&\
paymentId=100500&\
orderId=1234&\
eshopAccount=RU123456789&\
serviceName=Kniga&\
recipientAmount=12.30&\
recipientCurrency=RUR&\
paymentStatus=5&\
userName=Petrov%20Alexander&\
userEmail=admin@rbkmoney.ru&\
paymentData=2007-10-28%2014:22:35&\
secretKey=myKey&\
hash=8f4693792fe46de17a2c4d93b84910a6&\
userField_1=user%20field%201"
  end
end
