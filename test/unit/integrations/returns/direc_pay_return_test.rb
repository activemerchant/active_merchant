require 'test_helper'

class DirecPayReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_success
    direc_pay = DirecPay::Return.new(http_raw_data_success)
    assert direc_pay.success?
    assert_equal 'Completed', direc_pay.message
  end

  def test_failure_is_successful
    direc_pay = DirecPay::Return.new(http_raw_data_failure)
    assert direc_pay.success?
    assert_equal 'Pending', direc_pay.message
  end

  def test_treat_initial_failures_as_pending
    direc_pay = DirecPay::Return.new(http_raw_data_failure)
    assert_equal 'Pending', direc_pay.notification.status
  end

  def test_return_has_notification
    direc_pay = DirecPay::Return.new(http_raw_data_success)
    notification = direc_pay.notification

    assert_equal '1001010000026481', direc_pay.notification.transaction_id
    assert notification.complete?
    assert_equal 'Completed', notification.status
    assert_equal '1001', notification.item_id
    assert_equal '1.00', notification.gross
    assert_equal 100, notification.gross_cents
    assert_equal Money.new(100, 'INR'), notification.amount
    assert_equal 'INR', notification.currency
    assert_equal 'IND', notification.country
    assert_equal 'NULL', notification.other_details
  end

  def test_treat_failed_return_as_complete
    direc_pay = DirecPay::Return.new(http_raw_data_failure)
    assert direc_pay.notification.complete?
  end

  private

  def http_raw_data_success
    "responseparams=1001010000026481|SUCCESS|IND|INR|NULL|1001|1.00|"
  end
  
  def http_raw_data_failure
    "responseparams=1001010000026516|FAIL|IND|INR|NULL|1001|1.00|"
  end
  
end
