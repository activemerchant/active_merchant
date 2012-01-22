require 'test_helper'
require 'logger'

class UsaEpayTest < Test::Unit::TestCase

  def test_transaction_gateway_created
    gateway = UsaEpayGateway.new(
      :login => 'X'
    )
    assert_kind_of UsaEpayTransactionGateway, gateway
  end

  def test_advanced_gateway_created_with_software_id
    gateway = UsaEpayGateway.new(
      :login => 'X',
      :password => 'Y',
      :software_id => 'Z'
    )
    assert_kind_of UsaEpayAdvancedGateway, gateway
  end

  def test_advanced_gateway_created_with_urls
    gateway = UsaEpayGateway.new(
      :login => 'X',
      :password => 'Y',
      :test_url => 'Z',
      :live_url => 'Z'
    )
    assert_kind_of UsaEpayAdvancedGateway, gateway
  end
end
