require 'test_helper'

class BraintreeBlueTest < Test::Unit::TestCase

  def setup
    @gateway = BraintreeBlueGateway.new(
      :merchant_id => 'test',
      :public_key => 'test',
      :private_key => 'test'
    )
  end

  def test_refund_legacy_method_signature
    Braintree::Transaction.expects(:refund).with('transaction_id', nil).returns(Response.new(true, 'test', {}))
    @gateway.refund('transaction_id', :test => true)
  end

  def test_refund_method_signature
    Braintree::Transaction.expects(:refund).with('transaction_id', '10.00').returns(Response.new(true, 'test', {}))
    @gateway.refund(1000, 'transaction_id', :test => true)
  end
end
