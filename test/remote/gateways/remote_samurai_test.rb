require 'test_helper'

class RemoteSamuraiTest < Test::Unit::TestCase


  def setup
    @gateway = SamuraiGateway.new(fixtures(:samurai))

    @amount = 100
    @declined_amount = 100.02
    @invalid_card_amount = 100.07
    @expired_card_amount = 100.08
    @credit_card = credit_card('4111111111111111', :verification_value => '111')

    @options = {
      :address1            => "1000 1st Av",
      :zip                 => "10101",
      :billing_reference   => "billing_reference",
      :customer_reference  => "customer_reference",
      :custom              => "custom",
      :descriptor          => "descriptor",
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_declined_purchase
    assert response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The card was declined.', response.message
  end

  def test_invalid_purchase
    assert response = @gateway.purchase(@invalid_card_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The card number was invalid.', response.message
  end

  def test_expired_purchase
    assert response = @gateway.purchase(@expired_card_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The expiration date month was invalid, or prior to today.', response.message
  end

  def test_successful_auth_and_capture
    assert authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize
    assert_equal 'OK', authorize.message
    assert capture = @gateway.capture(@amount, authorize.authorization, @options)
    assert_success capture
    assert_equal 'OK', capture.message
  end

  def test_invalid_login
    assert_raise(ArgumentError) do
      SamuraiGateway.new( :login => '', :password => '' )
    end
  end
end
