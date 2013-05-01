# Dwolla ActiveMerchant Integration
# http://www.dwolla.com/
# Authors: Michael Schonfeld <michael@dwolla.com>, Gordon Zheng <gordon@dwolla.com>
# Date: May 1, 2013

require 'test_helper'

class DwollaReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @failed_callback_dwolla = Dwolla::Return.new(http_raw_data_failed_callback, {:credential3 => 'mysecret'})
    @dwolla = Dwolla::Return.new(http_raw_data_success, {:credential3 => 'mysecret'})
  end

  def test_failed_callback_return
    assert_false @failed_callback_dwolla.success?
  end

  def test_failed_callback_accessors
    assert_equal "f32b1e55-9612-4b6d-90f9-1c1519e588da", @failed_callback_dwolla.checkout_id
    assert_equal "1312616", @failed_callback_dwolla.transaction
    assert @failed_callback_dwolla.test?
  end

  def test_success_return
    assert @dwolla.success?
  end

  def test_success_accessors
    assert_equal "f32b1e55-9612-4b6d-90f9-1c1519e588da", @dwolla.checkout_id
    assert_equal "1312616", @dwolla.transaction
    assert @dwolla.test?
  end
  
  private
  def http_raw_data_success
    "signature=098d3f32654bd8eebc9db323228879fa2ea12459&test=true&orderId=&amount=0.01&checkoutId=f32b1e55-9612-4b6d-90f9-1c1519e588da&status=Completed&clearingDate=8/28/2012%203:17:18%20PM&transaction=1312616&postback=success"
  end

  def http_raw_data_failed_callback
    "signature=098d3f32654bd8eebc9db323228879fa2ea12459&test=true&orderId=&amount=0.01&checkoutId=f32b1e55-9612-4b6d-90f9-1c1519e588da&status=Completed&clearingDate=8/28/2012%203:17:18%20PM&transaction=1312616&postback=failure"
  end
end