require 'test_helper'

class Be2billTest < Test::Unit::TestCase
  def setup
    @gateway = Be2billGateway.new(
                 :login    => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id        => '1',
      :billing_address => address,
      :description     => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal 'A189063', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    {"OPERATIONTYPE"=>"payment", "TRANSACTIONID"=>"A189063", "EXECCODE"=>"0000", "MESSAGE"=>"The transaction has been accepted.", "ALIAS"=>"A189063", "DESCRIPTOR"=>"RENTABILITEST"}.to_json
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    {"OPERATIONTYPE"=>"payment", "TRANSACTIONID"=>"A189063", "EXECCODE"=>"1001", "MESSAGE"=>"The parameter \"CARDCODE\" is missing.\n", "DESCRIPTOR"=>"RENTABILITEST"}.to_json
  end
end
