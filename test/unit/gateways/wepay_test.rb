require 'test_helper'

class WepayTest < Test::Unit::TestCase
  def setup
    @gateway = WepayGateway.new(
                            :client_id => 'client_id',
                            :account_id => 'account_id',
                            :access_token => 'access_token',
                            :use_staging => true
               )

    @credit_card = credit_card
    @amount = 20000
    @options = {
      :amount            => '24.95',
      :short_description => 'A brand new soccer ball',
      :type              => 'GOODS'
    }
  end


  def test_successful_purchase
    @gateway.expects(:ssl_post).at_most(2).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 1117213582, response.authorization
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).at_most(2).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_failure response
    assert response.test?
  end

  def test_successful_purchase_with_token
    @gateway.expects(:ssl_post).at_most(2).returns(successful_purchase_response)

    payment_method = "1422891921"
    assert response = @gateway.purchase(@amount, payment_method, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 1117213582, response.authorization
    assert response.test?
  end

  def test_unsuccessful_purchase_with_token
    @gateway.expects(:ssl_post).at_most(2).returns(failed_purchase_response)

    payment_method = "1422891921"
    assert response = @gateway.purchase(@amount, payment_method, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal "refunded", response.params[:state.to_s]
    assert response.test?
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "invalid_request", response.params[:error.to_s]
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).at_most(2).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_authorize
    @gateway.expects(:ssl_post).at_most(2).returns(failed_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_failure response
    assert_equal "invalid_request", response.params[:error.to_s]
    assert response.test?
  end

  def test_successful_authorize_with_token
    @gateway.expects(:ssl_post).at_most(2).returns(successful_authorize_response)

    payment_method = "1422891921"
    assert response = @gateway.authorize(@amount, payment_method, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_authorize_with_token
    @gateway.expects(:ssl_post).at_most(2).returns(failed_authorize_response)

    payment_method = "1422891921"
    assert response = @gateway.authorize(@amount, payment_method, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "invalid_request", response.params[:error.to_s]
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).at_most(2).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal "captured", response.params[:state.to_s]
    assert response.test?
  end

  def test_unsuccessful_capture
    @gateway.expects(:ssl_post).at_most(2).returns(failed_capture_response)

    assert response = @gateway.capture(@amount, @options)
    assert_failure response
    assert_equal "invalid_request", response.params[:error.to_s]
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void(@amount, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal "cancelled", response.params[:state.to_s]
    assert response.test?
  end

  def test_unsuccessful_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert response = @gateway.void(@amount, @options)
    assert_failure response
    assert_equal "invalid_request", response.params[:error.to_s]
    assert response.test?
  end

  def test_successful_add_card
    @gateway.expects(:ssl_post).returns(successful_add_card_response)

    assert response = @gateway.add_card(@credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal "new", response.params[:state.to_s]
    assert_equal 3322208138, response.authorization
    assert response.test?
  end

  def test_unsuccessful_add_card
    @gateway.expects(:ssl_post).returns(failed_add_card_response)

    assert response = @gateway.add_card(@credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "invalid_request", response.params[:error.to_s]
    assert response.test?
  end

  private

  def successful_add_card_response
    "{\"credit_card_id\": 3322208138,\"state\": \"new\"}"
  end

  def failed_add_card_response
    "{\"error\": \"invalid_request\",\"error_description\": \"Invalid credit card number\",\"error_code\": 1003}"
  end

  def successful_purchase_response
    "{\"checkout_id\":1117213582,\"checkout_uri\":\"https:\/\/stage.wepay.com\/api\/checkout\/1117213582\/974ff0c0\"}"
  end

  def failed_purchase_response
    "{\"error\":\"access_denied\",\"error_description\":\"invalid account_id, account does not exist or does not belong to user\",\"error_code\":3002}"
  end

  def successful_refund_response
    "{\"checkout_id\":1852898602,\"state\":\"refunded\"}"
  end

  def failed_refund_response
    "{\"error\":\"invalid_request\",\"error_description\":\"refund_reason parameter is required\",\"error_code\":1004}"
  end

  def successful_void_response
    "{\"checkout_id\":225040456,\"state\":\"cancelled\"}"
   end

  def failed_void_response
    "{\"error\":\"invalid_request\",\"error_description\":\"this checkout has already been cancelled\",\"error_code\":4004}"
  end

  def successful_authorize_response
    "{\"checkout_id\":640816095,\"checkout_uri\":\"https:\/\/stage.wepay.com\/api\/checkout\/640816095\/974ff0c0\"}"
  end

  def failed_authorize_response
    "{\"error\":\"invalid_request\",\"error_description\":\"checkout type parameter must be either GOODS, SERVICE, DONATION, or PERSONAL\",\"error_code\":1003}"
  end

  def successful_capture_response
    "{\"checkout_id\":1852898602,\"state\":\"captured\"}"
  end

  def failed_capture_response
    "{\"error\":\"invalid_request\",\"error_description\":\"Checkout object must be in state 'Reserved' to capture. Currently it is in state captured\",\"error_code\":4004}"
  end

end
