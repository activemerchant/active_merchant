require 'test_helper'

class RemoteIuguTest < Test::Unit::TestCase
  def setup
    @gateway = IuguGateway.new(fixtures(:iugu))

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4012888888881881')
    @new_credit_card = credit_card('5555555555554444')

    @options = {
      test: true,
      email: 'test@test.com',
      plan_identifier: 'familia',
      ignore_due_email: true,
      due_date: 10.days.from_now,
      description: 'Test Description',
      items: [ { price_cents: 100, quantity: 1, description: 'ActiveMerchant Test Purchase'},
               { price_cents: 100, quantity: 2, description: 'ActiveMerchant Test Purchase'} ],
      address: { email: 'test@test.com',
                 street: 'Street',
                 number: 1,
                 city: 'Test',
                 state: 'SP',
                 country: 'Brasil',
                 zip_code: '12122-0001' },
     payer: { name: 'Test Name',
              cpf_cnpj: "12312312312",
              phone_prefix: '11',
              phone: '12121212',
              email: 'test@test.com' }
    }

    @options_force_cc = @options.merge(payable_with: 'credit_card')
    @options_for_subscription = { plan_identified: 'silver' }
  end

  def test_successful_purchase_with_credit_card
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response

    assert response.authorization
    assert response.test

    assert_equal 'test@test.com', response.params['email']
    assert_equal 300, response.params["items_total_cents"]
    assert_equal 2, response.params["items"].size
    assert_equal response.authorization, response.params["id"]
    assert_match(/iugu\.com/, response.params["secure_url"])
  end

  def test_successful_authorize_with_bank_slip
    assert response = @gateway.authorize(@amount, nil, @options)

    assert_success response

    assert response.authorization
    assert response.test
    assert response.message.blank?
    assert response.params['pdf']
    assert response.params['url']
    assert response.params['invoice_id']

    assert_equal response.authorization, response.params['invoice_id']
    assert_match(/iugu\.com/, response.params["url"])
    assert_match(/iugu\.com/, response.params["pdf"])
  end

  def test_successful_authorize_with_credit_card
    assert response = @gateway.authorize(@amount, @credit_card, @options_force_cc)

    assert_success response

    assert response.authorization
    assert response.test
    assert response.params['pdf']
    assert response.params['url']
    assert response.params['invoice_id']

    assert_equal response.message, 'Autorizado'
    assert_equal response.authorization, response.params['invoice_id']
    assert_match(/iugu\.com/, response.params["url"])
    assert_match(/iugu\.com/, response.params["pdf"])
  end

  def test_successful_capture_with_credit_card
    assert response = @gateway.authorize(@amount, @credit_card, @options_force_cc)
    assert response = @gateway.capture(@amount, response.authorization, {test: true})

    assert_success response

    assert response.params['id']
    assert response.params['email']
    assert response.authorization
    assert response.test
  end

  def test_declined_purchase_with_credit_card
    assert response = @gateway.purchase(@amount, @declined_card, @options)

    assert_failure response

    assert response.test
    assert_block do
      ["Transaction declined", "Transação negada"].include?(response.message)
    end
  end

  def test_declined_authorize_with_credit_card
    assert response = @gateway.purchase(@amount, @declined_card, @options)

    assert_failure response

    assert response.test
    assert_equal "Transação negada", response.message
  end

  def test_successful_store
    response = @gateway.store_client(@options)
    store_options = @options.merge(customer: response.authorization)
    assert response = @gateway.store(@credit_card, store_options)

    assert_success response

    assert response.params['id']
    assert response.params['customer_id']

    assert_equal response.authorization, response.params["id"]
  end

  def test_successful_unstore
    response = @gateway.store_client(@options)
    store_options = @options.merge(customer: response.authorization)
    response = @gateway.store(@credit_card, store_options)
    unstore_options = { id: response.params['id'], customer: response.params['customer_id'] }
    assert response = @gateway.unstore(unstore_options)

    assert_success response

    assert response.params['id']
  end

  def test_successful_store_client
    assert response = @gateway.store_client(@options)
    assert_success response

    assert response.params['id']
    assert response.params['email']

    assert_equal response.authorization, response.params["id"]
  end

  def test_successful_unstore_client
    assert response = @gateway.store_client(@options)
    assert response = @gateway.unstore_client(id: response.authorization)
    assert_success response

    assert response.params['id']
    assert response.params['email']
  end

  def test_successful_generate_token_from_card
    assert response = @gateway.generate_token(@credit_card, @options)
    assert response.is_a?(String)
  end

  def test_successful_generate_token_from_token
    assert response = @gateway.generate_token('test_token', @options)
    assert 'test_token', response
  end

  def test_successful_subscribe
    assert response = @gateway.store_client(@options)
    assert response = @gateway.subscribe(@options.merge(customer: response.authorization))

    assert_success response
  end

  def test_successful_subscribe_and_unsubscribe
    assert response = @gateway.store_client(@options)
    assert response = @gateway.subscribe(@options.merge(customer: response.authorization))
    assert response = @gateway.unsubscribe(id: response.authorization)

    assert_success response
  end

  def test_successful_subscribe_and_suspend
    assert response = @gateway.store_client(@options)
    assert response = @gateway.subscribe(@options.merge(customer: response.authorization))
    assert response = @gateway.suspend_subscription(id: response.authorization)
    assert response.params['suspended']

    assert_success response
  end

  def test_successful_subscribe_and_suspend_and_unsubscribe
    assert response = @gateway.store_client(@options)
    assert response = @gateway.subscribe(@options.merge(customer: response.authorization))

    assert response = @gateway.suspend_subscription(id: response.authorization)
    assert_success response

    assert response = @gateway.unsubscribe(id: response.authorization)
    assert_success response
  end

  def test_successful_subscribe_and_suspend_and_activate
    assert response = @gateway.store_client(@options)
    assert response = @gateway.subscribe(@options.merge(customer: response.authorization))

    assert response = @gateway.suspend_subscription(id: response.authorization)
    assert_success response

    assert response = @gateway.activate_subscription(id: response.authorization)
    assert_success response
  end

  def test_successful_subscribe_and_suspend_and_activate_and_unsubscribe
    assert response = @gateway.store_client(@options)
    assert response = @gateway.subscribe(@options.merge(customer: response.authorization))

    assert response = @gateway.suspend_subscription(id: response.authorization)
    assert_success response

    assert response = @gateway.activate_subscription(id: response.authorization)
    assert_success response

    assert response = @gateway.activate_subscription(id: response.authorization)
    assert_success response
  end

  def test_successful_subscribe_and_change
    assert response = @gateway.store_client(@options)
    assert response = @gateway.subscribe(@options.merge(customer: response.authorization))

    change_params = { id: response.authorization, plan_identifier: 'silver' }
    assert response = @gateway.change_subscription(change_params)
    assert_equal 'silver', response.params['plan_identifier']

    assert_success response
  end
end
