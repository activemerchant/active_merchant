require 'test_helper'

class RemoteNetpayTest < Test::Unit::TestCase


  def setup
    @gateway = NetpayGateway.new(fixtures(:netpay))

    NetpayGateway.wiredump_device = File.open(File.join('/tmp', "netpay.log"), "a+")
    NetpayGateway.wiredump_device.sync = true

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

  #def test_unsuccessful_purchase
  #  assert response = @gateway.purchase(@amount, @declined_card, @options)
  #  assert_failure response
  #  assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  #end

  def test_successful_purchase_and_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Aprobada', refund.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Aprobada', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
    assert_equal 'Aprobada', capture.message
  end

  def test_authorize_and_cancel
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Aprobada', auth.message
    assert cancel = @gateway.cancel(amount, auth.authorization)
    assert_success cancel
    assert_equal 'Aprobada', cancel.message
  end

  #def test_failed_capture
  #  assert response = @gateway.capture(@amount, '')
  #  assert_failure response
  #  assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  #end

  #def test_invalid_login
  #  gateway = NetpayGateway.new(
  #              :login => '',
  #              :password => ''
  #            )
  #  assert response = gateway.purchase(@amount, @credit_card, @options)
  #  assert_failure response
  #  assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  #end
end
