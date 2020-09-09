require 'test_helper'
require 'byebug'

class PaypalExpressRestTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @paypal_customer = ActiveMerchant::Billing::PaypalCustomerGateway.new
    params = { username: "ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXMz9q",
               password: "EKj_bMZn0CkOhOvFwJMX2WwhtCq2A0OtlOd5T-zUhKIf9WQxvgPasNX0Kr1U4TjFj8ZN6XCMF5NM30Z_" }

    options = { "Content-Type": "application/json", authorization: params }
    bearer_token = @paypal_customer.get_token(options)
    @headers = { "Authorization": "Bearer #{ bearer_token[:access_token] }", "Content-Type": "application/json" }

    @body = {
        "intent": "AUTHORIZE",
        "purchase_units": [
            {
                "reference_id": "camera_shop_seller_#{DateTime.now}",
                "amount": {
                    "currency_code": "USD",
                    "value": "25.00"
                },
                "payee": {
                    "email_address": "sb-feqsa3029697@personal.example.com"
                }
            }
        ]
    }
    @options = { headers: @headers, body: @body }
  end


  def test_set_customer_order_creation
    response = @paypal_customer.create_order(@options)
    assert response.success?
    assert response.parsed_response["status"].eql?("CREATED")
    assert !response.parsed_response["id"].nil?
    assert !response.parsed_response['links'].blank?
  end
end
