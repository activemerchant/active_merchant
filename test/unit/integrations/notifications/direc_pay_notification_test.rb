require 'test_helper'

class DirecPayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @direc_pay = DirecPay::Notification.new(http_raw_data_success)
  end

  def test_success
    assert @direc_pay.complete?
    assert_equal "Completed", @direc_pay.status
    assert_equal "1001010000026481", @direc_pay.transaction_id
    assert_equal "1001", @direc_pay.item_id
    assert_equal "1.00", @direc_pay.gross
    assert_equal "INR", @direc_pay.currency
    assert_equal "IND", @direc_pay.country
  end

  def test_failure
    @direc_pay = DirecPay::Notification.new(http_raw_data_failure)
    assert !@direc_pay.complete?
    assert_equal "Failed", @direc_pay.status
    assert_equal "1001010000026516", @direc_pay.transaction_id
    assert_equal "1001", @direc_pay.item_id
    assert_equal "1.00", @direc_pay.gross
    assert_equal "INR", @direc_pay.currency
    assert_equal "IND", @direc_pay.country
    assert @direc_pay.acknowledge
  end
  
  def test_error
    @direc_pay = DirecPay::Notification.new(http_raw_data_error)
    assert !@direc_pay.complete?
    assert_equal "Error", @direc_pay.status
    assert_equal "1001010000026516", @direc_pay.transaction_id
  end
  
  def test_compositions
    assert_equal Money.new(100, 'INR'), @direc_pay.amount
  end

  def test_acknowledgement
    assert @direc_pay.acknowledge
  end

  def test_respond_to_acknowledge
    assert @direc_pay.respond_to?(:acknowledge)
  end


  private

  def http_raw_data_success
    "responseparams=1001010000026481|SUCCESS|IND|INR|1|1001|1.00|"
  end
  
  def http_raw_data_failure
    "responseparams=1001010000026516|FAIL|IND|INR|1|1001|1.00|"
  end
  
  def http_raw_data_pending
    "responseparams=1001010000026516|PENDING|IND|INR|1|1001|1|"
  end
  
  def http_raw_data_error
    "responseparams=1001010000026516|ERROR|Record not found for this transaction reference number"
  end  
end
