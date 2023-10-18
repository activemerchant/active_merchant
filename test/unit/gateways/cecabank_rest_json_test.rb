require 'test_helper'

class CecabankJsonTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CecabankJsonGateway.new(
      merchant_id: '12345678',
      acquirer_bin: '12345678',
      terminal_id: '00000003',
      cypher_key: 'enc_key'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      description: 'Store Purchase'
    }
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '12004172282310181802446007000#1#100', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_failure response
    assert_equal '27', response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, 'reference', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '12204172322310181826516007000#1#100', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)
    response = @gateway.capture(@amount, 'reference', @options)

    assert_failure response
    assert_equal '807', response.error_code
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '12004172192310181720006007000#1#100', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_equal '27', response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    assert response = @gateway.refund(@amount, 'reference', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '12204172352310181847426007000#1#100', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    assert response = @gateway.refund(@amount, 'reference', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)

    assert response = @gateway.void('12204172352310181847426007000#1#10', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '14204172402310181906166007000#1#10', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    assert response = @gateway.void('reference', @options)
    assert_failure response
    assert response.test?
  end

  private

  def successful_authorize_response
    <<~RESPONSE
      {
        "cifrado":"SHA2",
        "parametros":"eyJudW1BdXQiOiIxMDEwMDAiLCJyZWZlcmVuY2lhIjoiMTIwMDQxNzIyODIzMTAxODE4MDI0NDYwMDcwMDAiLCJjb2RBdXQiOiIwMDAifQ==",
        "firma":"2271f18614f9e3bf1f1d0bde7c23d2d9b576087564fd6cb4474f14f5727eaff2",
        "fecha":"231018180245479",
        "idProceso":"106900640-9da0de26e0e81697f7629566b99a1b73"
      }
    RESPONSE
  end

  def failed_authorize_response
    <<~RESPONSE
      {
        "fecha":"231018180927186",
        "idProceso":"106900640-9cfe017407164563ca5aa7a0877d2ade",
        "codResult":"27"
      }
    RESPONSE
  end

  def successful_capture_response
    <<~RESPONSE
      {
        "cifrado":"SHA2",
        "parametros":"eyJudW1BdXQiOiIxMDEwMDAiLCJyZWZlcmVuY2lhIjoiMTIyMDQxNzIzMjIzMTAxODE4MjY1MTYwMDcwMDAiLCJjb2RBdXQiOiI5MDAifQ==",
        "firma":"9dead8ef2bf1f82cde1954cefaa9eca67b630effed7f71a5fd3bb3bd2e6e0808",
        "fecha":"231018182651711",
        "idProceso":"106900640-5b03c604fd76ecaf8715a29c482f3040"
      }
    RESPONSE
  end

  def failed_capture_response
    <<~RESPONSE
      {
        "fecha":"231018183020560",
        "idProceso":"106900640-d0cab45d2404960b65fe02445e97b7e2",
        "codResult":"807"
      }
    RESPONSE
  end

  def successful_purchase_response
    <<~RESPONSE
      {
        "cifrado":"SHA2",
        "parametros":"eyJudW1BdXQiOiIxMDEwMDAiLCJyZWZlcmVuY2lhIjoiMTIwMDQxNzIxOTIzMTAxODE3MjAwMDYwMDcwMDAiLCJjb2RBdXQiOiIwMDAifQ==",
        "firma":"da751ff809f54842ff26aed009cdce2d1a3b613cb3be579bb17af2e3ab36aa37",
        "fecha":"231018172001775",
        "idProceso":"106900640-bd4bd321774c51ec91cf24ca6bbca913"
      }
    RESPONSE
  end

  def failed_purchase_response
    <<~RESPONSE
      {
        "fecha":"231018174516102",
        "idProceso":"106900640-29c9d010e2e8c33872a4194df4e7a544",
        "codResult":"27"
      }
    RESPONSE
  end

  def successful_refund_response
    <<~RESPONSE
      {
        "cifrado":"SHA2",
        "parametros":"eyJtZXJjaGFudElEIjoiMTA2OTAwNjQwIiwiYWNxdWlyZXJCSU4iOiIwMDAwNTU0MDAwIiwidGVybWluYWxJRCI6IjAwMDAwMDAzIiwibnVtT3BlcmFjaW9uIjoiOGYyOTJiYTcwMmEzMTZmODIwMmEzZGFjY2JhMjFmZWMiLCJpbXBvcnRlIjoiMTAwIiwibnVtQXV0IjoiMTAxMDAwIiwicmVmZXJlbmNpYSI6IjEyMjA0MTcyMzUyMzEwMTgxODQ3NDI2MDA3MDAwIiwidGlwb09wZXJhY2lvbiI6IkQiLCJwYWlzIjoiMDAwIiwiY29kQXV0IjoiOTAwIn0=",
        "firma":"37591482e4d1dce6317c6d7de6a6c9b030c0618680eaefb4b42b0d8af3854773",
        "fecha":"231018184743876",
        "idProceso":"106900640-8f292ba702a316f8202a3daccba21fec"
      }
    RESPONSE
  end

  def failed_refund_response
    <<~RESPONSE
      {
        "fecha":"231018185809202",
        "idProceso":"106900640-fc93d837dba2003ad767d682e6eb5d5f",
        "codResult":"15"
      }
    RESPONSE
  end

  def successful_void_response
    <<~RESPONSE
      {
        "cifrado":"SHA2",
        "parametros":"eyJtZXJjaGFudElEIjoiMTA2OTAwNjQwIiwiYWNxdWlyZXJCSU4iOiIwMDAwNTU0MDAwIiwidGVybWluYWxJRCI6IjAwMDAwMDAzIiwibnVtT3BlcmFjaW9uIjoiMDNlMTkwNTU4NWZlMmFjM2M4N2NiYjY4NGUyMjYwZDUiLCJpbXBvcnRlIjoiMTAwIiwibnVtQXV0IjoiMTAxMDAwIiwicmVmZXJlbmNpYSI6IjE0MjA0MTcyNDAyMzEwMTgxOTA2MTY2MDA3MDAwIiwidGlwb09wZXJhY2lvbiI6IkQiLCJwYWlzIjoiMDAwIiwiY29kQXV0IjoiNDAwIn0=",
        "firma":"af55904b24cb083e6514b86456b107fdb8ebfc715aed228321ad959b13ef2b23",
        "fecha":"231018190618224",
        "idProceso":"106900640-03e1905585fe2ac3c87cbb684e2260d5"
      }
    RESPONSE
  end

  def failed_void_response
    <<~RESPONSE
      {
        "fecha":"231018191116348",
        "idProceso":"106900640-d7ca10f4fae36b2ad81f330eeb1ce509",
        "codResult":"15"
      }
    RESPONSE
  end
end
