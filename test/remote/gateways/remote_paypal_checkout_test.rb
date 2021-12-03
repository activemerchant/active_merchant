require "test_helper"

class PaypalExpressRestTest < Test::Unit::TestCase
  def setup
    Base.mode               = :test
    @gateway                = ActiveMerchant::Billing::PaypalCheckoutGateway.new(fixtures(:ppcp))
    @ppcp_credentials       = fixtures(:ppcp)

    @order_options = {
        'purchase_units': [
            {
                'amount': {
                    'currency_code': 'USD',
                    'value': 1000
                }
            }
        ]
    }

    @card_order_options = {
        "payment_source": {
            "card": {
                "name": "John Doe",
                "number": @ppcp_credentials[:card_number],
                "expiry": "#{ @ppcp_credentials[:year] }-#{ @ppcp_credentials[:month] }",
                "security_code": @ppcp_credentials[:cvc]
            }
        }
    }
  end
  
  def test_get_order_details
    response      = @gateway.create_order("CAPTURE", @order_options)
    order_id      = response.params["id"]
    response      = @gateway.get_order_details(order_id)
    assert_success response
    assert_equal order_id, response.params["id"]
  end

  def test_create_access_token_when_valid_credentials_then_success
    response      = @gateway.create_access_token()
    assert_success response
    assert response.params["access_token"] != nil
  end

  def test_create_access_token_when_invalid_credentials_then_failure
    invalid_credentials = {
        "client_id": "dummy",
        "client_secret": "dummy"
    }
    temp_gateway  = ActiveMerchant::Billing::PaypalCheckoutGateway.new(invalid_credentials)
    response      = temp_gateway.create_access_token()
    assert_failure response
  end

  def test_get_capture_details
    response   = @gateway.create_order("CAPTURE", @order_options)
    order_id   = response.params["id"]
    response   = @gateway.capture(order_id, @card_order_options)
    capture_id = response.params["purchase_units"][0]["payments"]["captures"][0]["id"]
    response   = @gateway.get_capture_details(capture_id)
    assert_success response
    success_status_assertions(response, "COMPLETED")
  end

  def test_get_authorization_details
    response         = @gateway.create_order("AUTHORIZE", @order_options)
    order_id         = response.params["id"]
    response         = @gateway.authorize(order_id, @card_order_options)
    authorization_id = response.params["purchase_units"][0]["payments"]["authorizations"][0]["id"]
    response         = @gateway.get_authorization_details(authorization_id)
    assert_success response
    success_status_assertions(response, "CREATED")
  end

  def test_get_refund_details
    response        = @gateway.create_order("CAPTURE", @order_options)
    order_id        = response.params["id"]
    response        = @gateway.capture(order_id, @card_order_options)
    capture_id      = response.params["purchase_units"][0]["payments"]["captures"][0]["id"]
    response        = @gateway.refund(capture_id)
    refund_id       = response.params["id"]
    response        = @gateway.get_refund_details(refund_id)
    assert_success response
    success_status_assertions(response, "COMPLETED")
  end

  def test_create_capture_order
    response = @gateway.create_order("CAPTURE", @order_options)
    success_status_assertions(response, "CREATED")
  end

  def test_create_authorize_order
    response = @gateway.create_order("AUTHORIZE", @order_options)
    success_status_assertions(response, "CREATED")
  end

  def test_capture_order_with_card
    response = @gateway.create_order("CAPTURE", @order_options)
    order_id = response.params["id"]
    response = @gateway.capture(order_id, @card_order_options)
    success_status_assertions(response, "COMPLETED")
  end

  def test_authorize_order_with_card
    response = @gateway.create_order("AUTHORIZE", @order_options)
    order_id = response.params["id"]
    response = @gateway.authorize(order_id, @card_order_options)
    success_status_assertions(response, "COMPLETED")
  end

  def test_capture_authorized_order_with_card
    response         = @gateway.create_order("AUTHORIZE", @order_options)
    order_id         = response.params["id"]
    response         = @gateway.authorize(order_id, @card_order_options)
    authorization_id = response.params["purchase_units"][0]["payments"]["authorizations"][0]["id"]
    response         = @gateway.do_capture(authorization_id)
    success_status_assertions(response, "COMPLETED")
  end

  def test_refund_captured_order_with_card
    response        = @gateway.create_order("CAPTURE", @order_options)
    order_id        = response.params["id"]
    response        = @gateway.capture(order_id, @card_order_options)
    capture_id      = response.params["purchase_units"][0]["payments"]["captures"][0]["id"]
    refund_response = @gateway.refund(capture_id)
    success_status_assertions(refund_response, "COMPLETED")
  end

  def test_void_authorized_order_with_card
    response         = @gateway.create_order("AUTHORIZE", @order_options)
    order_id         = response.params["id"]
    response         = @gateway.authorize(order_id, @card_order_options)
    authorization_id = response.params["purchase_units"][0]["payments"]["authorizations"][0]["id"]
    void_response    = @gateway.void(authorization_id)
    success_empty_assertions(void_response)
  end

  private

  # Assertions private methods

  def success_status_assertions(response, status)
    assert_success response
    assert_equal status, response.params["status"]
    assert !response.params["id"].nil?
    assert !response.params["links"].nil?
  end

  def success_empty_assertions(response)
    assert_success response
    assert_empty   response.params
  end
end
