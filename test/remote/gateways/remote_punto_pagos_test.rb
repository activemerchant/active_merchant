require 'test_helper'

class RemotePuntoPagosTest < Test::Unit::TestCase
  def setup
    @now = Time.new(2018, 3, 1)
    Time.stubs(:now).returns(@now)
    @timestamp = Time.now.strftime("%a, %d %b %Y %H:%M:%S GMT")
    @config = fixtures(:punto_pagos)
    @gateway = PuntoPagosGateway.new(@config)
    @amount = 9999
    @str_amount = '100.00'
    @trx_id = 10

    @purchase_options = { trx_id: @trx_id }

    @details_options = {
      trx_id: @trx_id,
      amount: 100
    }

    @notificate_options = {
      trx_id: @trx_id,
      amount: 100,
      timestamp: @timestamp
    }
  end

  def test_successful_purchase_setup
    response = @gateway.setup_purchase(@amount, @purchase_options)
    assert_purchase_setup_success(response)
  end

  def test_successful_purchase_setup_with_payment_method
    @purchase_options[:payment_method] = :ripley

    response = @gateway.setup_purchase(@amount, @purchase_options)
    assert_purchase_setup_success(response)
  end

  def test_failed_purchase_setup_with_invalid_trx_id
    @purchase_options[:trx_id] = ''

    response = @gateway.setup_purchase(@amount, @purchase_options)
    assert_request_failure(response, '99', 'Input string was not in a correct format.')
  end

  def test_failed_purchase_setup_with_invalid_credentials
    @gateway = PuntoPagosGateway.new(key: 'X', secret: 'Y')

    response = @gateway.setup_purchase(@amount, @purchase_options)
    assert_request_failure(response, '99', 'La llave no existe')
  end

  def test_notification_with_incomplete_transaction
    purchase_response = @gateway.setup_purchase(@amount, @purchase_options)
    @notificate_options[:token] = purchase_response.token
    @notificate_options[:authorization] = build_notification_signature(purchase_response.token)

    response = @gateway.notificate(@notificate_options)
    assert_equal purchase_response.token, response[:token]
    assert_equal 'Transaccion incompleta', response[:error]
    assert_equal '99', response[:respuesta]
  end

  def test_details_for_with_failed_transaction
    purchase_response = @gateway.setup_purchase(@amount, @purchase_options)
    @details_options[:token] = purchase_response.token

    response = @gateway.details_for(@details_options)
    assert_request_failure(response, '6', 'Transaccion incompleta')
  end

  private

  def assert_purchase_setup_success(response)
    assert response.success?
    assert response.test?
    assert_equal '00', response.code
    assert_equal 'Success', response.message
    assert_nil response.error_code
    assert !response.authorization.blank?
    assert !response.token.blank?
    assert !response.trx_id.blank?
  end

  def assert_request_failure(response, code, message)
    assert !response.success?
    assert response.test?
    assert_equal code, response.code
    assert_equal message, response.message
    assert_equal 'processing_error', response.error_code
  end

  def assert_purchase_failure(response, code, message)
    assert_request_failure(response, code, message)
    assert response.authorization.blank?
    assert response.token.blank?
    assert response.trx_id.blank?
  end

  def build_notification_signature(token)
    ActiveMerchant::Billing::PuntoPagos::Authorization.new(@config).sign(
      'transaccion/notificacion',
      token,
      @trx_id,
      @str_amount,
      @timestamp
    )
  end
end
