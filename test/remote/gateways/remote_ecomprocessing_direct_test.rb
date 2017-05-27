require          'test_helper'
require_relative 'genesis/shared_examples'

class RemoteEcomprocessingDirectTest < Test::Unit::TestCase

  include Genesis::SharedExamples

  def setup
    @gateway = EcomprocessingDirectGateway.new(fixtures(:ecomprocessing_direct))

    prepare_shared_test_data
  end

end
