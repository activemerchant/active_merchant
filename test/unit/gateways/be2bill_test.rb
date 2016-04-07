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

    @refund_options = {
      :order_id     => '1',
      :description  => 'Refund Store Purchase'
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

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'A189063', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    assert response = @gateway.authorize(@amount, nil, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'A189063', response.authorization
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_reponse)

    assert response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(@amount, @credit_card, @refund_options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'A189063', response.authorization
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_reponse)

    assert response = @gateway.refund(@amount, '', @refund_options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void('A189063', @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'A189063', response.authorization
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert response = @gateway.void('', @options)
    assert_failure response
    assert response.test?
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    {"OPERATIONTYPE"=>"payment", "TRANSACTIONID"=>"A189063", "EXECCODE"=>"0000", "MESSAGE"=>"The transaction has been accepted.", "ALIAS"=>"A189063", "DESCRIPTOR"=>"RENTABILITEST"}.to_json
  end

  def successful_authorize_response
    {"OPERATIONTYPE"=>"authorization", "TRANSACTIONID"=>"A189063", "EXECCODE"=>"0000", "MESSAGE"=>"The transaction has been accepted.", "ALIAS"=>"A189063", "DESCRIPTOR"=>"RENTABILITEST"}.to_json
  end

  def successful_capture_response
    {"OPERATIONTYPE"=>"capture", "TRANSACTIONID"=>"A189063", "EXECCODE"=>"0000", "MESSAGE"=>"The transaction has been accepted.", "ALIAS"=>"A189063", "DESCRIPTOR"=>"RENTABILITEST"}.to_json
  end

  def successful_refund_response
    {"OPERATIONTYPE"=>"refund", "TRANSACTIONID"=>"A189063", "EXECCODE"=>"0000", "MESSAGE"=>"The transaction has been accepted.", "ALIAS"=>"A189063", "DESCRIPTOR"=>"RENTABILITEST"}.to_json
  end

  def successful_void_response
    {"OPERATIONTYPE"=>"stopntimes", "TRANSACTIONID"=>"A189063", "EXECCODE"=>"0000", "MESSAGE"=>"The transaction has been accepted.", "ALIAS"=>"A189063", "DESCRIPTOR"=>"RENTABILITEST"}.to_json
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    {"OPERATIONTYPE"=>"payment", "TRANSACTIONID"=>"A189063", "EXECCODE"=>"1001", "MESSAGE"=>"The parameter \"CARDCODE\" is missing.\n", "DESCRIPTOR"=>"RENTABILITEST"}.to_json
  end

  def failed_authorize_response
    {"OPERATIONTYPE"=>"authorization", "TRANSACTIONID"=>"A1515780", "EXECCODE"=>"4001", "MESSAGE"=>"The bank refused the transaction.", "DESCRIPTOR"=>"RENTABILITEST"}.to_json
  end

  def failed_capture_reponse
    {"OPERATIONTYPE"=>"capture", "EXECCODE"=>"1001", "MESSAGE"=>"The parameter \"TRANSACTIONID\" is missing."}.to_json
  end

  def failed_refund_reponse
    {"OPERATIONTYPE"=>"refund", "TRANSACTIONID"=>"A1515780", "EXECCODE"=>"4001", "MESSAGE"=>"The bank refused the transaction.", "DESCRIPTOR"=>"RENTABILITEST"}.to_json
  end

  def failed_void_response
    {"OPERATIONTYPE"=>"capture", "EXECCODE"=>"1001", "MESSAGE"=>"The parameter \"SCHEDULEID\" is missing."}.to_json
  end
end
