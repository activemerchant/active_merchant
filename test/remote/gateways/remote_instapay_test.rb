require File.dirname(__FILE__) + '/../../test_helper'

class RemoteInstapayTest < Test::Unit::TestCase


  def setup
    @gateway = InstapayGateway.new(fixtures(:instapay))

    @amount = 100
    @credit_card = credit_card('5454545454545454')
    @declined_card = credit_card('4000300011112220')
       @authorization = '92888036'

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount,  @declined_card, @options)
    assert_failure response
    assert_equal  'Declined', response.message
  end

  def test_succesful_auth
    assert response = @gateway.authorize(@amount,  @credit_card, @options)
    assert_success response
    assert_equal  'Accepted', response.message
  end

  def test_failed_auth
    assert response = @gateway.authorize(@amount,  @declined_card, @options)
    assert_failure response
    assert_equal  'Declined', response.message
  end
end
