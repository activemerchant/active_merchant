require 'test_helper'

class RemotePayhubTest < Test::Unit::TestCase


  def setup
    @gateway = PayhubGateway.new(fixtures(:payhub))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @credit_card.verification_value = "999"
    @declined_card = credit_card('1234123445674567')

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match /SUCCESS/, response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match /Invalid|incorrect|415\-306\-9476/, response.message
  end

  def test_invalid_login
    gateway = PayhubGateway.new(
                :orgid => '',
                :mode => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match /Invalid|incorrect|415\-306\-9476/, response.message
  end

end
