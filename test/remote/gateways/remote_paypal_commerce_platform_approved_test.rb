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

    @approved_authroize_order_id = "7V123312RG0637734"
    @approved_capture_order_id = "2CJ18316FT2538839"
    @approved_authroize_order_id_for_capture = "5EU30839XL336345M"
    @approved_capture_order_id_for_refund = "0V4855580B516603L"


    @body = {}
  end

  def test_handle_approve_capture
    response = capture_order
    assert response[:status].eql?("COMPLETED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end

  def test_handle_approve_authorize
    response = @paypal_customer.handle_approve(@approved_authroize_order_id, options.merge({ operator: "authorize" }))
    assert response[:status].eql?("COMPLETED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end

  def test_do_capture_for_authorized_order
    response = @paypal_customer.handle_approve(@approved_authroize_order_id_for_capture, options.merge({ operator: "authorize" }))
    authorization_id = response[:purchase_units][0][:payments][:authorizations][0][:id]
    response = @paypal_customer.do_capture(authorization_id,options)
    assert response[:status].eql?("COMPLETED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end

  def test_refund_captured_order
    response = @paypal_customer.handle_approve(@approved_capture_order_id_for_refund,
                                               options.merge({ operator: "capture" }))
    capture_id = response[:purchase_units][0][:payments][:captures][0][:id]
    refund_order_res = @paypal_customer.refund(capture_id, options)
    assert refund_order_res[:status].eql?("COMPLETED")
    assert !refund_order_res[:id].nil?
    assert !refund_order_res[:links].blank?
  end

  private
  def capture_order
    @paypal_customer.handle_approve(@approved_capture_order_id, options.merge({ operator: "capture" }))
  end
  def options
    { headers: @headers, body: @body }
  end
end
