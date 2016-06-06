require 'test_helper'

class RemotePagarmeTest < Test::Unit::TestCase
  def setup
    @gateway = PagarmeGateway.new(fixtures(:pagarme))

    @amount = 1000

    @credit_card = credit_card('4242424242424242', {
      first_name: 'Richard',
      last_name: 'Deschamps'
    })

    @declined_card = credit_card('4242424242424242', {
      first_name: 'Richard',
      last_name: 'Deschamps',
      :verification_value => '688'
    })

    @options = {
      billing_address: address(),
      description: 'ActiveMerchant Teste de Compra'
    }

    @options_recurring = {
        order_id: '1',
        ip: '127.0.0.1',
        customer: {
            document_number: "94123506518",
            id: "71097",
            :document_number => "18152564000105",
            :name => "nome do cliente",
            :email => "eee@email.com",
            :born_at => 13121988,
            :gender => "M",
            :phone => {
                :ddi => 55,
                :ddd => 11,
                :number => 999887766
            },
            :address => {
                :street => "rua qualquer",
                :complement => "apto",
                :number => 13,
                :district => "pinheiros",
                :city => "sao paulo",
                :state => "SP",
                :zipcode => "05444040",
                :country => "Brasil"
            }
        },
        :card_number => "4901720080344448",
        :card_holder_name => "Jose da Silva",
        :card_expiration_month => "10",
        :card_expiration_year => "21",
        :card_cvv => "314",
        plan_code: 40408,
        payment_method: 'boleto',
        invoice: '1',
        merchant: 'Richard\'s',
        description: 'Store Purchase',
        email: 'suporte@pagar.me',
        billing_address: address(),
        #card_hash: "card_ciovmgj16000e3w6e879dy79m"
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transação aprovada', response.message

    # Assert metadata
    assert_equal response.params["metadata"]["description"], @options[:description]
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: '127.0.0.1',
      customer: 'Richard Deschamps',
      invoice: '1',
      merchant: 'Richard\'s',
      description: 'ActiveMerchant Teste de Compra',
      email: 'suporte@pagar.me',
      billing_address: address()
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Transação aprovada', response.message

    # Assert metadata
    assert_equal response.params["metadata"]["order_id"], options[:order_id]
    assert_equal response.params["metadata"]["ip"], options[:ip]
    assert_equal response.params["metadata"]["customer"], options[:customer]
    assert_equal response.params["metadata"]["invoice"], options[:invoice]
    assert_equal response.params["metadata"]["merchant"], options[:merchant]
    assert_equal response.params["metadata"]["description"], options[:description]
    assert_equal response.params["metadata"]["email"], options[:email]
  end

  def test_successful_purchase_without_options
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Transação aprovada', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transação recusada', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert_equal 'Transação autorizada', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Transação aprovada', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transação recusada', response.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, nil)
    assert_failure response
    assert_equal 'Não é possível capturar uma transação sem uma prévia autorização.', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Transação estornada', refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, nil)
    assert_failure response
    assert_equal 'Não é possível estornar uma transação sem uma prévia captura.', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Transação estornada', void.message
  end

  def test_failed_void
    response = @gateway.void(nil)
    assert_failure response
    assert_equal 'Não é possível estornar uma transação autorizada sem uma prévia autorização.', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Transação autorizada', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 'Transação recusada', response.message
  end

  def test_invalid_login
    gateway = PagarmeGateway.new(api_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{401 Authorization Required}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end

  # def test_successful_recurring
  #
  #   response = @gateway.recurring(@amount, @credit_card, @options_recurring)
  #
  #   assert_instance_of Response, response
  #   assert_success response
  #
  #   assert_equal 'credit_card', response.params["payment_method"]
  #   assert_equal 'paid', response.params["status"]
  #   assert_equal 'Transação aprovada', response.message
  #   assert response.test?
  # end
  #
  def test_get_invoice
    response = @gateway.invoice("502012")

    assert_instance_of Response, response
    assert_success response

    assert_equal 'credit_card', response.params['invoice'][:payment_method]
    assert_equal 'paid', response.params['invoice'][:action]
  end


  def test_get_invoice_not_exists
    response = @gateway.invoice("211502012")

    assert_instance_of Response, response
    assert_success response

    assert_equal nil, response.params['invoice'][:payment_method]
    assert_equal nil, response.params['invoice'][:action]
  end

  def test_get_invoices_not_exists
    response = @gateway.invoices('11158706')

    assert_instance_of Response, response
    assert_success response

    assert_equal 0, response.params['invoices'].size
  end

  def test_get_invoices
    response = @gateway.invoices('58706')

    assert_instance_of Response, response
    assert_success response

    assert_equal 1, response.params['invoices'].size
  end

  def test_get_payments
  response = @gateway.payments("502012")

  assert_instance_of Response, response
  assert_success response

  assert_equal 1, response.params['payments'].size

  end

  def test_get_payments_not_exists
    response = @gateway.payments("5020112")

    assert_instance_of Response, response
    assert_success response

    assert_equal 0, response.params['payments'].size

  end

  def test_get_payment
  response = @gateway.payment("502012","29006")

  assert_instance_of Response, response
  assert_success response

  assert_equal 15151, response.params['payment'][:amount]
  assert_equal 'waiting_funds', response.params['payment'][:action]
  assert_equal 29006, response.params['payment'][:id]

  end

  def test_get_payment_payment_not_exist
    response = @gateway.payment("502012","29006")

    assert_instance_of Response, response
    assert_success response

    assert_equal nil, response.params['payment']['id']
  end


  def test_get_payment_invoice_not_exist
    response = @gateway.payment("50201211","290106")

    assert_instance_of Response, response
    assert_success response

    assert_equal nil, response.params['payment']['id']
  end


  def test_update_subscription_not_exists
    params = {
        card_id: "card_ciovmgj16000e3w6e879dy79m",
        payment_method: "credit_card"
    }

    response = @gateway.update(587001, params)

    assert_instance_of Response, response
    assert_failure response

    assert_equal 'Subscription não encontrado', response.params['errors'][0]['message']
  end

  def test_update_subscription_to_Credit_card
    params = {
        card_id: "card_ciovmgj16000e3w6e879dy79m",
        payment_method: "credit_card"
    }

    response = @gateway.update(58707, params)

    assert_instance_of Response, response
    assert_success response

    assert_equal 'credit_card', response.params['payment_method']
    assert_equal 'card_ciovmgj16000e3w6e879dy79m', response.params['card']['id']
  end

  # # só da pra testar uma vez devido ir na api e voltar.
  # def test_cancel
  #   response = @gateway.cancel(58709)
  #   assert_instance_of Response, response
  #   assert_success response
  #
  #   if response.params.has_key?('status')
  #     assert_equal 'canceled', response.params['status']
  #   end
  # end
  #

  def test_cancel_already_canceled
    response = @gateway.cancel(58163)
    assert_instance_of Response, response
    assert_failure response

    assert_equal 'Assinatura já cancelada.', response.params['errors'][0]['message']
  end


end
