require 'test_helper'
require 'byebug'

class PaypalExpressRestTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    # @gateway = PaypalExpressRestGateway.new(fixtures(:paypal_certificate))
    @bearer_token = "A21AAGynk5olOMTJUaG-zE4Rt8Xz0vIKNuawTbhjRLG9nXTa85A8RWdJRAXa2VoPfKD1__rPLy5v5-rHJhh586Co3_MahLKPQ"
    @headers = { "Authorization": "Bearer #{ @bearer_token }", "Content-Type": "application/json" }

    @body = {
        "intent": "CAPTURE",
        "final_capture": "true",
        "purchase_units": [
            {
                "amount": {
                    "currency_code": "USD",
                    "value": "100.00"
                }
            }
        ]
    }
    @options = { headers: @headers, body: @body }
  end


  def test_set_customer_order_creation
    paypal_customer = ActiveMerchant::Billing::PaypalCustomerGateway.new
    response = paypal_customer.create_order(@options)
    assert response.success?
    assert response.parsed_response["status"].eql?("CREATED")
    assert !response.parsed_response["id"].nil?
    assert !response.parsed_response['links'].blank?
  end
end
