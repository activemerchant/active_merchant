require 'test_helper'
require 'unit/gateways/authorize_net_test'

class BluePayTest < AuthorizeNetTest
  def setup
    super
    @gateway = BluePayGateway.new(
      :login => 'X',
      :password => 'Y'
    )
  end
end
