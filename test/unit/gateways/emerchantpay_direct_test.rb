require          'test_helper'
require_relative 'genesis/shared_examples'

class EmerchantpayDirectTest < Test::Unit::TestCase

  include CommStub
  include Genesis::SharedExamples

  def setup
    @gateway = EmerchantpayDirectGateway.new(
      username: 'username',
      password: 'password',
      token:    'token'
    )

    prepare_shared_test_data(credit_card)
  end

end
