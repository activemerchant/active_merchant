require 'test_helper'

class CecabankTest < Test::Unit::TestCase
  def setup
    @gateway = CecabankGateway.new(
      :merchant_id  => '12345678',
      :acquirer_bin => '12345678',
      :terminal_id  => '00000003',
      :key => 'enc_key'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '12345678901234567890|202215722', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_refund_request
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(@amount, "reference", @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_refund_request
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(@amount, "reference", @options)
    assert_failure response
    assert response.test?
  end

  private

  def successful_purchase_response
    <<-RESPONSE
<?xml version="1.0" encoding="ISO-8859-1" ?>
<TRANSACCION valor="OK" numeroOperacion="202215722" fecha="22/01/2014 13:15:32">
  <OPERACION tipo="000">
    <importe>        171.00  Euros</importe>
    <descripcion><![CDATA[blah blah blah]]></descripcion>
    <numeroAutorizacion>101000</numeroAutorizacion>
    <referencia>12345678901234567890</referencia>
    <pan>##PAN##</pan>
  </OPERACION>
</TRANSACCION>
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
<?xml version="1.0" encoding="ISO-8859-1" ?>
<TRANSACCION valor="ERROR" numeroOperacion="1390410672" fecha="22/01/2014 18:11:12">
  <ERROR>
    <codigo>27</codigo>
    <descripcion><![CDATA[ERROR. Formato CVV2/CVC2 no valido.]]></descripcion>
  </ERROR>
</TRANSACCION>
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
<?xml version="1.0" encoding="ISO-8859-1" ?>
<TRANSACCION valor="OK" numeroOperacion="1390414594" fecha="##FECHA##" >
  <OPERACION tipo="900">
    <importe>          1.00 Euros</importe>
  </OPERACION>
</TRANSACCION>
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
<?xml version="1.0" encoding="ISO-8859-1" ?>
<TRANSACCION valor="ERROR" numeroOperacion="1390414596" fecha="##FECHA##">
  <ERROR>
    <codigo>15</codigo>
    <descripcion><![CDATA[ERROR. Operaci&oacute;n inexistente <1403>]]></descripcion>
  </ERROR>
</TRANSACCION>
    RESPONSE
  end
end
