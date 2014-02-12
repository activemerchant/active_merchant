require 'test_helper'

class ConektaTest < Test::Unit::TestCase
  def setup
    @gateway = ConektaGateway.new(:login => "1tv5yJp3xnVZ7eK67m4h")

    @amount = 300

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number             => "4111111111111111",
      :verification_value => "183",
      :month              => "01",
      :year               => "2018",
      :first_name         => "Mario F.",
      :last_name          => "Moreno Reyes"
    )

    @declined_card = ActiveMerchant::Billing::CreditCard.new(
      :number             => "4000000000000002",
      :verification_value => "183",
      :month              => "01",
      :year               => "2018",
      :first_name         => "Mario F.",
      :last_name          => "Moreno Reyes"
    )

    @options = {
      :description => 'Blue clip',
      :success_url => "https://www.example.com/success",
      :failure_url => "https://www.example.com/failure",
      :address1 => "Rio Missisipi #123",
      :address2 => "Paris",
      :city => "Guerrero",
      :country => "Mexico",
      :zip => "5555",
      :name => "Mario Reyes",
      :phone => "12345678",
      :carrier => "Estafeta"
    }
  end

  def test_successful_tokenized_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, 'tok_xxxxxxxxxxxxxxxx', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal nil, response.message
    assert response.test?
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal nil, response.message
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)
    assert response = @gateway.refund(@amount, "1", @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_instance_of Response, response
    assert_equal nil, response.message
    assert response.test?
  end

  def test_unsuccessful_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_capture
    @gateway.expects(:ssl_request).returns(failed_purchase_response)
    assert response = @gateway.capture("1", @amount, @options)
    assert_failure response
    assert response.test?
  end

  def test_invalid_login
    gateway = ConektaGateway.new(:login => 'invalid_token')
    gateway.expects(:ssl_request).returns(failed_login_response)
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  def successful_purchase_response
    {
      'id' => '521b859fcfc26c0f180002d9',
      'livemode' => false,
      'created_at' => 1377535391,
      'status' => 'pre_authorized',
      'currency' => 'MXN',
      'description' => 'Blue clip',
      'reference_id' => nil,
      'failure_code' => nil,
      'failure_message' => nil,
      'object' => 'charge',
      'amount' => 300,
      'processed_at' => nil,
      'fee' => 348,
      'card' => {
        'name' => 'Mario Reyes',
        'exp_month' => '01',
        'exp_year' => '18',
        'street2' => 'Paris',
        'street3' => 'nil',
        'city' => 'Guerrero',
        'zip' => '5555',
        'country' => 'Mexico',
        'brand' => 'VISA',
        'last4' => '1111',
        'object' => 'card',
        'fraud_response' => '3d_secure_required',
        'redirect_form' => {
          'url' => 'https => //eps.banorte.com/secure3d/Solucion3DSecure.htm',
          'action' => 'POST',
          'attributes' => {
            'MerchantId' => '7376961',
            'MerchantName' => 'GRUPO CONEKTAME',
            'MerchantCity' => 'EstadodeMexico',
            'Cert3D' => '03',
            'ClientId' => '60518',
            'Name' => '7376962',
            'Password' => 'fgt563j',
            'TransType' => 'PreAuth',
            'Mode' => 'Y',
            'E1' => 'qKNKjndV9emCxuKE1G4z',
            'E2' => '521b859fcfc26c0f180002d9',
            'E3' => 'Y',
            'ResponsePath' => 'https => //eps.banorte.com/RespuestaCC.jsp',
            'CardType' => 'VISA',
            'Card' => '4111111111111111',
            'Cvv2Indicator' => '1',
            'Cvv2Val' => '183',
            'Expires' => '01/18',
            'Total' => '3.0',
            'ForwardPath' => 'http => //localhost => 3000/charges/banorte_3d_secure_response',
            'auth_token' => 'qKNKjndV9emCxuKE1G4z'
          }
        }
      }
    }.to_json
  end

  def failed_purchase_response
    {
      'message' => 'The card was declined',
      'type' => 'invalid_parameter_error',
      'param' => ''
    }.to_json
  end

  def failed_bank_purchase_response
    {
      'message' => 'The minimum purchase is 15 MXN pesos for bank transfer payments',
      'type' => 'invalid_parameter_error',
      'param' => ''
    }.to_json
  end

  def failed_refund_response
    {
      'object' => 'error',
      'type' => 200,
      'message' => 'The charge does not exist or it is not suitable for this operation'
    }.to_json
  end

  def failed_void_response
    {
      'object' => 'error',
      'type' => 200,
      'message' => 'The charge does not exist or it is not suitable for this operation'
    }.to_json
  end

  def successful_authorize_response
    {
      'id' => '521b859fcfc26c0f180002d9',
      'livemode' => false,
      'created_at' => 1377535391,
      'status' => 'pre_authorized',
      'currency' => 'MXN',
      'description' => 'Blue clip',
      'reference_id' => nil,
      'failure_code' => nil,
      'failure_message' => nil,
      'object' => 'charge',
      'amount' => 300,
      'processed_at' => nil,
      'fee' => 348,
      'card' => {
        'name' => 'Mario Reyes',
        'exp_month' => '01',
        'exp_year' => '18',
        'street2' => 'Paris',
        'street3' => 'nil',
        'city' => 'Guerrero',
        'zip' => '5555',
        'country' => 'Mexico',
        'brand' => 'VISA',
        'last4' => '1111',
        'object' => 'card',
        'fraud_response' => '3d_secure_required',
        'redirect_form' => {
          'url' => 'https => //eps.banorte.com/secure3d/Solucion3DSecure.htm',
          'action' => 'POST',
          'attributes' => {
            'MerchantId' => '7376961',
            'MerchantName' => 'GRUPO CONEKTAME',
            'MerchantCity' => 'EstadodeMexico',
            'Cert3D' => '03',
            'ClientId' => '60518',
            'Name' => '7376962',
            'Password' => 'fgt563j',
            'TransType' => 'PreAuth',
            'Mode' => 'Y',
            'E1' => 'qKNKjndV9emCxuKE1G4z',
            'E2' => '521b859fcfc26c0f180002d9',
            'E3' => 'Y',
            'ResponsePath' => 'https => //eps.banorte.com/RespuestaCC.jsp',
            'CardType' => 'VISA',
            'Card' => '4111111111111111',
            'Cvv2Indicator' => '1',
            'Cvv2Val' => '183',
            'Expires' => '01/18',
            'Total' => '3.0',
            'ForwardPath' => 'http => //localhost => 3000/charges/banorte_3d_secure_response',
            'auth_token' => 'qKNKjndV9emCxuKE1G4z'
          }
        }
      }
    }.to_json
  end

  def failed_authorize_response
    {
      'message' => 'The card was declined',
      'type' => 'invalid_parameter_error',
      'param' => ''
    }.to_json
  end

  def failed_capture_response
    {
      'object' => 'error',
      'type' => 200,
      'message' => 'The charge does not exist or it is not suitable for this operation'
    }.to_json
  end

  def failed_login_response
    {
      'object' => 'error',
      'type' => 'authentication_error',
      'message' => 'Unrecognized authentication token'
    }.to_json
  end
end
