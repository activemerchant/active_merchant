require 'test_helper'
require 'byebug'

class PaypalExpressRestTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @paypal_customer = ActiveMerchant::Billing::PaypalCustomerGateway.new
    params = { username: "ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXMz9q",
               password: "EKj_bMZn0CkOhOvFwJMX2WwhtCq2A0OtlOd5T-zUhKIf9WQxvgPasNX0Kr1U4TjFj8ZN6XCMF5NM30Z_" }

    params = { username: "AeLico9_Zr8qxYi5jO78egnG7wgSEz8-yQDk0sLDplQTBc_NvCpVSqBjpw2fw6bYZsNJyoZezWCBks4G",
               password: "EG3CEcnR73U55aTP6Q5mGFZusEsNzn-H7HpAebiF1JeLFQh4AdTiJ393VerSXKXDK_j_NYMBv5g5PpgW" }


    options = { "Content-Type": "application/json", authorization: params }
    bearer_token = @paypal_customer.require!(options)
    @headers = { "Authorization": "Bearer #{ bearer_token[:access_token] }", "Content-Type": "application/json" }

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
