require 'test_helper'
require File.expand_path(File.dirname(__FILE__) + '/../../../../lib/active_merchant/billing/gateways/punto_pagos/response')

class PuntoPagosResponseTest < Test::Unit::TestCase
  def setup
    @response_class = ActiveMerchant::Billing::PuntoPagos::Response

    params = [
      'token',
      'trx_id',
      'codigo_autorizacion',
      'fecha_aprobacion',
      'medio_pago',
      'medio_pago_descripcion',
      'monto',
      'num_cuotas',
      'valor_cuota',
      'tipo_cuotas',
      'numero_tarjeta',
      'numero_operacion',
      'primer_vencimiento',
      'tipo_pago'
    ].inject({}) do |result, attribute|
      result[attribute] = attribute
      result
    end

    @response = @response_class.new(nil, nil, params)
  end

  def test_attributes
    assert_equal('token', @response.token)
    assert_equal('trx_id', @response.trx_id)
    assert_equal('codigo_autorizacion', @response.auth_code)
    assert_equal('fecha_aprobacion', @response.approved_at)
    assert_equal('medio_pago', @response.payment_method)
    assert_equal('medio_pago_descripcion', @response.payment_method_description)
    assert_equal('monto', @response.amount)
    assert_equal('num_cuotas', @response.shares)
    assert_equal('valor_cuota', @response.share_value)
    assert_equal('tipo_cuotas', @response.share_type)
    assert_equal('numero_tarjeta', @response.card_number)
    assert_equal('numero_operacion', @response.operation_number)
    assert_equal('primer_vencimiento', @response.first_expiration)
    assert_equal('tipo_pago', @response.payment_type)
  end
end
