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

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @options)
    assert_success response
    assert_equal 'Sucesso', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @options)
    assert_success auth
    assert_equal 'Sucesso', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(auth.authorization, @credit_card, @options)
    assert_success capture
    assert_equal 'Requisição processada com sucesso', capture.message
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Requisição processada com sucesso', response.message
  end

  def test_successful_purchase_with_payment_slip
    assert response = @gateway.purchase(@amount, 'boleto_bancario', @options.merge(@payment_slip_options))
    assert_success response
    assert_equal 'Requisição processada com sucesso', response.message
  end

  def test_successful_purchase_with_bank_debit
    assert response = @gateway.purchase(@amount, 'banco_do_brasil', @options)
    assert_success response
    assert_equal 'Requisição processada com sucesso', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Instituição de pagamento inválida', response.message
  end

  def test_unsuccessful_authorize
    assert response = @gateway.authorize(@amount, @options.merge(:order_id => 1))
    assert_failure response
    assert_equal 'Id Próprio já foi utilizado em outra Instrução', response.message
  end

  def test_failed_capture
    assert response = @gateway.capture('error', @credit_card, @options)
    assert_failure response
    assert_equal 'Token inválido', response.message
  end

  def test_invalid_login
    gateway = MoipGateway.new(:token => '', :api_key => '')
    assert_raise ActiveMerchant::ResponseError, 'Failed with 401 Unauthorized' do
      gateway.purchase(@amount, @credit_card, @options)
    end
  end
end