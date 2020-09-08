require 'test_helper'

class RemotePlaceToPayTest < Test::Unit::TestCase
  def setup
    @default_gateway = PlaceToPayGateway.new(fixtures(:place_to_pay_default))
    @international_gateway = PlaceToPayGateway.new(fixtures(:place_to_pay_international))
    @wrong_default_gateway = PlaceToPayGateway.new(fixtures(:place_to_pay_invalid_default))
    @wrong_international_gateway = PlaceToPayGateway.new(fixtures(:place_to_pay_invalid_international))
    @amount = 100
    @valid_credit_card = credit_card('4005580000000040',
      verification_value: '237',
      month: '03',
      year: '22')
    @valid_credit_card_otp = credit_card('36545400000008',
    verification_value: '237',
    month: '03',
    year: '22')
    @valid_credit_card_for_colombia = credit_card('4111111111111111',
      verification_value: '237',
      month: '03',
      year: '22')
    @invalid_credit_card = credit_card('36545400000248',
      verification_value: '237',
      month: '03',
      year: '22')
    @expired_credit_card = credit_card('4012888888881881',
      verification_value: '237',
      month: '03',
      year: '22')
    @options = {
      'reference': 'Lucho_test_008',
      'currency': 'USD'
    }
    @options_to_capture = @options.merge({
      'payer': {
        "document": "8467451900",
        "documentType": "CC",
        "name": "Miss Delia Schamberger Sr.",
        "surname": "Wisozk",
        "email": "tesst@gmail.com",
        "mobile": "3006108300"
      },
      'otp': '000000'
    })
    @purchase_options = @options.merge({
      'payer': {
        "document": "8467451900",
        "documentType": "CC",
        "name": "Miss Delia Schamberger Sr.",
        "surname": "Wisozk",
        "email": "tesst@gmail.com",
        "mobile": "3006108300"
      },
      "reference": "Lucho_test_#{rand(1000)}",
      'description': 'some description',
      'group_code': 'P',
      'buyer': {
        "document": "8467451900",
        "documentType": "CC",
        "name": "Miss Delia Schamberger Sr.",
        "surname": "Wisozk",
        "email": "tesst@gmail.com",
        "mobile": "3006108300"
      },
      'code': 1,
      'type': 22,
      'groupCode': 'M',
      'installment': 12,
      'additional': {
        "SOME_ADDITIONAL": "http://example.com/yourcheckout"
      },
      'taxes': [
        {
          "kind": "ice",
          "amount": 4.8,
          "base": 40
        },
        {
          "kind": "valueAddedTax",
          "amount": 7.6,
          "base": 40
        }
      ],
      'details': [
        {
          "kind": "shipping",
          "amount": 2
        },
        {
          "kind": "tip",
          "amount": 2
        },
        {
          "kind": "subtotal",
          "amount": 40
        }
      ]
    })
  end

  def test_successful_authorize
    response_base_country = @default_gateway.authorize(@amount, @valid_credit_card, @options)
    response_another_country = @international_gateway.authorize(@amount, @valid_credit_card, @options)
    assert_success response_base_country
    assert_success response_another_country
    assert_equal 'La petición se ha procesado correctamente', response_base_country.message
    assert_equal 'La petición se ha procesado correctamente', response_another_country.message
  end

  def test_failled_authorize_wrong_credentials
    response_base_country = @wrong_default_gateway.authorize(@amount, @valid_credit_card, @options)
    response_another_country = @wrong_international_gateway.authorize(@amount, @invalid_credit_card, @options)
    assert_failure response_base_country
    assert_failure response_another_country
    assert_equal 'Autenticación fallida 101', response_base_country.message
    assert_equal 'Autenticación fallida 101', response_another_country.message
  end

  def test_successful_my_pi_query_card_another_country
    options = {'id': 1}
    response = @international_gateway.my_pi_query(@amount, @valid_credit_card, options)
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
  end

  def test_failed_my_pi_query_card_does_not_apply_to_3ds
    options = {'id': 1}
    response = @international_gateway.my_pi_query(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'El comercio no tiene configurados datos de 3DS', response.message
  end

  def test_successful_calculate_interests_another_country_card
    options = @options.merge({
      'code': 1,
      'type': 22,
      'groupCode': 'M',
      'installment': 12
    })
    response = @international_gateway.calculate_interests(@amount, @valid_credit_card, options)
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
  end

  def test_failled_calculate_interests_missing_params
    options = {}
    response = @international_gateway.calculate_interests(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'Referencia inválida', response.message
  end

  def test_successful_generate_otp_another_country_card
    # special credit card number for this case
    options = @options.merge({
      'reference': '5b05daa383573',
      'description': 'A payment collect example'
    })
    response = @international_gateway.generate_otp(@amount, @valid_credit_card_otp, options)
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
  end

  def test_failled_generate_otp_missing_params
    options = {}
    response = @international_gateway.generate_otp(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'Referencia inválida', response.message
  end

  def test_failled_generate_otp_card_does_not_apply
    options = @options.merge({
      'reference': '5b05daa383573',
      'description': 'A payment collect example'
    })
    response = @international_gateway.generate_otp(@amount, @valid_credit_card, options)
    assert_failure response
    assert_equal 'El servicio requerido no aplica para el medio de pago suministrado OTP Generation', response.message
  end

  def test_successful_validate_otp_ec
    options = @options.merge({
      'reference': '123456',
      'otp': '000000'
    })
    response = @international_gateway.validate_otp(@amount, @valid_credit_card_otp, options)
    assert_success response
    assert_equal 'OTP Validation successful', response.message
  end

  def test_failled_validate_otp_missing_params
    options = {}
    response = @international_gateway.validate_otp(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'Referencia inválida', response.message
  end

  def test_success_validate_otp_not_required
    options = @options.merge({
      'reference': '2110163',
      'otp': '123456'
    })
    response = @international_gateway.validate_otp(@amount, @valid_credit_card, options)
    assert_success response
    assert_equal 'OTP not required', response.message
  end

  def test_failled_validate_otp_wrong_reference_and_otp_code
    options = @options.merge({
      'reference': '2110163',
      'otp': '876543'
    })
    response = @international_gateway.validate_otp(@amount, @valid_credit_card_otp, options)
    assert_failure response
    assert_equal 'El OTP ingresado no coincide con el que se te ha provisto', response.message
  end

  def test_successful_purchase_ec
    response = @international_gateway.purchase(@amount, @valid_credit_card_otp, @purchase_options)
    assert_success response
    assert_equal 'Aprobada', response.message
  end

  def test_successful_purchase_col
    options = @purchase_options.merge({
      "currency": 'COP',
    })
    response = @default_gateway.purchase(@amount, @valid_credit_card_for_colombia, options)
    assert_success response
    assert_equal 'Aprobada', response.message
  end

  def test_failled_purchase_ec_invalid_credit_card
    response = @international_gateway.purchase(@amount, @invalid_credit_card, @purchase_options)
    assert_failure response
    assert_equal 'Rechazada', response.message
  end

  def test_failled_purchase_col_wrong_currency
    response = @default_gateway.purchase(@amount, @valid_credit_card_for_colombia,
      @purchase_options)
    assert_failure response
    assert_equal 'Código de moneda inválido o no soportado', response.message
  end

  def test_failled_purchase_col_declined_card
    options = @purchase_options.merge({
      'currency': 'COP'
    })
    response = @default_gateway.purchase(@amount, @expired_credit_card, options)
    assert_failure response
    assert_equal 'Negada, Tarjeta vencida', response.message
  end

  def test_successful_get_status_transaction
    purchase_response = @international_gateway.purchase(@amount, @valid_credit_card_otp, @purchase_options)
    options = {
      'internalReference': purchase_response.params['internalReference']
    }
    iternational_response = @international_gateway.get_status_transaction(options)
    assert_success iternational_response
    assert_equal 'Aprobada', iternational_response.message
  end

  def test_failed_get_status_transaction_wrong_reference
    options = {
      'internalReference': 34812
    }
    iternational_response = @international_gateway.get_status_transaction(options)
    response_col = @default_gateway.get_status_transaction(options)
    assert_failure iternational_response
    assert_failure response_col
    assert_equal 'No hay una transacción con el identificador provisto', iternational_response.message
    assert_equal 'No hay una transacción con el identificador provisto', response_col.message
  end

  def test_succesful_refund_transaction
    purchase_response = @international_gateway.purchase(@amount, @valid_credit_card_otp,
      @purchase_options)
    options = {
      'internalReference': purchase_response.params['internalReference'],
      'authorization': '999999',
      'action': 'reverse'
    }
    iternational_response = @international_gateway.refund(options)
    assert_success iternational_response
    assert_equal 'Aprobada', iternational_response.message
  end

  def test_failed_refund_transaction
    options = {
      'internalReference': 10446,
      'authorization': '000000',
      'action': 'reverse'
    }
    iternational_response = @international_gateway.refund(options)
    response_col = @default_gateway.refund(options)
    assert_failure iternational_response
    assert_failure response_col
    assert_equal 'La referencia interna provista es inválida', iternational_response.message
    assert_equal 'La referencia interna provista es inválida', response_col.message
  end

  def test_successful_capture
    iternational_response = @international_gateway.capture(@valid_credit_card, @options_to_capture)
    response_col = @default_gateway.capture(@valid_credit_card, @options_to_capture)
    assert_success iternational_response
    assert_success response_col
    assert_equal 'La petición se ha procesado correctamente', iternational_response.message
    assert_equal 'La petición se ha procesado correctamente', response_col.message
  end

  def test_failed_capture_nissing_otp
     options = @options_to_capture
     options.reject! {|key| key == :otp}
     iternational_response = @international_gateway.capture(@invalid_credit_card, options)
     assert_failure iternational_response
     assert_equal 'No se ha proporcionado un OTP y es necesario', iternational_response.message
   end


   def test_successful_search
    options = {
      'reference': "Lucho_test_110",
       'amount': {
         "currency": "USD"
       }
     }
     response = @international_gateway.search_transaction(@amount, options)
     assert_success response
     assert_equal 'La petición se ha procesado correctamente', response.message
   end

   def test_failled_search
    options = {
      'reference': 'TEST_20180516_182751',
       'amount': {
         "currency": "USD"
       }
     }
     iternational_response = @international_gateway.search_transaction(@amount, options)
     assert_failure iternational_response
     assert_equal 'No se ha encontrado información con los datos proporcionados', iternational_response.message
   end
end
