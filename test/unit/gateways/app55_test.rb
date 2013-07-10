require 'test_helper'

class App55Test < Test::Unit::TestCase
  def setup
    @gateway = App55Gateway.new(
                 :ApiKey => 'ABC',
                 :ApiSecret => 'DEF'
               )

    @credit_card = credit_card
    @duff_card = credit_card('400030001111222')
    @amount = 100

    @options = {
      :customer => '3',
      :billing_address => address,
      :description => 'app55 active merchant unit test'
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

    assert response = @gateway.purchase(@amount, @duff_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_store_card
    @gateway.expects(:ssl_request).returns(successful_store_card)

    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert response.params["sig"]
    assert response.params["card"]["token"]
    assert_equal @credit_card.number.to_s.last(4), response.params["card"]["number"].to_s.last(4)
    assert response.test?
  end

  def test_unstore_card
    @gateway.expects(:ssl_request).returns(successful_unstore_card)

    #remove it
    assert response = @gateway.unstore("xpiWf", @options)
    assert_success response
    assert response.params["sig"]
    assert response.test?
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    <<-RESPONSE
    {"sig":"TxjO6RNAQYstte69KYQu8zmxF_8=","transaction":{"id":"130703144451_78313","description":"app55 active merchant unit test","currency":"GBP","code":"succeeded","amount":"1.00","auth_code":"06603"},"ts":"20130703134451"}
    RESPONSE
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    <<-RESPONSE
    {"error":{"message":"Invalid card number supplied.","type":"validation-error","code":197123}}
    RESPONSE
  end

  def successful_store_card
    <<-RESPONSE
    {"card":{"type":"Visa Credit","number":"411111******4242","token":"xpiWf","expiry":"10/2014"},"sig":"M7YSyOO-5hU_qq2CipxeuooCTrc=","ts":"20130703143237"}
    RESPONSE
  end

  def successful_unstore_card
    <<-RESPONSE
    {"sig":"thur144-59VXq6-8a1v3FVNxSEs=","ts":"20130703143346"}
    RESPONSE
  end
end