require 'test_helper'

class RemoteBanwireTest < Test::Unit::TestCase


  def setup
    @gateway = BanwireGateway.new(:login => "desarrollo",
                                  :currency => "MXN")

    @amount = 100
    @credit_card = credit_card('5204164299999999',
                               :month => 11,
                               :year => 2012,
                               :verification_value => '999')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => '1',
      :email => "test@email.com",
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'denied', response.message
  end

  def test_invalid_login
    gateway = BanwireGateway.new(
                :login => 'fakeuser',
                :currency => 'MXN'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'ID de cuenta invalido', response.message
  end
end
