require 'test_helper'

class FasapayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @fasapay = Fasapay::Notification.new(https_raw_data, :secret => 'myKey')
  end

  def test_respond_to_acknowledge
    assert @fasapay.respond_to?(:acknowledge)
  end

  def test_https_acknowledgement
    assert @fasapay.acknowledge
  end

  def test_accessors
    assert_equal 'FP0022', @fasapay.account
    assert_equal 'FP0023', @fasapay.payer
    assert_equal '100', @fasapay.amount
    assert_equal '3', @fasapay.fee_amount
    assert_equal 'USD', @fasapay.currency
    assert_equal 'Apple', @fasapay.description
    assert_equal 'StoreName', @fasapay.account_name
    assert_equal '2010/11/10 12:22:55', @fasapay.received_at
    assert_equal '123', @fasapay.order_id
  end

  private

  def https_raw_data
    "fp_paidto=FP0022&\
fp_paidby=FP0023&\
fp_amnt=100&\
fp_fee_amnt=3&\
fp_currency=USD&\
fp_item=Apple&\
fp_store=StoreName&\
fp_timestamp=2010%2F11%2F10+12%3A22%3A55&\
fp_merchant_ref=123"
  end
end
