require 'test_helper'

class RemoteNetpayTest < Test::Unit::TestCase
  def setup
    @gateway = NetpayGateway.new(fixtures(:netpay))

    @amount = 2000
    @credit_card = credit_card('5454545454545454')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Aprobada', response.message
  end

  def test_unsuccessful_purchase
    # We have to force a decline using the mode option
    opts = @options.clone
    opts[:mode] = 'D'
    assert response = @gateway.purchase(@amount, @declined_card, opts)
    assert_failure response
    assert_match(/Declinada/, response.message)
  end

  def test_successful_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'Aprobada', void.message
  end

  def test_successful_purchase_and_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Aprobada', refund.message
  end

=begin
  # Netpay are currently adding support for authorize and capture.
  # When this is complete, the following remote calls should work.

  def test_successful_authorize
   assert response = @gateway.authorize(@amount, @credit_card, @options)
   assert_success response
   assert_equal 'Aprobada', response.message
  end

  def test_unsuccessful_authorize
   # We have to force a decline using the mode option
   opts = @options.clone
   opts[:mode] = 'D'
   assert response = @gateway.authorize(@amount, @declined_card, opts)
   assert_failure response
   assert_match /Declinada/, response.message
  end

  def test_successful_authorize_and_capture
   assert purchase = @gateway.authorize(@amount, @credit_card, @options)
   assert_success purchase
   assert capture = @gateway.capture(@amount, purchase.authorization)
   assert_success capture
   assert_equal 'Aprobada', capture.message
  end

  def test_failed_capture
   assert response = @gateway.capture(@amount, '')
   assert_failure response
   assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  end

  def test_invalid_login
   gateway = NetpayGateway.new(
               :login => '',
               :password => ''
             )
   assert response = gateway.purchase(@amount, @credit_card, @options)
   assert_failure response
   assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  end
=end
end
