require 'test_helper'

class RemotePayhubTest < Test::Unit::TestCase


  def setup
    @gateway = PayhubGateway.new(fixtures(:payhub))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
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
    assert_equal '00', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_not_equal '00', response.message
  end

  def test_invalid_login
    gateway = PayhubGateway.new(
                :orgid => '',
                :mode => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_not_equal '00', response.message
  end


=begin
  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  end
=end

end
