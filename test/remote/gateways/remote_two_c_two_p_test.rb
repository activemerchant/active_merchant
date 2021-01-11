require 'test_helper'

class RemoteTwoCTwoPTest < Test::Unit::TestCase
  def setup
    @gateway = TwoCTwoPGateway.new(fixtures(:two_c_two_p))

    @amount = 1000

    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('')

    @invalid_card_options = {
      order_id: generate_unique_id,
      description: 'Store Purchase',
      currency: 'PHP',
      pan_country: 'PH',
    }

    @valid_card_options = {
      order_id: generate_unique_id,
      description: 'Store Purchase',
      currency: 'PHP',
      pan_country: 'PH',
    }    
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @valid_card_options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_fail_purchase
    response = @gateway.purchase(@amount, @declined_card, @invalid_card_options)
    assert_failure response
    assert_equal "The length of 'pan' field does not match.", response.message
  end
end
