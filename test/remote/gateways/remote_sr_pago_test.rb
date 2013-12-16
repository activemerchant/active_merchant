require 'test_helper'

class RemoteSrPagoTest < Test::Unit::TestCase


  def setup
    @gateway = SrPagoGateway.new(fixtures(:sr_pago))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :uid => "MUAyMDExMDMyNDE2NTczNQ==",
      :test => true,
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'El cargo se hizo correctamente', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'El cargo no se pudo realizar', response.message
  end

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
    assert_equal 'No se pudo realizar el cargo correctamente', response.message
  end

  def test_invalid_login
    gateway = SrPagoGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Fallo al intentar autenticar', response.message
  end
end
