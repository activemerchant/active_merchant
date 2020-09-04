require 'test_helper'

class RemotePlaceToPayTest < Test::Unit::TestCase
  def setup
    @gateway_col = PlaceToPayGateway.new(fixtures(:place_to_pay_col))
    @gateway_international = PlaceToPayGateway.new(fixtures(:place_to_pay_ec))
    @wrong_gateway_col = PlaceToPayGateway.new(fixtures(:place_to_pay_invalid_col))
    @wrong_gateway_ec = PlaceToPayGateway.new(fixtures(:place_to_pay_invalid_ec))
    @amount = 100
    @valid_credit_card = credit_card('4005580000000040',
      verification_value: '237',
      month: '03',
      year: '22')
    @invalid_credit_card = credit_card('36545400000248',
      verification_value: '237',
      month: '03',
      year: '22')
    @options = {
      'reference': 'Lucho_test_008',
      'currency': 'USD'
    }
  end

  # PASS
  def test_successful_authorize
    response_base_country = @gateway_col.authorize(@amount, @valid_credit_card, @options)
    response_another_country = @gateway_international.authorize(@amount, @valid_credit_card, @options)
    assert_success response_base_country
    assert_success response_another_country
    assert_equal 'La petición se ha procesado correctamente', response_base_country.message
    assert_equal 'La petición se ha procesado correctamente', response_another_country.message
  end

  # PASS
  def test_failled_authorize_wrong_credentials
    response_base_country = @wrong_gateway_col.authorize(@amount, @valid_credit_card, @options)
    response_another_country = @wrong_gateway_ec.authorize(@amount, @invalid_credit_card, @options)
    assert_failure response_base_country
    assert_failure response_another_country
    assert_equal 'Autenticación fallida 101', response_base_country.message
    assert_equal 'Autenticación fallida 101', response_another_country.message
  end

  # FAILLED: Internal error / PASS: intermitent
  # This test do not apply to the main country: Colombia
  # def test_successful_lookup_card_another_country
  #   options = @options.merge({
  #     'returnUrl': 'https://www.placetopay.com',
  #     'description': 'Testing Payment',
  #   })
  #   # special credit card number for this case
  #   credit_card = credit_card('4147570010013074')
  #   credit_card.verification_value = '237'
  #   credit_card.month = '03'
  #   credit_card.year = '22'
  #   response = @gateway_international.lookup_card(@amount, credit_card, options)
  #   assert_success response
  #   assert_equal 'La petición se ha procesado correctamente', response.message
  # end

  # PASS
  def test_failled_lookup_card_method_card_does_not_apply_3ds
    @options[:returnUrl] = 'https://www.placetopay.com'
    @options[:description] = 'Testing Payment'
    credit_card = credit_card('36545400000248')
    credit_card.verification_value = '237'
    credit_card.month = '03'
    credit_card.year = '22'
    response = @gateway_international.lookup_card(@amount, credit_card, @options)
    assert_failure response
    assert_equal 'El comercio no tiene configurados datos de 3DS', response.message
  end

  # PASS
  def test_successful_my_pi_query_card_another_country
    # special credit card number for this case
    credit_card = credit_card('4110760000000008')
    credit_card.verification_value = '237'
    credit_card.month = '03'
    credit_card.year = '22'
    options = {'id': 1}
    response = @gateway_international.my_pi_query(@amount, credit_card, options)
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
  end

  # PASS
  def test_failed_my_pi_query_card_does_not_apply_to_3ds
    options = {'id': 1}
    response = @gateway_international.my_pi_query(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'El comercio no tiene configurados datos de 3DS', response.message
  end

  # PASS
  def test_successful_calculate_interests_another_country_card
    options = @options.merge({
      'code': 1,
      'type': 22,
      'groupCode': 'M',
      'installment': 12
    })
    response = @gateway_international.calculate_interests(@amount, @valid_credit_card, options)
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
  end

  # PASS
  def test_failled_calculate_interests_missing_params
    options = {}
    response = @gateway_international.calculate_interests(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'Referencia inválida', response.message
  end

  # PASS
  def test_successful_generate_otp_another_country_card
    # special credit card number for this case
    credit_card = credit_card('36545400000008')
    credit_card.verification_value = '237'
    credit_card.month = '03'
    credit_card.year = '22'
    options = @options.merge({
      'reference': '5b05daa383573',
      'description': 'A payment collect example'
    })
    response = @gateway_international.generate_otp(@amount, credit_card, options)
    assert_success response
    assert_equal 'La petición se ha procesado correctamente', response.message
  end

  # PASS
  def test_failled_generate_otp_missing_params
    options = {}
    response = @gateway_international.generate_otp(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'Referencia inválida', response.message
  end

  #PASS
  def test_successful_validate_otp_ec
    options = @options.merge({
      'reference': '123456',
      'otp': '000000'
    })
    credit_card = credit_card('36545400000008',
      verification_value: '237',
      month: '03',
      year: '22')
    response = @gateway_international.validate_otp(@amount, credit_card, options)
    assert_success response
    assert_equal 'OTP Validation successful', response.message
  end

  #PASS
  def test_failled_validate_otp_missing_params
    options = {}
    response = @gateway_international.validate_otp(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'Referencia inválida', response.message
  end

  #PASS
  def test_success_validate_otp_not_required
    options = @options.merge({
      'reference': '2110163',
      'otp': '123456'
    })
    response = @gateway_international.validate_otp(@amount, @valid_credit_card, options)
    assert_success response
    assert_equal 'OTP not required', response.message
  end

  #PASS
  def test_failled_validate_otp_wrong_reference_and_otp_code
    options = @options.merge({
      'reference': '2110163',
      'otp': '876543'
    })
    credit_card = credit_card('36545400000008',
      verification_value: '237',
      month: '03',
      year: '22')
    response = @gateway_international.validate_otp(@amount, credit_card, options)
    assert_failure response
    assert_equal 'El OTP ingresado no coincide con el que se te ha provisto', response.message
  end

  # PASS
  def test_successful_purchase_ec
    options = @options.merge({
      'payer': {
        "document": "8467451900",
        "documentType": "CC",
        "name": "Miss Delia Schamberger Sr.",
        "surname": "Wisozk",
        "email": "tesst@gmail.com",
        "mobile": "3006108300"
      },
      "reference": "Lucho_test_008",
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
    credit_card = credit_card('36545400000008')
    credit_card.verification_value = '237'
    credit_card.month = '03'
    credit_card.year = '22'
    response = @gateway_international.purchase(@amount, credit_card, options)
    assert_success response
    assert_equal 'Aprobada', response.message
  end

  # PASS
  def test_successful_purchase_col
    options = @options.merge({
      'payer': {
        "document": "8467451900",
        "documentType": "CC",
        "name": "Miss Delia Schamberger Sr.",
        "surname": "Wisozk",
        "email": "tesst@gmail.com",
        "mobile": "3006108300"
      },
      "currency": 'COP',
      "reference": 'test_000_debd770bb8fbabb0802fba46f361447c',
      "reference": "Lucho_test_008",
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
    credit_card = credit_card('4111111111111111',
      verification_value: '237',
      month: '03',
      year: '22')
    response = @gateway_col.purchase(@amount, credit_card, options)
    assert_success response
    assert_equal 'Aprobada', response.message
  end

  # PASS
  def test_failled_purchase_ec
    options = @options.merge({
      'payer': {
        "document": "8467451900",
        "documentType": "CC",
        "name": "Miss Delia Schamberger Sr.",
        "surname": "Wisozk",
        "email": "tesst@gmail.com",
        "mobile": "3006108300"
      },
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
      ],
      'otp': 'a8ecc59c2510a8ae27e1724ebf4647b5'
    })
    response = @gateway_international.purchase(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'Rechazada', response.message
  end

  # PASS
  def test_failled_purchase_col_wrong_currency
    options = @options.merge({
      'payer': {
        "document": "8467451900",
        "documentType": "CC",
        "name": "Miss Delia Schamberger Sr.",
        "surname": "Wisozk",
        "email": "tesst@gmail.com",
        "mobile": "3006108300"
      },
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
      ],
      'otp': 'a8ecc59c2510a8ae27e1724ebf4647b5'
    })
    response = @gateway_col.purchase(@amount, @invalid_credit_card, options)
    assert_failure response
    assert_equal 'Código de moneda inválido o no soportado', response.message
  end

  #PASS
  def test_failled_purchase_col_declined_card
    options = @options.merge({
      'payer': {
        "document": "8467451900",
        "documentType": "CC",
        "name": "Miss Delia Schamberger Sr.",
        "surname": "Wisozk",
        "email": "tesst@gmail.com",
        "mobile": "3006108300"
      },
      "currency": 'COP',
      "reference": 'test_000_debd770bb8fbabb0802fba46f361447c',
      "reference": "Lucho_test_008",
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
    credit_card = credit_card('4012888888881881',
      verification_value: '237',
      month: '03',
      year: '22')
    response = @gateway_col.purchase(@amount, credit_card, options)
    assert_failure response
    assert_equal 'Negada, Tarjeta vencida', response.message
  end

  # PASS 
  def test_successful_get_status_transaction
    options_to_ourchase = @options.merge({
      'payer': {
        "document": "8467451900",
        "documentType": "CC",
        "name": "Miss Delia Schamberger Sr.",
        "surname": "Wisozk",
        "email": "tesst@gmail.com",
        "mobile": "3006108300"
      },
      "reference": "Lucho_test_008",
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
    credit_card = credit_card('36545400000008')
    credit_card.verification_value = '237'
    credit_card.month = '03'
    credit_card.year = '22'
    response_to_purchase = @gateway_international.purchase(@amount, credit_card, options_to_ourchase)
    options = {
      'internalReference': response_to_purchase.params["internalReference"]
    }
    iternational_response = @gateway_international.get_status_transaction(options)
    assert_success iternational_response
    assert_equal 'Aprobada', iternational_response.message
  end

  # PASS
  def test_failed_get_status_transaction_wrong_reference
    options = {
      'internalReference': 34812
    }
    iternational_response = @gateway_international.get_status_transaction(options)
    response_col = @gateway_col.get_status_transaction(options)
    assert_failure iternational_response
    assert_failure response_col
    assert_equal 'No hay una transacción con el identificador provisto', iternational_response.message
    assert_equal 'No hay una transacción con el identificador provisto', response_col.message
  end

  # PASS
  def test_succesful_reverse_transaction
    options_to_ourchase = @options.merge({
      'payer': {
        "document": "8467451900",
        "documentType": "CC",
        "name": "Miss Delia Schamberger Sr.",
        "surname": "Wisozk",
        "email": "tesst@gmail.com",
        "mobile": "3006108300"
      },
      "reference": "Lucho_test_008",
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
    credit_card = credit_card('36545400000008')
    credit_card.verification_value = '237'
    credit_card.month = '03'
    credit_card.year = '22'
    response_to_purchase = @gateway_international.purchase(@amount, credit_card, options_to_ourchase)
    options = {
      'internalReference': response_to_purchase.params["internalReference"],
      'authorization': "999999",
      "action": "reverse"
    }
    iternational_response = @gateway_international.reverse_transaction(options)
    assert_success iternational_response
    assert_equal 'Aprobada', iternational_response.message
  end

  # PASS
  def test_failed_reverse_transaction
    options = {
      'internalReference': 10446,
      'authorization': "000000",
      "action": "reverse"
    }
    iternational_response = @gateway_international.reverse_transaction(options)
    response_col = @gateway_col.reverse_transaction(options)
    assert_failure iternational_response
    assert_failure response_col
    assert_equal 'La referencia interna provista es inválida', iternational_response.message
    assert_equal 'La referencia interna provista es inválida', response_col.message
  end

  # PASS
  def test_successful_tokenize
   options = @options.merge({
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
    iternational_response = @gateway_international.tokenize(@valid_credit_card, options)
    response_col = @gateway_col.tokenize(@valid_credit_card, options)
    assert_success iternational_response
    assert_success response_col
    assert_equal 'La petición se ha procesado correctamente', iternational_response.message
    assert_equal 'La petición se ha procesado correctamente', response_col.message
  end

  # PASS
  def test_failed_tokenize_nissing_otp
    options = @options.merge({
       'payer': {
         "document": "8467451900",
         "documentType": "CC",
         "name": "Miss Delia Schamberger Sr.",
         "surname": "Wisozk",
         "email": "tesst@gmail.com",
         "mobile": "3006108300"
       }
     })
     iternational_response = @gateway_international.tokenize(@invalid_credit_card, options)
     assert_failure iternational_response
     assert_equal 'No se ha proporcionado un OTP y es necesario', iternational_response.message
   end

  # failled
   def test_successful_search
    options_to_ourchase = @options.merge({
      'payer': {
        "document": "8467451900",
        "documentType": "CC",
        "name": "Miss Delia Schamberger Sr.",
        "surname": "Wisozk",
        "email": "tesst@gmail.com",
        "mobile": "3006108300"
      },
      "reference": "Lucho_test_110",
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
    credit_card = credit_card('36545400000008')
    credit_card.verification_value = '237'
    credit_card.month = '03'
    credit_card.year = '22'
    response_to_purchase = @gateway_international.purchase(@amount, credit_card, options_to_ourchase)
    options = {
      'reference': "Lucho_test_110",
       'amount': {
         "currency": "USD"
       }
     }
     iternational_response = @gateway_international.search_transaction(@amount, options)
     assert_success iternational_response
     assert_equal 'La petición se ha procesado correctamente', iternational_response.message
   end

  # PASS
   def test_failled_search
    options = {
      'reference': 'TEST_20180516_182751',
       'amount': {
         "currency": "USD"
       }
     }
     iternational_response = @gateway_international.search_transaction(@amount, options)
     assert_failure iternational_response
     assert_equal 'No se ha encontrado información con los datos proporcionados', iternational_response.message
   end
end
