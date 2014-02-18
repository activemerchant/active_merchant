# coding: utf-8
require 'test_helper'

class MoipTest < Test::Unit::TestCase
  def setup
    @gateway = MoipGateway.new(
        :token => 'token',
        :api_key => 'key'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
        :order_id => generate_unique_id,
        :reason   => 'Moip active merchant unit test',
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
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).twice.returns(successful_authorize_response, successful_capture_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 207695, response.authorization
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'O2H021S410S2U1F4K1C7G5E455T1E0B882F0V0Z0K0B0F0C4G4I7J4S7H083', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_request).twice.returns(successful_authorize_response,failed_capture_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_authorize
    @gateway.expects(:ssl_request).returns(unsuccessful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  def successful_authorize_response
    <<-XML
        <ns1:EnviarInstrucaoUnicaResponse xmlns:ns1="http://www.moip.com.br/ws/alpha/">
          <Resposta>
            <ID>201402141754510820000004474703</ID>
            <Status>Sucesso</Status>
            <Token>O2H021S410S2U1F4K1C7G5E455T1E0B882F0V0Z0K0B0F0C4G4I7J4S7H083</Token>
          </Resposta>
        </ns1:EnviarInstrucaoUnicaResponse>
    XML
  end

  # Place raw successful response from gateway here
  def successful_capture_response
    '?({"Status":"EmAnalise","Codigo":0,"CodigoRetorno":"","TaxaMoIP":"0.46","StatusPagamento":"Sucesso","Classificacao":{"Codigo":999,"Descricao":"Nao suportado no ambiente Sandbox"},"CodigoMoIP":207695,"Mensagem":"Requisicao processada com sucesso","TotalPago":"1.00"})'
  end

  # Place raw failed response from gateway here
  def failed_capture_response
    '?({"Codigo":901,"StatusPagamento":"Falha","Mensagem":"Instituicao de pagamento invalida"})'
  end

  def unsuccessful_authorize_response
    <<-XML
      <ns1:EnviarInstrucaoUnicaResponse xmlns:ns1="http://www.moip.com.br/ws/alpha/">
        <Resposta>
           <ID>201402151733229990000004478630</ID>
           <Status>Falha</Status>
           <Erro Codigo="102">Id Pr\xF3prio j\xE1 foi utilizado em outra Instru\xE7\xE3o</Erro>
        </Resposta>
      </ns1:EnviarInstrucaoUnicaResponse>
    XML
  end
end