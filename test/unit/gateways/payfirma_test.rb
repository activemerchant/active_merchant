require 'test_helper'

class PayfirmaTest < Test::Unit::TestCase
  def setup
    @gateway = PayfirmaGateway.new(
      :login => 'login',
      :password => 'password'
    )

    @credit_card = credit_card('4111111111111111', :verification_value => '123')
    @approved_amount = 100
    @declined_amount = 200
  end

  def test_successful_authorization
    @gateway.expects(:ssl_request).returns(successful_authorization_response)

    assert response = @gateway.authorize(@approved_amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '2237197', response.authorization
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.authorize(@approved_amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '2237196', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    assert response = @gateway.purchase(@declined_amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '2237198', response.authorization
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    assert response = @gateway.purchase(@approved_amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '2237202', response.authorization
  end

  def test_successful_store
    @gateway.expects(:ssl_request).returns(successful_store_response)

    assert response = @gateway.store(@credit_card, :email => 'Longbob@example.com')
    assert_instance_of Response, response
    assert_success response
    assert_equal '0|0', response.authorization
  end

  def test_successful_unstore
    @gateway.expects(:ssl_request).returns(successful_unstore_response)

    assert response = @gateway.unstore('0|0')
    assert_instance_of Response, response
    assert_success response
  end

  def test_amount_style
    assert_equal '10.34', @gateway.send(:amount, 1034)

    assert_raise(ArgumentError) do
      @gateway.send(:amount, '10.34')
    end
  end

  def test_supported_countries
    assert_equal ['CA', 'US'], PayfirmaGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :diners_club, :jcb], PayfirmaGateway.supported_cardtypes
  end

  private

  def successful_authorization_response
    <<-RESPONSE
{"type": "authorize", "result": "approved", "result_bool": true, "card_type": "visa", "amount": "1.00", "transaction_id": "2237197", "suffix": "1111", "avs": "_", "cvv2": "_", "auth_code": "SPLKD", "email": "", "first_name": "Longbob", "last_name": "Longsen", "address1": "", "address2": "", "city": "", "province": "", "country": "", "postal_code": "", "company": "", "telephone": "", "description": "", "order_id": "", "invoice_id": "", "custom_id": ""}
    RESPONSE
  end

  def successful_purchase_response
    <<-RESPONSE
{"type": "sale", "result": "approved", "result_bool": true, "card_type": "visa", "amount": "1.00", "transaction_id": "2237196", "suffix": "1111", "avs": "_", "cvv2": "_", "auth_code": "YMURJ", "email": "", "first_name": "Longbob", "last_name": "Longsen", "address1": "", "address2": "", "city": "", "province": "", "country": "", "postal_code": "", "company": "", "telephone": "", "description": "", "order_id": "", "invoice_id": "", "custom_id": ""}
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
{"type": "authorize", "result": "declined", "result_bool": false, "card_type": "visa", "amount": "2.00", "transaction_id": "2237198", "suffix": "1111", "avs": "_", "cvv2": "_", "auth_code": "", "email": "", "first_name": "Longbob", "last_name": "Longsen", "address1": "", "address2": "", "city": "", "province": "", "country": "", "postal_code": "", "company": "", "telephone": "", "description": "", "order_id": "", "invoice_id": "", "custom_id": ""}
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
{"type": "refund", "result": "approved", "result_bool": true, "card_type": "other", "amount": "1.00", "transaction_id": "2237202", "suffix": "1111", "avs": "", "cvv2": "", "auth_code": "", "email": "", "first_name": "", "last_name": "", "address1": "", "address2": "", "city": "", "province": "", "country": "", "postal_code": "", "company": "", "telephone": "", "description": "", "order_id": "", "invoice_id": "", "custom_id": ""}
    RESPONSE
  end

  def successful_store_response
    <<-RESPONSE
{"lookupid": 0, "email": "Longbob@example.com", "first_name": "Longbob", "last_name": "Longsen", "cards": [{"card_lookup_id": 0, "default": true, "card_expiry": "12/18", "card_suffix": "1111", "card_description": null}]}
    RESPONSE
  end

  def successful_unstore_response
    <<-RESPONSE
{"result": "Success", "result_bool": true, "message": "Customer payment data deleted"}
    RESPONSE
  end
end
