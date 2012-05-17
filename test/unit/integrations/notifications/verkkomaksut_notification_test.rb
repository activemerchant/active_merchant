require 'test_helper'

class VerkkomaksutNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @verkkomaksut = Verkkomaksut::Notification.new(http_params)
  end

  def test_accessors
    assert @verkkomaksut.complete?
    assert_equal "PAID", @verkkomaksut.status
    assert_equal "2", @verkkomaksut.order_id
    assert_equal "1336058061", @verkkomaksut.received_at
    assert_equal "4", @verkkomaksut.method
    assert_equal "6B40F9B939D03EFE7573D61708FA4126", @verkkomaksut.security_key
  end

  
  def test_acknowledgement
    assert @verkkomaksut.acknowledge("6pKF4jkv97zmqBJ3ZL8gUw5DfT2NMQ")
  end
  
  def test_faulty_acknowledgement
    @verkkomaksut = Verkkomaksut::Notification.new({"ORDER_NUMBER"=>"2", "TIMESTAMP"=>"1336058061", "PAID"=>"3DF5BB7E26", "METHOD"=>"4", "RETURN_AUTHCODE"=>"6asd0F9B939D03EFE7573D61708FA4126"})
    assert_equal false, @verkkomaksut.acknowledge("6pKF4jkv97zmqBJ3ZL8gUw5DfT2NMQ")
  end

  private
  def http_params
    {"ORDER_NUMBER"=>"2", "TIMESTAMP"=>"1336058061", "PAID"=>"3DF5BB7E26", "METHOD"=>"4", "RETURN_AUTHCODE"=>"6B40F9B939D03EFE7573D61708FA4126"}
  end
end
