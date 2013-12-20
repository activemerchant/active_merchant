require 'test_helper'

class RemoteSrPagoTest < Test::Unit::TestCase


  def setup
    @gateway = SrPagoGateway.new(fixtures(:sr_pago))

    @amount = 1050
    @credit_card = credit_card('5453750000000011')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :uid => "MUAyMDExMDMyNDE2NTczNQ==",
      :test => true,
      :ref => "cargo de prueba",
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Antonió Flores Aldama\nManuel avila camacho 184, Col. Reforma Social, Del. Miguel Hidalgo, C.P. 11650\nTel: 5541691761", response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "No. de tarjeta invalido.\n", response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal "Antonió Flores Aldama\nManuel avila camacho 184, Col. Reforma Social, Del. Miguel Hidalgo, C.P. 11650\nTel: 5541691761", auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal "No capturado", response.message
  end
end
