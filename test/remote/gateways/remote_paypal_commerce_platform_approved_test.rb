require 'test_helper'
require 'byebug'

class PaypalExpressRestTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @paypal_customer = ActiveMerchant::Billing::PaypalCommercePlateformCustomerGateway.new

    params = { username: "ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXMz9q",
               password: "EKj_bMZn0CkOhOvFwJMX2WwhtCq2A0OtlOd5T-zUhKIf9WQxvgPasNX0Kr1U4TjFj8ZN6XCMF5NM30Z_" }

    options = { "Content-Type": "application/json", authorization: params }
    bearer_token = @paypal_customer.get_token(options)
    @headers = { "Authorization": "Bearer #{ bearer_token[:access_token] }", "Content-Type": "application/json" }

    @approved_authroize_order_id = "5MK62365AY576800F"
    @approved_capture_order_id = "4X929828DR249194J"

    @body = {}

  end

  def test_handle_approve_capture
    options = { headers: @headers, body: @body }
    response = @paypal_customer.handle_approve(@approved_capture_order_id,
                                               "capture",options)
    assert response.success?
    assert response.parsed_response["status"].eql?("COMPLETED")
    assert !response.parsed_response["id"].nil?
    assert !response.parsed_response['links'].blank?
  end

  def test_handle_approve_authorize
    options = { headers: @headers, body: @body }
    response = @paypal_customer.handle_approve(@approved_authroize_order_id,
                                               "authorize",options)
    assert response.success?
    assert response.parsed_response["status"].eql?("COMPLETED")
    assert !response.parsed_response["id"].nil?
    assert !response.parsed_response['links'].blank?
  end

end
