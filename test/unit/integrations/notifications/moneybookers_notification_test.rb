require 'test_helper'

class MoneybookersNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @moneybookers = Moneybookers::Notification.new(http_raw_data, :credential2 => 'secret')
  end

  def test_accessors
    assert @moneybookers.complete?
    assert_equal 'Completed', @moneybookers.status
    assert_equal "200234", @moneybookers.transaction_id
    assert_equal "1005", @moneybookers.item_id
    assert_equal '39.60', @moneybookers.gross
    assert_equal 'EUR', @moneybookers.currency    
    assert_equal "25.46", @moneybookers.merchant_amount
    assert_equal "GBP", @moneybookers.merchant_currency
    assert_equal nil, @moneybookers.received_at
  end

  def test_compositions
    assert_equal Money.new(3960, 'EUR'), @moneybookers.amount
  end
  
  def test_respond_to_acknowledge
    assert @moneybookers.respond_to?(:acknowledge)
  end
  
  def test_status_failed
    notification = Moneybookers::Notification.new(http_raw_data.sub(/status=2/, 'status=-2'), :credential2 => 'secret')
    assert_equal 'Failed', notification.status
  end
  
  def test_status_pending
    notification = Moneybookers::Notification.new(http_raw_data.sub(/status=2/, 'status=0'), :credential2 => 'secret')
    assert_equal 'Pending', notification.status    
  end
  
  def test_status_cancelled
    notification = Moneybookers::Notification.new(http_raw_data.sub(/status=2/, 'status=-1'), :credential2 => 'secret')
    assert_equal 'Cancelled', notification.status    
  end
  
  def test_status_reversed
    notification = Moneybookers::Notification.new(http_raw_data.sub(/status=2/, 'status=-3'), :credential2 => 'secret')
    assert_equal 'Reversed', notification.status
  end
  
  def test_status_error
    notification = Moneybookers::Notification.new(http_raw_data.sub(/status=2/, 'status='), :credential2 => 'secret')
    assert_equal 'Error', notification.status
  end
  
  def test_acknowledge
    data = {"md5sig"=>"CDEA3910DDD4090DF89034CA82C46D34", "transaction_id"=>"54910248", "amount"=>"1.03", "id"=>"968", "pay_to_email"=>"dennis@shopify.com", "mb_currency"=>"EUR", "currency"=>"USD", "mb_transaction_id"=>"403117232", "mb_amount"=>"0.735741", "merchant_id"=>"21235995", "status"=>"2", "pay_from_email"=>"dennis@shopify.com", "payment_type"=>"MBD"}
    data = data.collect{|key, value| "#{key}=#{value}"}.join('&')
    notification = Moneybookers::Notification.new(data, :credential2 => 't3stt3st')
    assert notification.acknowledge
  end
  
  private
  def http_raw_data
    "pay_to_email=merchant@merchant.com&pay_from_email=payer@moneybookers.com&merchant_id=100005&mb_transaction_id=200234&transaction_id=1005&mb_amount=25.46&mb_currency=GBP&status=2&md5sig=327638C253A4637199CEBA6642371F20&amount=39.60&currency=EUR"
  end  
end
