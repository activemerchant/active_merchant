require 'test_helper'

class RemoteRapydTest < Test::Unit::TestCase
  def setup
    @gateway = XpayGateway.new(fixtures(:x_pay))
    @amount = 3545
    @credit_card = credit_card('4111111111111111')
    @options = {
      order: {
        order_id: 'btid2384983',
        currency: 'EUR',
        amount: @amount,
        customer_info: {
          card_holder_name: 'John Doe',
          card_holder_email: 'test@example.com',
          billing_address: address
        }
      }
    }
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_match 'PENDING', response.message
  end

  def test_successful_purchase
    auth = @gateway.authorize(@amount, @credit_card, @options)
    options = @options.merge(operation_id: auth.params.dig('operation', 'operationId'))
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_match 'PENDING', response.message
  end

  def test_successful_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    options = @options.merge(operation_id: auth.params.dig('operation', 'operationId'))
    response = @gateway.capture(@amount, @credit_card, options)
    assert_success response
  end
end
