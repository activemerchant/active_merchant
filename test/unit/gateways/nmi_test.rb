require 'test_helper'
require 'unit/gateways/authorize_net_test'

class NmiTest < AuthorizeNetTest
  def setup
    super
    @gateway = NmiGateway.new(
      :login => 'X',
      :password => 'Y'
    )
  end
end
