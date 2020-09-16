require 'test_helper'
require 'byebug'

class PaypalExpressRestTest < Test::Unit::TestCase
  def setup
    Base.mode         = :test
    @paypal_customer  = ActiveMerchant::Billing::PaypalCommercePlatformGateway.new

    params = { username: "ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXMz9q",
               password: "EKj_bMZn0CkOhOvFwJMX2WwhtCq2A0OtlOd5T-zUhKIf9WQxvgPasNX0Kr1U4TjFj8ZN6XCMF5NM30Z_" }

    options       = { "Content-Type": "application/json", authorization: params }
    access_token  = @paypal_customer.get_token(options)
    @headers      = { "Authorization": access_token, "Content-Type": "application/json" }

    @approved_authroize_order_id                            = "5P820709R1513241E"
    @approved_authroize_order_id_for_capture                = "90P32070AN822850T"
    @approved_authroize_order_id_for_void                   = "67948351JY195100F"
    @approved_authorize_order_id_for_capture_ppcp           = "9U0775177H892072L"

    @approved_capture_order_id                              = "06D984636T553381R"
    @approved_capture_order_id_for_refund                   = "41C219142W2497150"
    @approved_capture_order_id_for_ppcp                     = "32C76544FD9217427"

    @approved_delayed_capture_order_id_for_capture          = "67U39950VY142733G"
    @approved_delayed_capture_order_id_for_capture_ppcp     = "539846926F7063801"

    @approved_delayed_authorize_order_id_for_capture        = "0T579286DN9310115"
    @approved_delayed_authorize_order_id_for_capture_ppcp   = "9ND37409CB3232456"

    @approved_delayed_capture_order_id_for_disburse         = "31R95402NH875082T"
    @approved_delayed_authorize_order_id_for_disburse       = "6FF92286BP500124Y"


    @approved_capture_order_id_for_get                      = "2N479927956739445"
    @approved_capture_order_id_for_get_refund               = "4KM278190P145982L"
    @approved_authorize_order_id_for_get                    = "182969752D966232Y"
    @order_id_for_get                                       = "817565224U7700521"


    @body = body
    @capture_body = capture_body
    @additional_params = {
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
    }

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
    response = authorize_order(@approved_authroize_order_id)
    assert response[:status].eql?("COMPLETED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end

  def test_do_capture_for_authorized_order_direct_merchant
    response         = authorize_order(@approved_authroize_order_id_for_capture)
    authorization_id = response[:purchase_units][0][:payments][:authorizations][0][:id]
    response         = do_capture_order(authorization_id)
    assert response[:status].eql?("COMPLETED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end

  def test_do_capture_for_authorized_order_ppcp
    response         = authorize_order(@approved_authorize_order_id_for_capture_ppcp)
    authorization_id = response[:purchase_units][0][:payments][:authorizations][0][:id]
    response         = do_capture_order(authorization_id, "PPCP")
    assert response[:status].eql?("COMPLETED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end

  def test_refund_captured_order
    response          = capture_order(@approved_capture_order_id_for_refund)
    capture_id        = response[:purchase_units][0][:payments][:captures][0][:id]
    refund_order_res  = @paypal_customer.refund(capture_id, options)
    assert refund_order_res[:status].eql?("COMPLETED")
    assert !refund_order_res[:id].nil?
    assert !refund_order_res[:links].blank?
  end

  def test_void_authorized_order
    response         = authorize_order(@approved_authroize_order_id_for_void)
    authorization_id = response[:purchase_units][0][:payments][:authorizations][0][:id]
    void_response    = @paypal_customer.void(authorization_id, options)
    assert void_response.empty?
  end

  # def test_get_order_details
  #   response = @paypal_customer.get_order_details(@order_id_for_get, options)
  #   assert !response[:status].nil?
  #   assert !response[:id].nil?
  #   assert !response[:links].blank?
  # end
  #
  # def test_get_capture_order_details
  #   response          = capture_order(@approved_capture_order_id_for_get)
  #   capture_id        = response[:purchase_units][0][:payments][:captures][0][:id]
  #   response          = @paypal_customer.get_capture_details(capture_id, options)
  #   assert !response[:status].nil?
  #   assert !response[:id].nil?
  #   assert !response[:links].blank?
  # end
  #
  # def test_get_authorization_details
  #   response = authorize_order(@approved_authorize_order_id_for_get)
  #   authorization_id = response[:purchase_units][0][:payments][:authorizations][0][:id]
  #   response  = @paypal_customer.get_authorization_details(authorization_id, options)
  #   assert !response[:status].nil?
  #   assert !response[:id].nil?
  #   assert !response[:links].blank?
  # end
  #
  # def test_get_refund_details
  #   response          = capture_order(@approved_capture_order_id_for_get_refund)
  #   capture_id        = response[:purchase_units][0][:payments][:captures][0][:id]
  #   response          = @paypal_customer.refund(capture_id, options)
  #   refund_id         = response[:id]
  #   response          = @paypal_customer.get_refund_details(refund_id, options)
  #   assert !response[:status].nil?
  #   assert !response[:id].nil?
  #   assert !response[:links].blank?
  # end

  #       <- ************** To be confirmed ************** ->
  # def test_disburse_for_capture_order
  #     @body.update(
  #         :reference_id =>  "capture_id",
  #         :reference_type => "TRANSACTION_ID"
  #     )
  #     disburse_order_res  = @paypal_customer.disburse(options)
  #     @body.delete(:reference_id)
  #     @body.delete(:reference_type)
  #     puts disburse_order_res
  # end

  # def test_disburse_for_authorize_order
  #     response = @paypal_customer.handle_approve(@approved_delayed_authorize_order_id_for_disburse,
  #                                                options.merge({ operator: "authorize" }))
  #     authorization_id = response[:purchase_units][0][:payments][:authorizations][0][:id]
  #
  #     response = @paypal_customer.do_capture(authorization_id,options)
  #     @body.delete("payment_instruction")
  #     capture_id = response[:id]
  #     @body.update(
  #       :reference_id =>  capture_id,
  #       :reference_type => "TRANSACTION_ID"
  #     )
  #     disburse_order_res  = @paypal_customer.disburse(options)
  #     @body.delete("reference_id")
  #     @body.delete("reference_type")
  #     puts disburse_order_res
  # end
  #
  # def test_do_capture_for_delayed_authorized_order_direct_merchant
  #   response = @paypal_customer.handle_approve(@approved_delayed_authorize_order_id_for_capture, options.merge({ operator: "authorize" }))
  #   authorization_id = response[:purchase_units][0][:payments][:authorizations][0][:id]
  #   @body.update(
  #       "payment_instruction": {
  #           "disbursement_mode": "DELAYED"
  #       }
  #   )
  #   response = @paypal_customer.do_capture(authorization_id,options)
  #   @body.delete("payment_instruction")
  #   assert response[:status].eql?("COMPLETED")
  #   assert !response[:id].nil?
  #   assert !response[:links].blank?
  # end
  #
  # def test_do_capture_for_delayed_authorized_order_ppcp
  #   response = @paypal_customer.handle_approve(@approved_delayed_authorize_order_id_for_capture_ppcp, options.merge({ operator: "authorize" }))
  #   authorization_id = response[:purchase_units][0][:payments][:authorizations][0][:id]
  #   @body.update(
  #       "payment_instruction": {
  #           "disbursement_mode": "DELAYED",
  #           "platform_fees": [
  #               {
  #                   "amount": {
  #                       "currency_code": "USD",
  #                       "value": "10.00"
  #                   },
  #                   "payee": {
  #                       "email_address": "sb-jnxjj3033194@business.example.com"
  #                   }
  #               }
  #           ]
  #       }
  #   )
  #   response = @paypal_customer.do_capture(authorization_id,options)
  #   @body.delete("payment_instruction")
  #   assert response[:status].eql?("COMPLETED")
  #   assert !response[:id].nil?
  #   assert !response[:links].blank?
  # end
  #
  # def test_handle_approve_delayed_capture_direct_merchant
  #   response = capture_order(@approved_delayed_capture_order_id_for_capture)
  #   assert response[:status].eql?("COMPLETED")
  #   assert !response[:id].nil?
  #   assert !response[:links].blank?
  # end
  #
  # def test_handle_approve_delayed_capture_ppcp
  #   response = capture_order(@approved_delayed_capture_order_id_for_capture_ppcp)
  #   assert response[:status].eql?("COMPLETED")
  #   assert !response[:id].nil?
  #   assert !response[:links].blank?
  # end

  private
  def capture_order(order_id)
    @paypal_customer.handle_approve(order_id, options.merge({ operator: "capture" }))
  end
  def authorize_order(order_id)
    @paypal_customer.handle_approve(order_id, options.merge({ operator: "authorize" }))
  end
  def do_capture_order(authorization_id, mode="DIRECT")
    if mode.eql?("PPCP")
      @body.update(
        @additional_params
      )
    else
      @body.delete("payment_instruction")
    end
    @body.merge!(capture_body)
    response = @paypal_customer.do_capture(authorization_id,options)
    @body = body
    response
  end
  def options
    { headers: @headers, body: @body }
  end
  def capture_body
    {
        "amount": {
            "value": "25.00",
            "currency_code": "USD"
        },
        "invoice_id": "invoice_number_#{DateTime.now}",
        "final_capture": true,
    }
  end
  def body
    {

    }
  end
end
