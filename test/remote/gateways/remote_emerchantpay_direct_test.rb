require          'test_helper'
require_relative 'genesis/shared_examples'

class RemoteEmerchantpayDirectTest < Test::Unit::TestCase

  include Genesis::SharedExamples

  def setup
    @gateway = EmerchantpayDirectGateway.new(fixtures(:emerchantpay_direct))

    prepare_shared_test_data
  end

end
