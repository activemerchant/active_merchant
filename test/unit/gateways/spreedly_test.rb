require 'test_helper'

class SpreedlyTest < Test::Unit::TestCase
  def setup
    @gateway = SpreedlyGateway.new(fixtures(:spreedly))

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
end