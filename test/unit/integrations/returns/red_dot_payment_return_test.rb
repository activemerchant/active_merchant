require 'test_helper'

class RedDotPaymentReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @return = RedDotPayment::Return.new(successful_query_string, { account: 'merchant1', credential3: 'REDDOT'})
  end

  def test_initializer
    assert_raise(StandardError) { RedDotPayment::Return.new('order_number=1234') }
    assert_raise(StandardError) { RedDotPayment::Return.new('name=cody', { account: 'merchant1', credential2: '123456'}) }
    assert_nothing_raised { RedDotPayment::Return.new('order_number=1234', { account: 'merchant1', credential3: '123456'}) }
  end

  def test_success?
    @return.notification.expects(:acknowledge).returns(true)
    @return.notification.expects(:status).returns('Paid')
    assert @return.success?

    @return.notification.expects(:status).returns('Rejected')
    assert !@return.success?
  end

  private
  def successful_query_string
    "order_number=12345&result=Paid&confirmation_code=6ACB2926&transaction_id=3711184054&authorization_code=123456&signature=46cd72ad8a0f374d1bf31190cc78ff52&amount=9.50&currency_code=SGD"
  end
end
