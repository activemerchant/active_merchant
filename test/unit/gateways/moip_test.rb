require 'test_helper'

class MoipTest < Test::Unit::TestCase
  def setup
    @gateway = MoipGateway.new(
        username: 'name',
        password: 'password'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
        :order_id => generate_unique_id,
        :reason   => 'Moip active merchant unit test',
        :customer => {
            :name  => 'Guilherme Bernardino',
            :email => 'Guibernardino@me.com',
            :id    => 1
        },
        :address => {
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
        :credit_card => {
            :installments       => 1,
            :birthday           => '01/01/1990',
            :phone              => '1131654020',
            :identity_document  => '52211670695',
            :buyer_cpf          => '23725576025'
        }
    }
  end

  def test_successful_purchase
    omit("Fix this test")
    @gateway.expects(:ssl_request).twice.returns(successful_authenticate_response, successful_pay_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 207695, response.authorization
    assert response.test?
  end

  def test_successful_canceled_query
    omit("Fix this test")
    @gateway.expects(:ssl_request).once.returns(canceled_query_response)

    assert response = @gateway.query('0000.0005.3227')
    assert_instance_of Response, response
    assert_success response

    assert_equal 'Cancelado', response.message[:status]
    assert_equal 'PolÃ­tica do banco emissor', response.message[:description]
    assert_equal '5', response.message[:code]
    assert_equal '0000.0005.3227', response.authorization
    assert response.test?
  end

  def test_successful_ok_query
    omit("Fix this test")
    @gateway.expects(:ssl_request).once.returns(ok_query_response)

    assert response = @gateway.query('0000.0005.3227')
    assert_instance_of Response, response
    assert_success response

    assert_equal 'Confirmado', response.message[:status]
    assert_equal '4', response.message[:code]
    assert_equal '0000.0005.3227', response.authorization
    assert response.test?
  end

  def test_successful_authenticate
    @gateway.expects(:ssl_request).returns(successful_authenticate_response)

    assert response = @gateway.send(:authenticate, @amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'O2H021S410S2U1F4K1C7G5E455T1E0B882F0V0Z0K0B0F0C4G4I7J4S7H083', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_request).twice.returns(successful_authenticate_response,failed_pay_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_authenticate
    @gateway.expects(:ssl_request).returns(unsuccessful_authenticate_response)

    assert response = @gateway.send(:authenticate, @amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_cancel_recurring
    Moip::Assinaturas::Subscription.expects(:cancel).returns(successful_cancel_recurring_response)
    response = @gateway.cancel_recurring('subscription_code')
    assert_success response
    assert_equal 'cancel', response.subscription_action
    assert_equal 'subscription_code', response.authorization
  end

  private

  def successful_cancel_recurring_response
    { success: true }
  end

  def successful_authenticate_response
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
  def successful_pay_response
    '?({"Status":"EmAnalise","Codigo":0,"CodigoRetorno":"","TaxaMoIP":"0.46","StatusPagamento":"Sucesso","Classificacao":{"Codigo":999,"Descricao":"Nao suportado no ambiente Sandbox"},"CodigoMoIP":207695,"Mensagem":"Requisicao processada com sucesso","TotalPago":"1.00"})'
  end

  # Place raw failed response from gateway here
  def failed_pay_response
    '?({"Codigo":901,"StatusPagamento":"Falha","Mensagem":"Instituicao de pagamento invalida"})'
  end

  def unsuccessful_authenticate_response
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

  def canceled_query_response
    <<-XML
      <ns1:ConsultarTokenResponse xmlns:ns1="http://www.moip.com.br/ws/alpha/">
      <RespostaConsultar>
          <ID>201204021046430860000000379674</ID>
          <Status>Sucesso</Status>
          <Autorizacao>
              <Pagador>
                  <Nome>Nome Sobrenome</Nome>
                  <Email>teste@labs.moip.com.br</Email>
              </Pagador>
              <EnderecoCobranca>
                  <Logradouro>Av. Brigadeiro Faria Lima</Logradouro>
                  <Numero>2927</Numero>
                  <Complemento>8° Andar</Complemento>
                  <Bairro>Jardim Paulistao</Bairro>
                  <CEP>01452000</CEP>
                  <Cidade>Sao Paulo</Cidade>
                  <Estado>SP</Estado>
                  <Pais>BRA</Pais>
                  <TelefoneFixo>(11)2222-3333</TelefoneFixo>
              </EnderecoCobranca>
              <Recebedor>
                  <Nome>Moip - Integraçao</Nome>
                  <Email>exemplo@labs.moip.com.br</Email>
              </Recebedor>
              <Pagamento>
                  <Data>2012-04-02T10:44:57.000-03:00</Data>
                  <TotalPago Moeda="BRL">1.00</TotalPago>
                  <TaxaParaPagador Moeda="BRL">0.00</TaxaParaPagador>
                  <TaxaMoIP Moeda="BRL">0.46</TaxaMoIP>
                  <ValorLiquido Moeda="BRL">0.54</ValorLiquido>
                  <FormaPagamento>CartaoDeCredito</FormaPagamento>
                  <InstituicaoPagamento>Visa</InstituicaoPagamento>
                  <Status Classificacao="Política do banco emissor " Tipo="5">
                      Cancelado
                  </Status>
                  <Parcela>
                      <TotalParcelas>1</TotalParcelas>
                  </Parcela>
                  <CodigoMoIP>0000.0005.3227</CodigoMoIP>
              </Pagamento>
          </Autorizacao>
      </RespostaConsultar>
      </ns1:ConsultarTokenResponse>
    XML
  end

  def ok_query_response
    <<-XML
      <ns1:ConsultarTokenResponse xmlns:ns1="http://www.moip.com.br/ws/alpha/">
      <RespostaConsultar>
          <ID>201204021046430860000000379674</ID>
          <Status>Sucesso</Status>
          <Autorizacao>
              <Pagador>
                  <Nome>Nome Sobrenome</Nome>
                  <Email>teste@labs.moip.com.br</Email>
              </Pagador>
              <EnderecoCobranca>
                  <Logradouro>Av. Brigadeiro Faria Lima</Logradouro>
                  <Numero>2927</Numero>
                  <Complemento>8° Andar</Complemento>
                  <Bairro>Jardim Paulistao</Bairro>
                  <CEP>01452000</CEP>
                  <Cidade>Sao Paulo</Cidade>
                  <Estado>SP</Estado>
                  <Pais>BRA</Pais>
                  <TelefoneFixo>(11)2222-3333</TelefoneFixo>
              </EnderecoCobranca>
              <Recebedor>
                  <Nome>Moip - Integraçao</Nome>
                  <Email>exemplo@labs.moip.com.br</Email>
              </Recebedor>
              <Pagamento>
                  <Data>2012-04-02T10:44:57.000-03:00</Data>
                  <TotalPago Moeda="BRL">1.00</TotalPago>
                  <TaxaParaPagador Moeda="BRL">0.00</TaxaParaPagador>
                  <TaxaMoIP Moeda="BRL">0.46</TaxaMoIP>
                  <ValorLiquido Moeda="BRL">0.54</ValorLiquido>
                  <FormaPagamento>CartaoDeCredito</FormaPagamento>
                  <InstituicaoPagamento>Visa</InstituicaoPagamento>
                  <Status Tipo="4">
                      Confirmado
                  </Status>
                  <Parcela>
                      <TotalParcelas>1</TotalParcelas>
                  </Parcela>
                  <CodigoMoIP>0000.0005.3227</CodigoMoIP>
              </Pagamento>
          </Autorizacao>
      </RespostaConsultar>
      </ns1:ConsultarTokenResponse>
    XML
  end
end
