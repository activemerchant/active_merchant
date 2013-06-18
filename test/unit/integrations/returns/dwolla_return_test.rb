require 'test_helper'

class DwollaReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @checkout_failed = Dwolla::Return.new(http_raw_data_failed_checkout, {:credential3 => '62hdv0jBjsBlD+0AmhVn9pQuULSC661AGo2SsksQTpqNUrff7Z'})
    @callback_failed = Dwolla::Return.new(http_raw_data_failed_callback, {:credential3 => '62hdv0jBjsBlD+0AmhVn9pQuULSC661AGo2SsksQTpqNUrff7Z'})
    @success = Dwolla::Return.new(http_raw_data_success, {:credential3 => '62hdv0jBjsBlD+0AmhVn9pQuULSC661AGo2SsksQTpqNUrff7Z'})
  end

  def test_success_return
    assert @success.success?
  end

  def test_success_accessors
    assert_equal "ac5b910a-7ec1-4b65-9f68-90449ed030f6", @success.checkout_id
    assert_equal "3165397", @success.transaction
    assert_false @success.test?
  end

  def test_failed_callback_return
    assert_false @callback_failed.success?
  end

  def test_failed_callback_accessors
    assert_equal "ac5b910a-7ec1-4b65-9f68-90449ed030f6", @callback_failed.checkout_id
    assert_equal "3165397", @callback_failed.transaction
    assert @callback_failed.test?
  end

  def test_checkout_failed_return
    assert_false @callback_failed.success?
  end

  def test_checkout_failed_accessors
    assert_equal "failure", @checkout_failed.error
    assert_equal "User Cancelled", @checkout_failed.error_description
  end

  private

  def http_raw_data_success
    "signature=7d4c5deaf9178faae7c437fd8693fc0b97b1b22b&orderId=abc123&amount=0.01&checkoutId=ac5b910a-7ec1-4b65-9f68-90449ed030f6&status=Completed&clearingDate=6/8/2013%208:07:41%20PM&transaction=3165397&postback=success"
  end

  def http_raw_data_failed_callback
    "signature=7d4c5deaf9178faae7c437fd8693fc0b97b1b22b&orderId=abc123&amount=0.01&checkoutId=ac5b910a-7ec1-4b65-9f68-90449ed030f6&status=Completed&clearingDate=6/8/2013%208:07:41%20PM&transaction=3165397&postback=failure&test=true"
  end

  def http_raw_data_failed_checkout
    "error=failure&error_description=User+Cancelled"
  end
end