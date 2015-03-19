require 'test_helper'

class PagoFacilTest < Test::Unit::TestCase
  def setup
    @gateway = PagoFacilGateway.new(fixtures(:pago_facil))

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      number: '4111111111111111',
      verification_value: '123',
      first_name: 'Juan',
      last_name: 'Reyes Garza',
      month: 9,
      year: Time.now.year + 1
    )

    @amount = 100

    @options = {
      order_id: '1',
      billing_address: {
        address1: 'Anatole France 311',
        address2: 'Polanco',
        city: 'Miguel Hidalgo',
        state: 'Distrito Federal',
        country: 'Mexico',
        zip: '11560',
        phone: '5550220910'
      },
      email: 'comprador@correo.com',
      cellphone: '5550123456'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "305638", response.authorization
    assert_equal "Transaction has been successful!-Approved", response.message
    assert response.test?
  end

  def test_successful_purchase_amex
    @gateway.expects(:ssl_post).returns(successful_purchase_response_amex)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "305638", response.authorization
    assert_equal "Transaction has been successful!-Approved", response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Errores en los datos de entrada Validaciones', response.message
  end

  def test_invalid_json
    @gateway.expects(:ssl_post).returns(invalid_json_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid response received from the PagoFacil API}, response.message
  end

  private

  def successful_purchase_response
    {"WebServices_Transacciones"=>
      {"transaccion"=>
        {"autorizado"=>"1",
         "autorizacion"=>"305638",
         "transaccion"=>"S-PFE12S12I12568",
         "texto"=>"Transaction has been successful!-Approved",
         "mode"=>"R",
         "empresa"=>"Usuario Invitado",
         "TransIni"=>"15:33:18 pm 25/02/2014",
         "TransFin"=>"15:33:27 pm 25/02/2014",
         "param1"=>"",
         "param2"=>"",
         "param3"=>"",
         "param4"=>"",
         "param5"=>"",
         "TipoTC"=>"Visa",
         "data"=>
          {"anyoExpiracion"=>"(2) **",
           "apellidos"=>"Reyes Garza",
           "calleyNumero"=>"Anatole France 311",
           "celular"=>"5550123456",
           "colonia"=>"Polanco",
           "cp"=>"11560",
           "cvt"=>"(3) ***",
           "email"=>"comprador@correo.com",
           "estado"=>"Distrito Federal",
           "idPedido"=>"1",
           "idServicio"=>"3",
           "idSucursal"=>"60f961360ca187d533d5adba7d969d6334771370",
           "idUsuario"=>"62ad6f592ecf2faa87ef2437ed85a4d175e73c58",
           "mesExpiracion"=>"(2) **",
           "monto"=>"1.00",
           "municipio"=>"Miguel Hidalgo",
           "nombre"=>"Juan",
           "numeroTarjeta"=>"(16) **** **** ****1111",
           "pais"=>"Mexico",
           "telefono"=>"5550220910",
           "transFechaHora"=>"1393363998",
           "bin"=>"(6) ***1"},
         "dataVal"=>
          {"idSucursal"=>"12",
           "cp"=>"11560",
           "nombre"=>"Juan",
           "apellidos"=>"Reyes Garza",
           "numeroTarjeta"=>"(16) **** **** ****1111",
           "cvt"=>"(3) ***",
           "monto"=>"1.00",
           "mesExpiracion"=>"(2) **",
           "anyoExpiracion"=>"(2) **",
           "idUsuario"=>"14",
           "source"=>"1",
           "idServicio"=>"3",
           "recurrente"=>"0",
           "plan"=>"NOR",
           "diferenciado"=>"00",
           "mensualidades"=>"00",
           "ip"=>"187.162.238.170",
           "httpUserAgent"=>"Ruby",
           "idPedido"=>"1",
           "tipoTarjeta"=>"Visa",
           "hashKeyCC"=>"e5be0afe08f125ec4f6f1251141c60df88d65eae",
           "idEmpresa"=>"12",
           "nombre_comercial"=>"Usuario Invitado",
           "transFechaHora"=>"1393363998",
           "noProcess"=>"",
           "noMail"=>"",
           "notaMail"=>"",
           "settingsTransaction"=>
            {"noMontoMes"=>"0.00",
             "noTransaccionesDia"=>"0",
             "minTransaccionTc"=>"5",
             "tiempoDevolucion"=>"30",
             "sendPdfTransCliente"=>"1",
             "noMontoDia"=>"0.00",
             "noTransaccionesMes"=>"0"},
           "email"=>"comprador@correo.com",
           "telefono"=>"5550220910",
           "celular"=>"5550123456",
           "calleyNumero"=>"Anatole France 311",
           "colonia"=>"Polanco",
           "municipio"=>"Miguel Hidalgo",
           "estado"=>"Distrito Federal",
           "pais"=>"Mexico",
           "idCaja"=>"",
           "paisDetectedIP"=>"MX",
           "qa"=>"1",
           "https"=>"on"},
         "status"=>"success"
        }
      }
    }.to_json
  end

  def failed_purchase_response
    {"WebServices_Transacciones"=>
      {"transaccion"=>
        {"autorizado"=>"0",
         "transaccion"=>"n/a",
         "autorizacion"=>"n/a",
         "texto"=>"Errores en los datos de entrada Validaciones",
         "error"=>
          {"numeroTarjeta"=>"'1111111111111111' no es de una institucion permitida"},
         "empresa"=>"Sin determinar",
         "TransIni"=>"16:10:20 pm 25/02/2014",
         "TransFin"=>"16:10:20 pm 25/02/2014",
         "param1"=>"",
         "param2"=>"",
         "param3"=>"",
         "param4"=>"",
         "param5"=>"",
         "TipoTC"=>"",
         "data"=>
          {"anyoExpiracion"=>"(2) **",
           "apellidos"=>"Reyes Garza",
           "calleyNumero"=>"Anatole France 311",
           "celular"=>"5550123456",
           "colonia"=>"Polanco",
           "cp"=>"11560",
           "cvt"=>"(3) ***",
           "email"=>"comprador@correo.com",
           "estado"=>"Distrito Federal",
           "idPedido"=>"1",
           "idServicio"=>"3",
           "idSucursal"=>"60f961360ca187d533d5adba7d969d6334771370",
           "idUsuario"=>"62ad6f592ecf2faa87ef2437ed85a4d175e73c58",
           "mesExpiracion"=>"(2) **",
           "monto"=>"1.00",
           "municipio"=>"Miguel Hidalgo",
           "nombre"=>"Juan",
           "numeroTarjeta"=>"(16) **** **** ****1111",
           "pais"=>"Mexico",
           "telefono"=>"5550220910",
           "transFechaHora"=>"1393366220",
           "bin"=>"(6) ***1"},
         "dataVal"=>
          {"email"=>"comprador@correo.com",
           "telefono"=>"5550220910",
           "celular"=>"5550123456",
           "calleyNumero"=>"Anatole France 311",
           "colonia"=>"Polanco",
           "municipio"=>"Miguel Hidalgo",
           "estado"=>"Distrito Federal",
           "pais"=>"Mexico",
           "idCaja"=>"",
           "numeroTarjeta"=>"",
           "cvt"=>"",
           "anyoExpiracion"=>"",
           "mesExpiracion"=>"",
           "https"=>"on"},
         "status"=>"success"
        }
      }
    }.to_json
  end

  def invalid_json_response
    "<b>Notice</b>\n#{failed_purchase_response}"
  end

  def successful_purchase_response_amex
    response = JSON.parse(successful_purchase_response)
    response.
      fetch("WebServices_Transacciones").
      fetch("transaccion")["autorizado"] = true
    response.to_json
  end
end
