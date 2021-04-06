require 'test_helper'

class PlaceToPayTest < Test::Unit::TestCase
  def setup
    @wrong_default_gateway = PlaceToPayGateway.new(login: '963bd435c7635826e6a34a4bb11a', secret_key: '1567q2a086', country: 'COL')
    @default_gateway = PlaceToPayGateway.new(login: '8c94963bd435c7635826e6a34a4bb11a', secret_key: 'RYKUrC1567q2a086', country: 'COL')
    @gateway_international = PlaceToPayGateway.new(login: '1863f8a3ba0e8d4290137c4b18fa4286', secret_key: '97d3E70wO36CoQjS', country: 'EC')
    @amount = 100
    @valid_credit_card = credit_card('4005580000000040')
    @valid_credit_card_otp = credit_card('36545400000008')
    @valid_credit_card_for_colombia = credit_card('4111111111111111')
    @invalid_credit_card = credit_card('36545400000248')
    @expired_credit_card = credit_card('4012888888881881')
    @options = {
      order_id: generate_unique_id,
      currency: 'USD'
    }
    @payer = {
      document: '8467451900',
      documentType: 'CC',
      name: 'Miss Delia Schamberger Sr.',
      surname: 'Wisozk',
      email: 'tesst@gmail.com',
      mobile: '3006108300'
    }
    @options_to_capture = @options.merge({
      payer: @payer,
      otp: '000000'
    })
    @purchase_options = @options.merge({
      payer: @payer,
      reference: "Lucho_test_#{rand(1000)}",
      description: 'some description',
      group_code: 'P',
      buyer: @payer,
      code: 1,
      type: 22,
      groupCode: 'M',
      installment: 12,
      additional: {
        'SOME_ADDITIONAL': 'http://example.com/yourcheckout'
      },
      taxes: [
        {
          kind: 'ice',
          amount: 4.8,
          base: 40
        },
        {
          kind: 'valueAddedTax',
          amount: 7.6,
          base: 40
        }
      ],
      details: [
        {
          kind: 'shipping',
          amount: 2
        },
        {
          kind: 'tip',
          amount: 2
        },
        {
          kind: 'subtotal',
          amount: 40
        }
      ]
    })
  end

  def test_successful_authorize
    @default_gateway.expects(:ssl_post).returns(successful_authorize_response)
    @gateway_international.expects(:ssl_post).returns(successful_authorize_response)
    response_default_gateway = @default_gateway.authorize(@amount, @valid_credit_card, @options)
    response_international_gateway = @gateway_international.authorize(@amount, @valid_credit_card, @options)
    assert_success response_default_gateway
    assert_success response_international_gateway
    assert_equal 'La petición se ha procesado correctamente', response_default_gateway.message
    assert_equal 'La petición se ha procesado correctamente', response_international_gateway.message
    assert response_default_gateway.test?
    assert response_international_gateway.test?
  end

  def test_failled_authorize_wrong_credentials
    @wrong_default_gateway.expects(:ssl_post).returns(failled_authorize_response)
    @gateway_international.expects(:ssl_post).returns(failled_authorize_response)
    response_default_gateway = @wrong_default_gateway.authorize(@amount, @invalid_credit_card,
      @options)
    response_international_gateway = @gateway_international.authorize(@amount, @valid_credit_card,
      @options)
    assert_failure response_default_gateway
    assert_failure response_international_gateway

    assert_equal 'Autenticación fallida 101', response_default_gateway.message
    assert_equal 'Autenticación fallida 101', response_international_gateway.message
    assert response_default_gateway.test?
    assert response_international_gateway.test?
  end

  def test_successful_my_pi_query_card_ec
    options = {id: 1}
    @gateway_international.expects(:ssl_post).returns(successful_my_pi_query_card_response)
    response = @gateway_international.my_pi_query(@amount, @valid_credit_card, options)
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
    assert response.test?
  end

  def test_failed_my_pi_query_card_ec
    options = {id: 1}
    @gateway_international.expects(:ssl_post).returns(failed_my_pi_query_card_response)
    response = @gateway_international.my_pi_query(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'El comercio no tiene configurados datos de 3DS', response.message
    assert response.test?
  end

  def test_successful_calculate_interests_ec
    options = @options.merge({
      code: 1,
      type: 22,
      groupCode: 'M',
      installment: 12
    })
    @gateway_international.expects(:ssl_post).returns(successful_calculate_interests_response)
    response = @gateway_international.calculate_interests(@amount, @valid_credit_card, options)
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
    assert response.test?
  end

  def test_failed_calculate_interests_ec
    options = @options.merge({
      code: 1,
      type: 22,
      groupCode: 'M',
      installment: 12
    })
    @gateway_international.expects(:ssl_post).returns(failed_calculate_interests_response)
    response = @gateway_international.calculate_interests(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'Ha ocurrido un error al obtener el cálculo de intereses, por favor intenta de nuevo en unos minutos', response.message
    assert response.test?
  end

  def test_successful_generate_otp_ec
    credit_card = credit_card('36545400000008',
      verification_value: '237',
      month: '03',
      year: '22')
    options = @options.merge({
      reference: '5b05daa383573',
      description: 'A payment collect example'
    })
    @gateway_international.expects(:ssl_post).returns(successful_generate_otp_response)
    response = @gateway_international.generate_otp(@amount, credit_card, options)
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
    assert response.test?
  end

  def test_failed_generate_otp_ec
    options = @options.merge({
      reference: '5b05daa383573',
      description: 'A payment collect example'
    })
    @gateway_international.expects(:ssl_post).returns(failed_generate_otp_response)
    response = @gateway_international.generate_otp(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'El servicio requerido no aplica para el medio de pago suministrado OTP Generation', response.message
    assert response.test?
  end

  def test_successful_validate_otp_ec
    options = @options.merge({
      reference: '2110163',
      otp: '866003',
      taxes: []
    })
    @gateway_international.expects(:ssl_post).returns(successful_validate_otp_response)
    response = @gateway_international.validate_otp(@amount, @valid_credit_card, options)
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
    assert response.test?
  end

  def test_failed_validate_otp_ec
    options = @options.merge({
      reference: '2110163',
      otp: '866003',
      taxes: []
    })
    @gateway_international.expects(:ssl_post).returns(failed_validate_otp_response)
    response = @gateway_international.validate_otp(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'El servicio requerido no aplica para el medio de pago suministrado OTP Generation', response.message
    assert response.test?
  end

  def test_successful_purchase
    @gateway_international.expects(:ssl_post).returns(successful_purchase_response)
    @default_gateway.expects(:ssl_post).returns(successful_purchase_response)
    international_response = @gateway_international.purchase(@amount, @valid_credit_card, @purchase_options)
    default_gateway = @default_gateway.purchase(@amount, @valid_credit_card, @purchase_options)
    assert_success international_response
    assert_success default_gateway
    assert_equal 'Aprobada', international_response.message
    assert_equal 'Aprobada', default_gateway.message
    assert international_response.test?
    assert default_gateway.test?
  end

  def test_failed_purchase
    @gateway_international.expects(:ssl_post).returns(failed_purchase_response)
    @default_gateway.expects(:ssl_post).returns(failed_purchase_response_col)
    international_response = @gateway_international.purchase(@amount, @invalid_credit_card, @purchase_options)
    default_gateway = @default_gateway.purchase(@amount, @invalid_credit_card, @purchase_options)
    assert_failure international_response
    assert_failure default_gateway
    assert_equal 'Por favor comunicarse con el call center', international_response.message
    assert_equal 'Código de moneda inválido o no soportado', default_gateway.message
    assert international_response.test?
    assert default_gateway.test?
  end

  def test_succesful_get_status_transaction
    options = {
      internalReference: 34812
    }
    @gateway_international.expects(:ssl_post).returns(successful_get_query_transaction)
    @default_gateway.expects(:ssl_post).returns(successful_get_query_transaction)
    iternational_response = @gateway_international.get_status_transaction(options)
    default_gateway = @default_gateway.get_status_transaction(options)
    assert_success iternational_response
    assert_success default_gateway
    assert_equal 'Aprobada', iternational_response.message
    assert_equal 'Aprobada', default_gateway.message
    assert iternational_response.test?
    assert default_gateway.test?
  end

  def test_failed_get_status_transaction_wrong_reference
    options = {
      internalReference: 34812
    }
    @gateway_international.expects(:ssl_post).returns(failed_get_query_transaction_wrong_reference)
    @default_gateway.expects(:ssl_post).returns(failed_get_query_transaction_wrong_reference)
    iternational_response = @gateway_international.get_status_transaction(options)
    default_gateway = @default_gateway.get_status_transaction(options)
    assert_failure iternational_response
    assert_failure default_gateway
    assert_equal 'No hay una transacción con el identificador provisto', iternational_response.message
    assert_equal 'No hay una transacción con el identificador provisto', default_gateway.message
    assert iternational_response.test?
    assert default_gateway.test?
  end

  def test_succesful_refund
    options = {
      internalReference: 10446,
      authorization: '000000',
      action: 'reverse'
    }
    @gateway_international.expects(:ssl_post).returns(successful_refund)
    @default_gateway.expects(:ssl_post).returns(successful_refund)
    iternational_response = @gateway_international.refund(options)
    response_col = @default_gateway.refund(options)
    assert_success iternational_response
    assert_success response_col
    assert_equal 'Aprobada', iternational_response.message
    assert_equal 'Aprobada', response_col.message
    assert iternational_response.test?
    assert response_col.test?
  end

  def test_failed_refund
    options = {
      internalReference: 10446,
      authorization: '000000',
      action: 'reverse'
    }
    @gateway_international.expects(:ssl_post).returns(failed_refund)
    @default_gateway.expects(:ssl_post).returns(failed_refund)
    iternational_response = @gateway_international.refund(options)
    response_col = @default_gateway.refund(options)
    assert_failure iternational_response
    assert_failure response_col
    assert_equal 'La referencia interna provista es inválida', iternational_response.message
    assert_equal 'La referencia interna provista es inválida', response_col.message
    assert iternational_response.test?
    assert response_col.test?
  end

  def test_successful_capture
    options = @options.merge({
       payer: @payer,
       otp: 'a8ecc59c2510a8ae27e1724ebf4647b5'
     })
     @gateway_international.expects(:ssl_post).returns(successful_capture)
     @default_gateway.expects(:ssl_post).returns(successful_capture)
     iternational_response = @gateway_international.capture(@valid_credit_card, options)
     response_col = @default_gateway.capture(@valid_credit_card, options)
     assert_success iternational_response
     assert_success response_col
     assert_equal 'La petición se ha procesado correctamente', iternational_response.message
     assert_equal 'La petición se ha procesado correctamente', response_col.message
   end

   def test_failed_search
    options = {
      reference: 'TEST_20180516_182751',
       amount: {
         currency: 'USD'
       }
     }
     money = 3243
     @gateway_international.expects(:ssl_post).returns(failed_search_transaction)
     @default_gateway.expects(:ssl_post).returns(failed_search_transaction)
     iternational_response = @gateway_international.search_transaction(money, options)
     response_col = @default_gateway.search_transaction(money, options)
     assert_failure iternational_response
     assert_failure response_col
     assert_equal 'No se ha encontrado información con los datos proporcionados', iternational_response.message
     assert_equal 'No se ha encontrado información con los datos proporcionados', response_col.message
   end

  private

  def successful_authorize_response
    <<-RESPONSE
    {
        "status": {
            "status": "OK",
            "reason": "00",
            "message": "La petición se ha procesado correctamente",
            "date": "2020-08-16T10:52:12-05:00"
        }
    }
    RESPONSE
  end

  def failled_authorize_response
    <<-RESPONSE
    {
      "status":
        {
          "status": "FAILED",
          "reason": 401,
          "message": "Autenticación fallida 101",
          "date": "2020-08-26T20:43:43-05:00"
        }
    }
    RESPONSE
  end

  def successful_my_pi_query_card_response
    <<-RESPONSE
    {
        "status": {
          "status": "OK",
          "reason": "00",
          "message": "La petición se ha procesado correctamente",
          "date": "2020-08-26T21:34:36-05:00"
        }
    }
    RESPONSE
  end

  def failed_my_pi_query_card_response
    <<-RESPONSE
    {
        "status": {
          "status": "FAILED",
          "reason": "SU",
          "message": "El comercio no tiene configurados datos de 3DS",
          "date": "2020-08-26T21:37:51-05:00"
        }
    }
    RESPONSE
  end

  def successful_calculate_interests_response
    <<-RESPONSE
    {
        "status": {
          "status": "OK",
          "reason": "00",
          "message": "La petición se ha procesado correctamente",
          "date": "2020-08-26T21:49:30-05:00"
        }
    }
    RESPONSE
  end

  def failed_calculate_interests_response
    <<-RESPONSE
    {
      "status": {
        "status": "REJECTED",
        "reason": "SU",
        "message": 
          "Ha ocurrido un error al obtener el cálculo de intereses, por favor intenta de nuevo en unos minutos",
        "date": "2020-08-26T21:52:15-05:00"
      }
    }
    RESPONSE
  end

  def successful_generate_otp_response
    <<-RESPONSE
    {
      "status": {
        "status": "OK",
        "reason": "SU",
        "message": "La petición se ha procesado correctamente",
        "date": "2020-08-26T22:03:31-05:00"
      }
    }
    RESPONSE
  end

  def failed_generate_otp_response
    <<-RESPONSE
    {
      "status": {
        "status": "REJECTED",
        "reason": "SU",
        "message": "El servicio requerido no aplica para el medio de pago suministrado OTP Generation",
        "date": "2020-08-26T22:06:39-05:00"
      }
    }
    RESPONSE
  end

  def successful_validate_otp_response
    <<-RESPONSE
    {
      "status": {
        "status": "OK",
        "reason": "SU",
        "message": "La petición se ha procesado correctamente",
        "date": "2020-08-26T22:06:39-05:00"
      }
    }
    RESPONSE
  end

  def failed_validate_otp_response
    <<-RESPONSE
    {
      "status": {
        "status": "REJECTED",
        "reason": "SU",
        "message": "El servicio requerido no aplica para el medio de pago suministrado OTP Generation",
        "date": "2020-08-26T22:06:39-05:00"
      }
    }
    RESPONSE
  end

  def successful_purchase_response
    <<-RESPONSE
    {
      "status": {
        "status": "APPROVED",
        "reason": "00",
        "message": "Aprobada",
        "date": "2020-08-26T22:06:39-05:00"
      }
    }
    RESPONSE
  end

  def failed_purchase_response_col
    <<-RESPONSE
    {
      "status": {
        "status": "REJECTED",
        "reason": "XC",
        "message": "Código de moneda inválido o no soportado",
        "date": "2020-08-26T23:07:30-05:00"
      }
    }
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
    {
      "status": {
        "status": "REJECTED",
        "reason": "02",
        "message": "Por favor comunicarse con el call center",
        "date": "2020-08-26T23:32:09-05:00"
      }
    }
    RESPONSE
  end

  def successful_get_query_transaction
    <<-RESPONSE
    {
      "status": {
        "status": "APPROVED",
        "reason": "00",
        "message": "Aprobada",
        "date": "2020-08-27T00:02:51-05:00"
      }
    }
    RESPONSE
  end

  def failed_get_query_transaction_wrong_reference
    <<-RESPONSE
    {
      "status": {
        "status": "FAILED",
        "reason": "BR",
        "message": "No hay una transacción con el identificador provisto",
        "date": "2020-08-27T00:02:51-05:00"
      }
    }
    RESPONSE
  end

  def successful_refund
    <<-RESPONSE
    {
      "status": {
        "status": "APPROVED",
        "reason": "00",
        "message": "Aprobada",
        "date": "2020-08-27T00:02:51-05:00"
      }
    }
    RESPONSE
  end

  def failed_refund
    <<-RESPONSE
    {
      "status": {
        "status": "FAILED",
        "reason": "BR",
        "message": "La referencia interna provista es inválida",
        "date": "2020-08-27T00:02:51-05:00"
      }
    }
    RESPONSE
  end

  def successful_capture
    <<-RESPONSE
    {
      "status": {
        "status": "OK",
        "reason": "00",
        "message": "La petición se ha procesado correctamente",
        "date": "2020-08-27T00:02:51-05:00"
      }
    }
    RESPONSE
  end

  def failed_search_transaction
    <<-RESPONSE
    {
      "status": {
        "status": "REJECTED",
        "reason": "00",
        "message": "No se ha encontrado información con los datos proporcionados",
        "date": "2020-08-27T00:02:51-05:00"
      }
    }
    RESPONSE
  end
end
