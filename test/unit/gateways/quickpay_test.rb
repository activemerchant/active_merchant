
require 'test_helper'

class QuickpayTest < Test::Unit::TestCase
  
  def test_error_without_login_option
    assert_raise ArgumentError do
      QuickpayGateway.new
    end
  end
  
  def test_v4to7
    gateway = QuickpayGateway.new(:login => 50000000, :password => 'secret')  
    assert_instance_of QuickpayV4to7Gateway, gateway
  end
  
  def test_v10
    gateway = QuickpayGateway.new(:login => 100, :api_key => 'APIKEY')  
    assert_instance_of QuickpayV10Gateway, gateway
  end
    
end

