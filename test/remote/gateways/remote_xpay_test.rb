require 'test_helper'

class RemoteXpayTest < Test::Unit::TestCase
  def setup
    @gateway = XpayGateway.new(fixtures(:xpay))
    @amount = 5000
    @credit_card = credit_card(
      '5186151650005008',
      month: 12,
      year: 2026,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '123',
      brand: 'master'
    )

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

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'PENDING', response.message
  end

  def test_successful_purchase
    init = @gateway.purchase(@amount, @credit_card, @options)
    assert_success init
    assert_match 'PENDING', init.message
  end
end
