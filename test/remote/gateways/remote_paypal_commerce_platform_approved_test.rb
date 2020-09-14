require 'test_helper'
require 'byebug'

class PaypalExpressRestTest < Test::Unit::TestCase
  def setup
    Base.mode         = :test
    @paypal_customer  = ActiveMerchant::Billing::PaypalCommercePlateformCustomerGateway.new

    params = { username: "ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXMz9q",
               password: "EKj_bMZn0CkOhOvFwJMX2WwhtCq2A0OtlOd5T-zUhKIf9WQxvgPasNX0Kr1U4TjFj8ZN6XCMF5NM30Z_" }

    options       = { "Content-Type": "application/json", authorization: params }
    access_token  = @paypal_customer.get_token(options)
    @headers      = { "Authorization": access_token, "Content-Type": "application/json" }

    @approved_authroize_order_id              = "2X705782F01736618"
    @approved_authroize_order_id_for_capture  = "2DT35501JY607793T"
    @approved_authroize_order_id_for_void     = "3T212397204450437"
    @approved_authorize_order_id_for_ppcp     = "61G33078M85140919"

    @approved_capture_order_id                = "2UW60478X0823492E"
    @approved_capture_order_id_for_refund     = "16P87453EJ0248013"
    @approved_capture_order_id_for_ppcp       = "27328531KT105745W"


    @body = {}
  end

  def test_handle_approve_capture_direct_merchant
    response = capture_order(@approved_capture_order_id)
    assert response[:status].eql?("COMPLETED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end

  def test_handle_approve_capture_ppcp
    response = capture_order(@approved_capture_order_id_for_ppcp)
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

  def test_do_capture_for_authorized_order_direct_merchant
    response = @paypal_customer.handle_approve(@approved_authroize_order_id_for_capture, options.merge({ operator: "authorize" }))
    authorization_id = response[:purchase_units][0][:payments][:authorizations][0][:id]
    response = @paypal_customer.do_capture(authorization_id,options)
    assert response[:status].eql?("COMPLETED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end

  def test_do_capture_for_authorized_order_ppcp
    response = @paypal_customer.handle_approve(@approved_authorize_order_id_for_ppcp, options.merge({ operator: "authorize" }))
    authorization_id = response[:purchase_units][0][:payments][:authorizations][0][:id]
    @body.update(
        "payment_instruction": {
            "disbursement_mode": "INSTANT",
            "platform_fees": [
                {
                    "amount": {
                        "currency_code": "USD",
                        "value": "10.00"
                    },
                    "payee": {
                        "email_address": "sb-jnxjj3033194@business.example.com"
                    }
                }
            ]
        }
    )
    response = @paypal_customer.do_capture(authorization_id,options)
    @body.delete("payment_instruction")
    assert response[:status].eql?("COMPLETED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end

  def test_refund_captured_order
    response = capture_order(@approved_capture_order_id_for_refund)
    capture_id        = response[:purchase_units][0][:payments][:captures][0][:id]
    refund_order_res  = @paypal_customer.refund(capture_id, options)
    assert refund_order_res[:status].eql?("COMPLETED")
    assert !refund_order_res[:id].nil?
    assert !refund_order_res[:links].blank?
  end

  def test_void_authorized_order
    response = @paypal_customer.handle_approve(@approved_authroize_order_id_for_void, options.merge({ operator: "authorize" }))
    authorization_id = response[:purchase_units][0][:payments][:authorizations][0][:id]
    void_response = @paypal_customer.void(authorization_id, options)
    assert void_response.empty?
  end

  private
  def capture_order(order_id)
    @paypal_customer.handle_approve(order_id, options.merge({ operator: "capture" }))
  end
  def options
    { headers: @headers, body: @body }
  end
end
