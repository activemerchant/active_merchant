require 'test_helper'

class OpenpayTest < Test::Unit::TestCase
  def setup
    @gateway = OpenpayGateway.new(
      key: 'key',
      merchant_id: 'merchant_id'
    )

    @credit_card = credit_card('4111111111111111')
    @amount = 100
    @refund_amount = 50

    @options = {
      order_id: '1234567890',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'tay1mauq3re4iuuk8bm4', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The card was declined', response.message
    assert response.test?
  end

  def test_successful_authorization
    @gateway.expects(:ssl_request).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert response.authorization
    assert_equal 'in_progress', response.params['status']
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, 'tubpycc6gtsk71fu3tsd')
    assert_success response
    assert_equal 'completed', response.params['status']
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_purchase_response('cancelled'))
    authorization = 'tay1mauq3re4iuuk8bm4'

    assert response = @gateway.void(authorization)
    assert_instance_of Response, response
    assert_success response

    assert_equal authorization, response.authorization
    assert_equal 'cancelled', response.params['status']
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refunded_response)

    assert response = @gateway.refund(@amount, 'tei4hnvyp4agt5ecnbow')
    assert_success response

    assert_equal 'tei4hnvyp4agt5ecnbow', response.authorization
    assert response.params['refund']
    assert_equal 'completed', response.params['status']
    assert_equal 'completed', response.params['refund']['status']
    assert response.test?
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_request).returns(generic_error_response)

    assert response = @gateway.refund(@refund_amount, 'tei4hnvyp4agt5ecnbow')
    assert_failure response
    assert !response.authorization
  end

  def test_successful_purchase_with_card_id
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, {credit_card: 'a2b79p8xmzeyvmolqfja'}, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'tay1mauq3re4iuuk8bm4', response.authorization
    assert response.test?
  end

  def test_succesful_store_new_customer_with_card
    @gateway.expects(:ssl_request).twice.returns(successful_new_customer, successful_new_card)
    @options[:email] = 'john@gmail.com'
    @options[:name] = 'John Doe'

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response
    assert_equal 2, response.responses.size

    customer_response = response.responses[0]
    assert_not_nil customer_response.params['id']

    card_response = response.responses[1]
    assert_not_nil card_response.params['id']

    assert response.test?
  end

  def test_successful_store_new_card
    @gateway.expects(:ssl_request).returns(successful_new_card)

    assert response = @gateway.store(@credit_card, customer: 'a2b79p8xmzeyvmolqfja')
    assert_success response

    assert_equal 'kgipbqixvjg3gbzowl7l', response.authorization
    assert response.test?
  end

  def test_missing_params_store
    @options[:name] = 'John Doe'

    assert_raise(ArgumentError) do
      @gateway.store(@credit_card, @options)
    end
  end

  def test_successful_unstore
    @gateway.expects(:ssl_request).returns(nil)

    assert response = @gateway.unstore('a2b79p8xmzeyvmolqfja', 'kgipbqixvjg3gbzowl7l', @options)
    assert_success response

    assert_nil response.authorization
    assert response.test?
  end

  private

  def successful_new_card
    <<-RESPONSE
{
   "type":"debit",
   "brand":"mastercard",
   "address":{
      "line1":"Av 5 de Febrero",
      "line2":"Roble 207",
      "line3":"col carrillo",
      "state":"Queretaro",
      "city":"Queretaro",
      "postal_code":"76900",
      "country_code":"MX"
   },
   "id":"kgipbqixvjg3gbzowl7l",
   "card_number":"1111",
   "holder_name":"Juan Perez Ramirez",
   "expiration_year":"20",
   "expiration_month":"12",
   "allows_charges":true,
   "allows_payouts":false,
   "creation_date":"2013-12-12T17:50:00-06:00",
   "bank_name":"DESCONOCIDO",
   "bank_code":"000",
   "customer_id":"a2b79p8xmzeyvmolqfja"
}
    RESPONSE
  end

  def successful_new_customer
    <<-RESPONSE
{
   "id":"a2b79p8xmzeyvmolqfja",
   "name":"Anacleto",
   "last_name":"Morones",
   "email":"morones.an@elllano.com",
   "phone_number":"44209087654",
   "status":"active",
   "balance":0,
   "clabe":"646180109400003235",
   "address":{
      "line1":"Camino Real",
      "line2":"Col. San Pablo",
      "state":"Queretaro",
      "city":"Queretaro",
      "postal_code":"76000",
      "country_code":"MX"
   },
   "creation_date":"2013-12-12T16:29:11-06:00"
}
    RESPONSE
  end

  def successful_refunded_response
    <<-RESPONSE
{
    "amount": 1.00,
    "authorization": "801585",
    "method": "card",
    "operation_type": "in",
    "transaction_type": "charge",
    "card": {
        "type": "debit",
        "brand": "mastercard",
        "address": {
            "line1": "1234 My Street",
            "line2": "Apt 1",
            "line3": null,
            "state": "ON",
            "city": "Ottawa",
            "postal_code": "K1C2N6",
            "country_code": "CA"
        },
        "card_number": "1111",
        "holder_name": "Longbob Longsen",
        "expiration_year": "15",
        "expiration_month": "09",
        "allows_charges": true,
        "allows_payouts": false,
        "creation_date": "2014-01-20T17:08:43-06:00",
        "bank_name": "DESCONOCIDO",
        "bank_code": "000",
        "customer_id": null
    },
    "status": "completed",
    "refund": {
        "amount": 1.00,
        "authorization": "030706",
        "method": "card",
        "operation_type": "out",
        "transaction_type": "refund",
        "status": "completed",
        "currency": "MXN",
        "id": "tspoc4u9msdbnkkhpcmi",
        "creation_date": "2014-01-20T17:08:44-06:00",
        "description": "Store Purchase",
        "error_message": null,
        "order_id": null
    },
    "currency": "MXN",
    "id": "tei4hnvyp4agt5ecnbow",
    "creation_date": "2014-01-20T17:08:43-06:00",
    "description": "Store Purchase",
    "error_message": null,
    "order_id": null
}
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
{
    "amount": 1.00,
    "authorization": "801585",
    "method": "card",
    "operation_type": "in",
    "transaction_type": "charge",
    "card": {
        "type": "debit",
        "brand": "mastercard",
        "address": null,
        "card_number": "1111",
        "holder_name": "Longbob Longsen",
        "expiration_year": "15",
        "expiration_month": "09",
        "allows_charges": true,
        "allows_payouts": false,
        "creation_date": "2014-01-18T21:01:10-06:00",
        "bank_name": "DESCONOCIDO",
        "bank_code": "000",
        "customer_id": null
    },
    "status": "completed",
    "currency": "MXN",
    "id": "tubpycc6gtsk71fu3tsd",
    "creation_date": "2014-01-18T21:01:10-06:00",
    "description": "Store Purchase",
    "error_message": null,
    "order_id": null
}
    RESPONSE
  end

  def successful_authorization_response
    <<-RESPONSE
{
    "amount": 1.00,
    "authorization": "801585",
    "method": "card",
    "operation_type": "in",
    "transaction_type": "charge",
    "card": {
        "type": "debit",
        "brand": "mastercard",
        "address": null,
        "card_number": "1111",
        "holder_name": "Longbob Longsen",
        "expiration_year": "15",
        "expiration_month": "09",
        "allows_charges": true,
        "allows_payouts": false,
        "creation_date": "2014-01-18T21:01:10-06:00",
        "bank_name": "DESCONOCIDO",
        "bank_code": "000",
        "customer_id": null
    },
    "status": "in_progress",
    "currency": "MXN",
    "id": "tubpycc6gtsk71fu3tsd",
    "creation_date": "2014-01-18T21:01:10-06:00",
    "description": "Store Purchase",
    "error_message": null,
    "order_id": null
}
      RESPONSE
  end

  def successful_purchase_response(status = 'completed')
    <<-RESPONSE
{
    "amount": 1.00,
    "authorization": "801585",
    "method": "card",
    "operation_type": "in",
    "transaction_type": "charge",
    "card": {
        "type": "debit",
        "brand": "mastercard",
        "address": {
            "line1": "1234 My Street",
            "line2": "Apt 1",
            "line3": null,
            "state": "ON",
            "city": "Ottawa",
            "postal_code": "K1C2N6",
            "country_code": "CA"
        },
        "card_number": "1111",
        "holder_name": "Longbob Longsen",
        "expiration_year": "15",
        "expiration_month": "09",
        "allows_charges": true,
        "allows_payouts": false,
        "creation_date": "2014-01-18T21:49:38-06:00",
        "bank_name": "BANCOMER",
        "bank_code": "012",
        "customer_id": null
    },
    "status": "#{status}",
    "currency": "MXN",
    "id": "tay1mauq3re4iuuk8bm4",
    "creation_date": "2014-01-18T21:49:38-06:00",
    "description": "Store Purchase",
    "error_message": null,
    "order_id": null
}
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
{
    "category": "gateway",
    "description": "The card was declined",
    "http_code": 402,
    "error_code": 3001,
    "request_id": "337cf033-9cd6-4314-a880-c71700e1625f"
}
    RESPONSE
  end

  def generic_error_response
    <<-RESPONSE
    {
        "category": "gateway",
        "description": "Generic Error Response",
        "http_code": 500,
        "error_code": 1001,
        "request_id": "b6b8241c-0bbc-4605-8c44-605b17d35aa8"
    }
    RESPONSE
  end
end
