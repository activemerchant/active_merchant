require          'test_helper'
require_relative 'genesis/shared_examples'

class EcomprocessingDirectTest < Test::Unit::TestCase

  include CommStub
  include Genesis::SharedExamples

  def setup
    @gateway = EcomprocessingDirectGateway.new(
      username: 'username',
      password: 'password',
      token:    'token'
    )

    prepare_shared_test_data(credit_card)
  end

end
