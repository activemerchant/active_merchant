require 'test_helper'

class SrPagoTest < Test::Unit::TestCase
  def setup
    @gateway = SrPagoGateway.new()

    @credit_card = credit_card
    @credit_card.number = "5453750000000011"

    @amount = 1050

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
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '777', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
      response = "<?xml version='1.0' encoding='UTF-8'?>\n<root>\n\t<PAGO>\n\t\t<ESTADO>OK</ESTADO>\n\t\t<AUTHNO>777</AUTHNO>\n\t\t<FECHA>19/12/2013</FECHA>\n\t\t<HORA>17:54:09</HORA>\n\t\t<FOLIO>000000</FOLIO>\n\t\t<IMPORTE>$10.50 MXP</IMPORTE>\n\t\t<TARJETA>MAST</TARJETA>\n\t\t<TARJETANO>XXXX-0011</TARJETANO>\n\t\t<NOMBRE>Longbob Longsen</NOMBRE>\n\t\t<COMERCIO>Antonio Flores Aldama\nManuel avila camacho 184, Col. Reforma Social, Del. Miguel Hidalgo, C.P. 11650\nTel: 5541691761</COMERCIO>\n\t\t</PAGO>\n</root>"
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
      response = "<?xml version='1.0' encoding='UTF-8'?>\n<root>\n\t<PAGO>\n\t\t<ESTADO>ERR</ESTADO>\n\t\t\t<AUTHNO>Tarjeta declinada por el banco, intente nuevamente, posiblemente tenga que llamar al banco para aprobar el cargo.</AUTHNO>\n\t\t\t</PAGO>\n</root>"
  end
end
