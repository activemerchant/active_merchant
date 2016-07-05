# coding: utf-8
require 'test_helper'

class RemoteMoipTest < Test::Unit::TestCase

  def setup
    @gateway = MoipGateway.new(fixtures(:moip))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('6011000990139424', brand: 'discover')

    @options = {
      :order_id => generate_unique_id,
      :reason   => 'Moip active merchant remote test',
      :payer => {
        :name  => 'Guilherme Bernardino',
        :email => 'Guibernardino@me.com',
        :id    => 1
      },
      :billing_address => {
        :address1     => 'Av. Brigadeiro Faria Lima',
        :address2     => '8° Andar',
        :number       => '2927',
        :neighborhood => 'Jardim Paulistano',
        :city         => 'São Paulo',
        :state        => 'SP',
        :zip          => '01452-000',
        :country      => 'BRA',
        :phone        => '1131654020'
      },
      :creditcard => {
        :installments      => 1,
        :birthday          => '01/01/1990',
        :phone             => '1131654020',
        :identity_document => '52211670695',
      }
    }

    @payment_slip_options = {
      :payment_slip => {
        :expiration_days => 3,
        :instruction_line_1 => 'Instruction line 1',
        :instruction_line_2 => 'Instruction line 2',
        :instruction_line_3 => 'Instruction line 3'
      }
    }
  end

  def test_successful_authenticate
    omit("Skipping... because this test is broken")
    assert response = @gateway.send(:authenticate, @amount, @credit_card, @options)
    assert_success response
    assert_equal 'Sucesso', response.message
  end

  def test_authenticate_and_pay
    omit("Skipping... because this test is broken")
    assert auth = @gateway.send(:authenticate, @amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Sucesso', auth.message
    assert auth.authorization

    payment = { :payment_method => @credit_card }
    my_options = @options.merge(payment)
    assert pay = @gateway.send(:pay, @amount, auth.authorization, my_options)
    assert_success pay
    assert_equal 'Requisição processada com sucesso', pay.message
  end

  def test_successful_purchase
    omit("Skipping... because this test is broken")
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Requisição processada com sucesso', response.message
  end

  def test_successful_purchase_with_payment_slip
    omit("Skipping... because this test is broken")
    assert response = @gateway.purchase(@amount, 'boleto_bancario', @options.merge(@payment_slip_options))
    assert_success response
    assert_equal 'Requisição processada com sucesso', response.message
  end

  def test_successful_purchase_with_bank_debit
    omit("Skipping... because this test is broken")
    assert response = @gateway.purchase(@amount, 'banco_do_brasil', @options)
    assert_success response
    assert_equal 'Requisição processada com sucesso', response.message
  end

  def test_unsuccessful_purchase
    omit("Skipping... because this test is broken")
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Instituição de pagamento inválida', response.message
  end

  def test_unsuccessful_authenticate
    omit("Skipping... because this test is broken")
    assert response = @gateway.send(:authenticate, @amount, @credit_card, @options.merge(:order_id => 1))
    assert_failure response
    assert_equal 'Id Próprio já foi utilizado em outra Instrução', response.message
  end

  def test_failed_pay
    omit("Skipping... because this test is broken")
    payment = { :payment_method => @credit_card }
    my_options = @options.merge(payment)
    assert response = @gateway.send(:pay, @amount, 'error', my_options)
    response.message
    assert_equal 'Token inválido', response.message
  end

  def test_invalid_login
    omit("Skipping... because this test is broken")
    gateway = MoipGateway.new(:token => '', :api_key => '')
    assert_raise ActiveMerchant::ResponseError, 'Failed with 401 Unauthorized' do
      gateway.purchase(@amount, @credit_card, @options)
    end
  end

  def test_failed_create_plan
    params_plan = {
      days: 30,
      price: @amount,
      period: 'monthly',
      plan_code: '0011MONTLY'
    }

    response = @gateway.create_plan(params_plan)
    assert_failure response

    assert_equal "Erro na requisição", response.message
    assert_equal "Código do plano já utilizado. Escolha outro código", response.params['errors'][0]['description']
    assert_true response.test?

  end

  def test_failed_create_plan_no_period
    params_plan = {
      plan_code: '0011MONTLY',
      price: 100
    }

    response = @gateway.create_plan(params_plan)
    assert_failure response

    assert_equal "Erro na requisição", response.message
    assert_equal "Unidade do intervaldo deve ser DAY, MONTH ou YEAR", response.params['errors'][0]['description']
    assert_true response.test?

  end

  def test_failed_create_plan_no_amount
    params_plan = {
      plan_code: '0011MONTLY'
    }

    response = @gateway.create_plan(params_plan)
    assert_failure response

    assert_equal "Erro na requisição", response.message
    assert_equal "O valor deve ter apenas números", response.params['errors'][0]['description']
    assert_true response.test?

  end

  def test_failed_create_plan_no_params
    params_plan = {}

    response = @gateway.create_plan(params_plan)
    assert_failure response

    assert_equal "Erro na requisição", response.message
    assert_equal "Código do plano deve ser informado", response.params['errors'][0]['description']
    assert_true response.test?

  end

  def test_sucessful_create_plan
    params_plan = {
      days: 30,
      price: @amount,
      period: 'monthly',
      plan_code: "22141MONTLY#{rand(99999)}",
      hold_setup_fee: true,
      payment_method: 'ALL'
    }

    response = @gateway.create_plan(params_plan)
    assert_success response

    assert_equal "Plano criado com sucesso", response.message
    assert_true response.test?

  end

  def test_sucessful_create_plan_with_alerts
    params_plan = {
      days: 30,
      price: @amount,
      period: 'monthly',
      plan_code: "13311MONTLY#{rand(99999)}",
    }

    response = @gateway.create_plan(params_plan)
    assert_success response

    plan_response = response.params['plan']

    assert_equal "Plano criado com sucesso", response.message
    assert_equal 2, plan_response['alerts'].size

    assert_equal "Atributo hold_setup_fee não informado, por default ele será considerado true.", plan_response['alerts'][0]['description']
    assert_equal "MA102", plan_response['alerts'][0]['code']
    assert_equal "Método de pagamento não informado, portanto, o método padrão será CREDIT_CARD", plan_response['alerts'][1]['description']
    assert_equal "MA177", plan_response['alerts'][1]['code']

    assert_true response.test?
  end

  def test_successful_update_plan
    params_plan = {
      days: 30,
      price: @amount,
      period: 'monthly',
      plan_code: 'PLAN-CODE-22141MONTLY',
    }

    response = @gateway.update_plan(params_plan)
    assert_success response

    assert_equal "Plano atualizado com sucesso.", response.message
    assert_true response.params['success']
    assert_true response.test?

  end

  def test_failed_update_plan
    params_plan = {
      days: 30,
      price: @amount,
      period: 'monthly',
    }

    response = @gateway.update_plan(params_plan)
    assert_failure response

    assert_equal "Erro ao atualizar plano.", response.message
    assert_equal "Ocorreu um erro no retorno do webservice.", response.params['message']
    assert_false response.params['success']
    assert_true response.test?

  end

  def test_successful_find_plan
    code = 'PLAN-CODE-22141MONTLY'
    response = @gateway.find_plan(code)
    assert_success response

    assert_equal "ONE INVOICE FOR 1 MONTH PLAN-CODE-22141MONTLY", response.params['plan']['name']
    assert_equal code, response.params['plan']['code']
    assert_true response.test?

  end

  def test_failed_find_plan
    response = @gateway.find_plan(nil)
    assert_failure response

    assert_equal "not found", response.message
    assert_equal "not found", response.params['message']
    assert_true response.test?

  end

end
