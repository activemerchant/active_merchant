require 'test_helper'

class RemoteRapydTest < Test::Unit::TestCase
  def setup
    @gateway = XpayGateway.new(fixtures(:x_pay))
    @amount = 200
    @credit_card = credit_card('4111111111111111')
    @options = {}
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match 'The payment was paid', response.message
  end
end
