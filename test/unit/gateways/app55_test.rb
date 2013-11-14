require 'test_helper'

class App55Test < Test::Unit::TestCase
  def setup
    @gateway = App55Gateway.new(
      api_key: 'ABC',
      api_secret: 'DEF'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      billing_address: address,
      description: 'app55 active merchant unit test'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '130703144451_78313', response.authorization
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  def successful_purchase_response
    <<-RESPONSE
    {"sig":"TxjO6RNAQYstte69KYQu8zmxF_8=","transaction":{"id":"130703144451_78313","description":"app55 active merchant unit test","currency":"GBP","code":"succeeded","amount":"1.00","auth_code":"06603"},"ts":"20130703134451"}
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
    {"error":{"message":"Invalid card number supplied.","type":"validation-error","code":197123}}
    RESPONSE
  end
end
