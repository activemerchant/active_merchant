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

  def test_failed_create_plan
    Moip::Assinaturas::Plan.expects(:create).returns(failed_create_plan)

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
    Moip::Assinaturas::Plan.expects(:create).returns(failed_create_plan_no_period)

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
    Moip::Assinaturas::Plan.expects(:create).returns(failed_create_plan_no_amount)

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
    Moip::Assinaturas::Plan.expects(:create).returns(failed_create_plan_no_params)

    params_plan = {}

    response = @gateway.create_plan(params_plan)
    assert_failure response

    assert_equal "Erro na requisição", response.message
    assert_equal "Código do plano deve ser informado", response.params['errors'][0]['description']
    assert_true response.test?

  end

  def test_sucessful_create_plan
    Moip::Assinaturas::Plan.expects(:create).returns(successful_create_plan)

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
    assert_not_nil response.plan_code
    assert_true response.test?

  end

  def test_sucessful_create_plan_with_alerts
    Moip::Assinaturas::Plan.expects(:create).returns(successful_create_plan_with_alerts)

    params_plan = {
      days: 30,
      price: @amount,
      period: 'monthly',
      plan_code: "13311MONTLY#{rand(99999)}",
    }

    response = @gateway.create_plan(params_plan)
    assert_not_nil response.plan_code
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
    Moip::Assinaturas::Plan.expects(:update).returns(successful_update_plan)

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
    assert_not_nil response.plan_code
    assert_true response.test?

  end

  #Averiguar 
  def test_failed_update_plan
    Moip::Assinaturas::Plan.expects(:update).returns(failed_update_plan)

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
    Moip::Assinaturas::Plan.expects(:details).returns(successful_find_plan)

    code = 'PLAN-CODE-22141MONTLY'
    response = @gateway.find_plan(code)
    assert_success response

    assert_equal "ONE INVOICE FOR 1 MONTH PLAN-CODE-22141MONTLY", response.params['plan']['name']
    assert_equal code, response.params['plan']['code']
    assert_true response.test?

  end

  def test_failed_find_plan
    Moip::Assinaturas::Plan.expects(:details).returns(failed_find_plan)

    response = @gateway.find_plan(nil)
    assert_failure response

    assert_equal "not found", response.message
    assert_equal "not found", response.params['message']
    assert_true response.test?

  end

  private

  def successful_cancel_recurring_response
    { success: true }
  end

  def failed_update_plan
    {"success"=>false, "message"=>"Ocorreu um erro no retorno do webservice."}
  end

  def successful_update_plan
    {"success"=>true}
  end

  def failed_find_plan
    {:success=>false, :message =>"not found"}
  end

  def successful_find_plan
    {
      :success => true,
      :plan => {
        "creation_date"=>{
          "minute"=>2,
          "second"=>36,
          "month"=>7,
          "year"=>2016,
          "hour"=>17,
          "day"=>5
        },
        "amount"=>100,
        "max_qty"=>0,
        "setup_fee"=>0,
        "interval" => {
          "unit"=>"MONTH",
          "length"=>1
        },
        "status"=>"ACTIVE",
        "description"=>"PLAN USED TO CREATE SUBSCRIPTIONS BY EDOOLS",
        "name"=>"ONE INVOICE FOR 1 MONTH PLAN-CODE-22141MONTLY",
        "billing_cycles"=>0,
        "code"=>"PLAN-CODE-22141MONTLY",
        "trial" => {
          "enabled"=>false,
          "days"=>0,
          "hold_setup_fee"=>true
        },
        "payment_method"=>"ALL"
      }
    }
  end

  def successful_create_plan_with_alerts
    {
      success:true,
      plan: {
        message: "Plano criado com sucesso",
        "alerts"=>[
          {
            "description"=>"Atributo hold_setup_fee não informado, por default ele será considerado true.",
            "code"=>"MA102"
          },
          {
            "description"=>"Método de pagamento não informado, portanto, o método padrão será CREDIT_CARD",
            "code"=>"MA177"
          }
        ]
      },
      "code"=>"PLAN-CODE-13311MONTLY85291"
    }
  end

  def successful_create_plan
    {
      success: true,
      plan: {
        message: "Plano criado com sucesso"
      },
      code: "PLAN-CODE-22141MONTLY18125"
    }
  end

  def failed_create_plan
    {
      success: false,
      message: "Erro na requisição",
      'errors' => [
        {
          'description' => "Código do plano já utilizado. Escolha outro código",
          'code' => "MA6"
        }
      ],
      code: "PLAN-CODE-0011MONTLY"
    }
  end

  def failed_create_plan_no_period
    {
      success: false,
      message: "Erro na requisição",
      "errors"=> [
        {
          "description"=>"Unidade do intervaldo deve ser DAY, MONTH ou YEAR",
          "code"=>"MA24"
        },
        {
          "description"=>"O número do intervalo de cobranças deve ter apenas números",
          "code"=>"MA20"
        }
      ],
      "code"=>"PLAN-CODE-0011MONTLY"
    }
  end

  def failed_create_plan_no_amount
    {
      success: false,
      message: "Erro na requisição",
      "errors" => [
        {
          "description"=>"O valor deve ter apenas números",
          "code"=>"MA14"
        },
        {
          "description"=>"Unidade do intervaldo deve ser DAY, MONTH ou YEAR",
          "code"=>"MA24"
        },
        {
          "description"=>"O número do intervalo de cobranças deve ter apenas números",
          "code"=>"MA20"
        }
      ],
      "code"=>"PLAN-CODE-0011MONTLY"
    }
  end

  def failed_create_plan_no_params
    {
      success: false,
      message: "Erro na requisição",
      "errors" => [
        {
          "description"=>"Código do plano deve ser informado",
          "code"=>"MA5"
        },
        {
          "description"=>"O valor deve ter apenas números",
          "code"=>"MA14"
        },
        {
          "description"=>"Unidade do intervaldo deve ser DAY, MONTH ou YEAR",
          "code"=>"MA24"
        },
        {
          "description"=>"O número do intervalo de cobranças deve ter apenas números",
          "code"=>"MA20"
        }
      ],
      "code"=>nil}
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
