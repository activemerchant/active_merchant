require 'test_helper'

class RemoteBalancedTest < Test::Unit::TestCase


  def setup
    @gateway = BalancedGateway.new(fixtures(:balanced))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @invalid_card = credit_card('4222222222222220')
    @declined_card = credit_card('4444444444444448')

    @options = {
        :email =>  'john.buyer@example.org',
        :billing_address => address,
        :description => 'Shopify Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert_equal @amount, response.params['amount']
  end

  def test_invalid_card
    assert response = @gateway.purchase(@amount, @invalid_card, @options)
    assert_failure response
    assert response.message.index('Processor did not accept this card.') != nil
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert response.message.index('Processor did not accept this card.') != nil
  end

  #def test_authorize_and_capture
  #  amount = @amount
  #  assert auth = @gateway.authorize(amount, @credit_card, @options)
  #  assert_success auth
  #  assert_equal 'Success', auth.message
  #  assert auth.authorization
  #  assert capture = @gateway.capture(amount, auth.authorization)
  #  assert_success capture
  #end
  #
  #def test_failed_capture
  #  assert response = @gateway.capture(@amount, '')
  #  assert_failure response
  #  assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  #end
  #
  #def test_invalid_login
  #  gateway = BalancedGateway.new(
  #              :login => '',
  #              :password => ''
  #            )
  #  assert response = gateway.purchase(@amount, @credit_card, @options)
  #  assert_failure response
  #  assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  #end
end
