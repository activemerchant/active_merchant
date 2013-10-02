require 'test_helper'

class BitPayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @bit_pay = BitPay::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @bit_pay.complete?
    assert_equal "complete", @bit_pay.status
    assert_equal "w1GRw1q86WPSUlT1r2cGsCZffrUM-KqT9fMFnbC9jo=", @bit_pay.transaction_id
    assert_equal 0.0083, @bit_pay.btcPrice
    assert_equal "USD", @bit_pay.currency
    assert_equal 1370539476654, @bit_pay.received_at
  end

  def test_compositions
    assert_equal "1", @bit_pay.amount
  end

  def test_acknowledgement
    assert @bit_pay.acknowledge('foobar')
  end

  private
  def http_raw_data
    "id=w1GRw1q86WPSUlT1r2cGsCZffrUM-KqT9fMFnbC9jo=&orderID=123&url=https://bitpay.com/invoice/w1GRw1q86WPSUlT1r2cGsCZffrUM-KqT9fMFnbC9jo=&status=complete&btcPrice=0.0083&price=1&currency=USD&invoiceTime=1370539476654&expirationTime=1370540376654&currentTime=1370539573956&posData=foobar"
  end
end
