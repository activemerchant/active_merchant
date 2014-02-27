require 'test_helper'

class DengionlineHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Dengionline::Helper.new(123, 6666, :amount => 120, :currency => 'USD', :nickname => 'user', :secret => 'secret', :transaction_type => 1)
  end

  def test_basic_helper_fields
    assert_field 'project', '6666'
    assert_field 'mode_type', '1'
    assert_field 'amount', '120'
    assert_field 'nickname', 'user'
    assert_field 'order_id', '123'
  end

  def test_validate
    assert_valid @helper
  end
  
  def test_mobile_mode
    @helper = Dengionline::Helper.new(123, 6666, {
      :amount => '120.00',
      :nickname => 'User',
      :transaction_type => 1,
      :method => :mobile,
      :mode => :background,
      :secret => 'secret',
      :mobile_user_id => '1234567890'
    })
    
    assert_valid @helper
    assert @helper.mobile?
    
    assert_field 'mode_type', Dengionline::Helper::MOBILE_PAYMENT_VALUE
    assert_field 'sendMobilePayment', '1'
    assert_field 'md5', '0eee24acf3da54f0dfc6d8d71ab3437a' # Digest::MD5.hexdigest "secret6666user1201234567890secret"
  end
  
end
