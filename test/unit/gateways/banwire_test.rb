require 'test_helper'

class BanwireTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = BanwireGateway.new(
                 :login => 'desarrollo',
                 :currency => 'MXN')

    @credit_card = credit_card('5204164299999999',
                               :month => 11,
                               :year => 2012,
                               :verification_value => '999')
    @amount = 100

    @options = {
      :order_id => '1',
      :email => 'test@email.com',
      :billing_address => address,
      :description => 'Store purchase'
    }

    @amex_credit_card = credit_card('375932134599999',
                                    :month => 3,
                                    :year => 2017,
                                    :first_name => "Banwire",
                                    :last_name => "Test Card")
    @amex_options = {
        :order_id => '2',
        :email => 'test@email.com',
        :billing_address => address(:address1 => 'Horacio', :zip => 11560),
        :description  => 'Store purchase amex'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'test12345', response.authorization
    assert_nil response.message
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_invalid_json
    @gateway.expects(:ssl_post).returns(invalid_json_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match /Invalid response received from the Banwire API/, response.message
  end

  #American Express requires address and zipcode
  def test_successful_amex_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @amex_credit_card, @amex_options)
    end.check_request do |endpoint, data, headers|
      assert_match(/post_code=11560/, data)
    end.respond_with(successful_purchase_amex_response)

    assert_success response

    assert_equal 'test12345', response.authorization
    assert response.test?
  end

  #American Express requires address and zipcode
  def test_unsuccessful_amex_request
    @gateway.expects(:ssl_post).returns(failed_purchase_amex_response)

    assert response = @gateway.purchase(@amount, @amex_credit_card, @amex_options)
    assert_match /requeridos para pagos con AMEX/, response.message
    assert_failure response
    assert response.test?
  end

  private

  def failed_purchase_response
    <<-RESPONSE
    {"user":"desarrollo","id":"20120627190025","referencia":"12345","date":"27-06-2012 19:00:25","card":"9999","response":"ko","code":700,"message":"Pago Denegado."}
    RESPONSE
  end

  def successful_purchase_response
    <<-RESPONSE
    {"user":"desarrollo","id":"20120627190025","referencia":"12345","date":"27-06-2012 19:00:25","card":"9999","response":"ok","code_auth":"test12345","monto":"100", "cliente":"Roberto I Ramirez N"}
    RESPONSE
  end

  def failed_purchase_amex_response
    <<-RESPONSE
    {"response":"ko","code":405,"message":"Direcci\u00f3n y c\u00f3digo postal requeridos para pagos con AMEX"}
    RESPONSE
  end

  def successful_purchase_amex_response
    <<-RESPONSE
    {"user":"desarrollo","id":"20120731153834","referencia":"12345","date":"31-07-2012 15:38:34","card":"99999","response":"ok","code_auth":"test12345","monto":0.5,"client":"Banwire Test Card"}
    RESPONSE
  end

  def invalid_json_response
    <<-RESPONSE
    {"user":"desarrollo"
    RESPONSE
  end
end
