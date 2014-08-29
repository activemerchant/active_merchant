require 'test_helper'
require 'unit/gateways/authorize_net_test'

class NmiTest < AuthorizeNetTest
  def setup
    super
    @gateway = NmiGateway.new(:login => 'X', :password => 'Y')
  end

  def test_credit_card_purchase_no_recurring_flag
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_no_match(/x_recurring_billing/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_credit_card_purchase_with_recurring_flag
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, :recurring => true)
    end.check_request do |endpoint, data, headers|
      assert_match(/x_recurring_billing=TRUE/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end
end
