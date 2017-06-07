require 'test_helper'

class WebPay3ReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_cancelled_return
    assert WebPay3::Return.new(http_raw_data_when_cancelled, key: fixtures(:web_pay3)[:key]).cancelled?
  end

  def test_success_return
    assert WebPay3::Return.new(http_raw_data_when_success, key: fixtures(:web_pay3)[:key]).success?
  end

  private

  def http_raw_data_when_cancelled
    'language=en&order_number=123aaa'
  end

  def http_raw_data_when_success
    'approval_code=478025&authentication=&cc_type=visa&currency=USD&custom_params=&digest=e836e56140875ad25b3485efaa19e0cd6d9687e7&enrollment=N&language=en&order_number=123aaa&response_code=0000'
  end

end
