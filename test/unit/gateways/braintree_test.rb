require 'test_helper'

class BraintreeTest < Test::Unit::TestCase

  def test_new_with_login_password_creates_braintree_orange
    gateway = BraintreeGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )
    assert_instance_of BraintreeOrangeGateway, gateway
  end

  def test_new_with_merchant_id_creates_braintree_blue
    gateway = BraintreeGateway.new(
      :merchant_id => 'MERCHANT_ID',
      :public_key => 'PUBLIC_KEY',
      :private_key => 'PRIVATE_KEY'
    )
    assert_instance_of BraintreeBlueGateway, gateway
  end
end
