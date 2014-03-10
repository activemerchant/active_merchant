require 'test_helper'

class RedDotPaymentNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @successful_payment = RedDotPayment::Notification.new(successful_query_string, { account: 'merchant1', credential3: 'REDDOT'})
    @failed_ack = RedDotPayment::Notification.new(failed_query_string, { account: 'merchant1', credential3: 'REDDOT'})
  end

  def test_complete?
    assert @successful_payment.complete?
  end

  def test_gross
    assert_equal "9.50", @successful_payment.gross
  end

  def test_currency
    assert_equal "SGD", @successful_payment.currency
  end

  def test_transaction_id
    assert_equal "3711184054", @successful_payment.transaction_id
  end

  def test_accessors
    assert_equal "Paid", @successful_payment.status
    assert_equal "12345", @successful_payment.item_id
    assert_equal nil, @successful_payment.received_at
    assert !@successful_payment.test?
  end

  def test_compositions
    assert_equal Money.new(950, 'SGD'), @successful_payment.amount
  end

  def test_acknowledgement
    assert @successful_payment.acknowledge
    assert !@failed_ack.acknowledge
  end

  def test_respond_to_acknowledge
    assert @successful_payment.respond_to?(:acknowledge)
  end

  private
  def successful_query_string
    "order_number=12345&result=Paid&confirmation_code=6ACB2926&transaction_id=3711184054&authorization_code=123456&signature=46cd72ad8a0f374d1bf31190cc78ff52&amount=9.50&currency_code=SGD"
  end

  def failed_query_string
    "order_number=614411&result=Rejected&error_code=8&signature=12341"
  end
end
