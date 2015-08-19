require 'test_helper'

class CecabankTest < Test::Unit::TestCase
  include CommStub

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

  def test_invalid_xml_response_handling
    @gateway.expects(:ssl_post).returns(invalid_xml_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_match(/Unable to parse the response/, response.message)
    assert_match(/No close tag for/, response.params['error_message'])
  end

  def test_expiration_date_sent_correctly
    stub_comms do
      @gateway.purchase(@amount, credit_card("4242424242424242", month: 1, year: 2014), @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/Caducidad=201401&/, data, "Expected expiration date format is yyyymm")
    end.respond_with(successful_purchase_response)
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
  
  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
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

  def invalid_xml_purchase_response
    <<-RESPONSE
<br>
<TRANSACCION valor="OK" numeroOperacion="202215722" fecha="22/01/2014 13:15:32">
Invalid unparsable xml in the response
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

  def transcript
    <<-TRANSCRIPT
      Num_operacion=0aa49d22f66af2c07163226dca82ddb8&Idioma=XML&Pago_soportado=SSL&URL_OK=NONE&URL_NOK=NONE&Importe=100&TipoMoneda=978&PAN=5540500001000004&Caducidad=201412&CVV2=989&Pago_elegido=SSL&Cifrado=SHA1&Firma=dcef9a490380a972f8ee4d801d416115402e0c94&Exponente=2&MerchantID=331009926&AcquirerBIN=0000522577&TerminalID=00000003
      Num_operacion=0aa49d22f66af2c07163226dca82ddb8&Idioma=XML&Pago_soportado=SSL&URL_OK=NONE&URL_NOK=NONE&Importe=100&TipoMoneda=978&PAN=5540500001000004&Caducidad=201412&CVV2=989&Pago_elegido=SSL&Cifrado=SHA1&Firma=dcef9a490380a972f8ee4d801d416115402e0c94&Exponente=2&MerchantID=331009926&AcquirerBIN=0000522577&TerminalID=00000003"
    TRANSCRIPT
  end

  def scrubbed_transcript
    <<-SCRUBBED_TRANSCRIPT
      Num_operacion=0aa49d22f66af2c07163226dca82ddb8&Idioma=XML&Pago_soportado=SSL&URL_OK=NONE&URL_NOK=NONE&Importe=100&TipoMoneda=978&PAN=[FILTERED]&Caducidad=201412&CVV2=[FILTERED]&Pago_elegido=SSL&Cifrado=SHA1&Firma=dcef9a490380a972f8ee4d801d416115402e0c94&Exponente=2&MerchantID=331009926&AcquirerBIN=0000522577&TerminalID=00000003
      Num_operacion=0aa49d22f66af2c07163226dca82ddb8&Idioma=XML&Pago_soportado=SSL&URL_OK=NONE&URL_NOK=NONE&Importe=100&TipoMoneda=978&PAN=[FILTERED]&Caducidad=201412&CVV2=[FILTERED]&Pago_elegido=SSL&Cifrado=SHA1&Firma=dcef9a490380a972f8ee4d801d416115402e0c94&Exponente=2&MerchantID=331009926&AcquirerBIN=0000522577&TerminalID=00000003"
    SCRUBBED_TRANSCRIPT
  end
end
