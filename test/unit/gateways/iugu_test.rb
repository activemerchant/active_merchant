require 'test_helper'

class IuguTest < Test::Unit::TestCase
  def setup
    @gateway = IuguGateway.new(:login => 'login')

    @credit_card = credit_card('4242424242424242')
    @amount = 400
    @refund_amount = 200

    @token_string = 'test_token'

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

  def test_successful_store_client
    @gateway.expects(:ssl_request).returns(successful_store_client_response)

    assert response = @gateway.store_client(@options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'successful_authorization', response.authorization
    assert response.test?
  end

  def test_successful_store_with_card
    @gateway.expects(:generate_token).returns('test_payment_token')
    @gateway.expects(:ssl_request).returns(successful_store_response)

    store_options = @options.merge(customer: 'customer_test')
    assert response = @gateway.store(@credit_card, store_options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'successful_authorization', response.authorization
    assert response.test?
  end

  def test_successful_store_with_token
    @gateway.expects(:ssl_request).returns(successful_store_response)

    store_options = @options.merge(customer: 'customer_test_id')
    assert response = @gateway.store('test_payment_token', store_options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'successful_authorization', response.authorization
    assert response.test?
  end

  def test_failed_store_without_customer
    assert_raises KeyError do
      @gateway.store('test_payment_token', @options)
    end
  end

  def test_successful_authorization_with_token
    @gateway.expects(:ssl_request).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, 'test_payment_token', @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'successful_authorization', response.authorization
    assert response.test?
  end

  def test_successful_authorization_with_customer
    @gateway.expects(:ssl_request).returns(successful_authorization_response)

    authorize_options = @options.merge(customer_payment_method_id: 'test_payment_id')
    assert response = @gateway.authorize(@amount, nil, authorize_options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'successful_authorization', response.authorization
    assert response.test?
  end

  def test_successful_authorization_with_bank_slip
    @gateway.expects(:ssl_request).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, nil, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'successful_authorization', response.authorization
    assert response.test?
  end

  def test_failed_authorization_without_email
    @options.delete(:email)

    assert_raises KeyError do
      @gateway.authorize(@amount, nil, @options)
    end
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)
    assert response = @gateway.capture(@amount, 'test_invoice' , test: true)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'successful_authorization', response.authorization
    assert response.test?
  end

  def test_successful_purchase
    auth_response = stub('authorization' => 'successful_authorization', 'success?' => true)

    @gateway.expects(:authorize).returns(auth_response)
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    assert response = @gateway.purchase(@amount, 'test_payment_token' , @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'successful_authorization', response.authorization
    assert response.test?
  end

  def test_successful_generate_token
    @gateway.expects(:ssl_request).returns(successful_generate_token_response)

    assert token = @gateway.generate_token(@credit_card, @options)
    assert_instance_of String, token

    assert_equal 'test_token_id', token
  end

  def test_successful_generate_token_with_string
    @gateway.expects(:ssl_request).never

    assert token = @gateway.generate_token('test_token_id', @options)
    assert_instance_of String, token

    assert_equal 'test_token_id', token
  end

  def test_successful_subscribe
    @gateway.expects(:ssl_request).returns(successful_subscribe_response)

    assert response = @gateway.subscribe(@options.merge(customer: 'test_customer'))
    assert_instance_of Response, response

    assert_equal 'successful_authorization', response.authorization
    assert response.test?
  end

  def test_failed_subscribe_without_customer
    assert_raises KeyError do
      @gateway.subscribe(@options)
    end
  end

  private
  def successful_store_client_response
    <<-RESPONSE
      {
        "id": "successful_authorization",
        "email": "test@test.com",
        "created_at": "2013-11-18T14:58:30-02:00",
        "updated_at": "2013-11-18T14:58:30-02:00"
      }
    RESPONSE
  end

  def successful_store_response
    <<-RESPONSE
    {
      "id": "successful_authorization",
      "description": "Test Description",
      "item_type": "credit_card",
      "data": {
        "holder_name": "Test Name",
        "display_number": "XXXX-XXXX-XXXX-4242",
        "brand": "visa"
      }
    }
    RESPONSE
  end

  def successful_authorization_response
    <<-RESPONSE
    {
      "success": true,
      "message": "Autorizado",
      "invoice_id": "successful_authorization"
    }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
			{
					"id": "successful_authorization",
					"due_date": "2015-04-07",
					"currency": "BRL",
					"discount_cents": null,
					"email": "email@email.com"
			}
    RESPONSE
  end

  def successful_generate_token_response
    <<-RESPONSE
      {
          "id": "test_token_id",
          "method": "credit_card"
      }
    RESPONSE
  end

  def successful_subscribe_response
    <<-RESPONSE
			{
					"id": "successful_authorization",
					"suspended": false,
					"plan_identifier": "id1",
					"price_cents": 200,
					"currency": "BRL"
			}
    RESPONSE
  end
end

