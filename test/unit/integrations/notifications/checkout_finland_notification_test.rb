require 'test_helper'

class CheckoutFinlandNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @checkout_finland = CheckoutFinland::Notification.new(http_params)
  end

  def test_accessors
    assert_equal false, @checkout_finland.complete? # http_params return data for a delayed payment that is not complete
    assert_equal "3", @checkout_finland.status
    assert_equal "12288575", @checkout_finland.transaction_id
    assert_equal "474738238", @checkout_finland.reference
    assert_equal "2657BA96CC7879C79192547EB6C9D4082EA39CA52FE1DAD09CB1C632ECFDAE67", @checkout_finland.mac
    assert @checkout_finland.delayed?
    assert_equal false, @checkout_finland.activation?
    assert_equal false, @checkout_finland.cancelled?
  end

  def test_acknowledgement
    assert @checkout_finland.acknowledge("SAIPPUAKAUPPIAS")
  end

  def test_faulty_acknowledgement
    # Same data different (invalid) authcode
    assert_equal false, @checkout_finland.acknowledge("LOREMIPSUM")
  end

  private
  def http_params
    {"VERSION" => "0001", "STAMP" => "1388998411", "REFERENCE" => "474738238", "PAYMENT" => "12288575", "STATUS" => "3", "ALGORITHM" => "3", "MAC" =>"2657BA96CC7879C79192547EB6C9D4082EA39CA52FE1DAD09CB1C632ECFDAE67"}
  end
end
