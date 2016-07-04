#encoding: utf-8
require 'test_helper'

class PayuLatamTest < Test::Unit::TestCase
  def setup
    @gateway = PayuCoGateway.new(key: "key", login: "login", account_id: "account", merchant_id: "merchant")
    @credit_card = credit_card
    @amount = 10000

    @options = {
      user: {
        identification: "123", 
        full_name: "REJECTED", 
        email: "test@test.com"
      }, 
      billing_address: {
        street1: "123", 
        street2: "", 
        city: "Barranquilla", 
        state: "Atlantico", 
        country: "CO", 
        zip: "080020", 
        phone: "1234"
      }
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'APPROVED', response.params["transactionResponse"]["state"]
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'DECLINED', response.params["transactionResponse"]["state"]
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    refund_options = {order_id: "123456", reason: "reson for the refund", transaction_id: "123-456-789-012"}
    
    assert refund = @gateway.refund(refund_options)
    assert_success refund
    assert_equal 'PENDING', refund.params["transactionResponse"]["state"]
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)
    refund_options = {order_id: "123456", reason: "reson for the refund", transaction_id: "123-456-789-012"}

    assert refund = @gateway.refund(refund_options)
    assert_success refund
    assert_equal 'ERROR', refund.params["code"]
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    void_options = {order_id: "123456", reason: "reson for the refund", transaction_id: "123-456-789-012"}

    assert void = @gateway.void(void_options)
    assert_success void
    assert_equal 'PENDING', void.params["transactionResponse"]["state"]
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    void_options = {order_id: "123456", reason: "reson for the refund", transaction_id: "123-456-789-012"}
    
    assert void = @gateway.void(void_options)
    assert_success void
    assert_equal 'ERROR', void.params["code"]
  end

  def test_order_status
    @gateway.expects(:ssl_post).returns(order_status_response)    
    
    assert order_status = @gateway.order_status(123456)
    assert_success order_status
    assert_equal 'SUCCESS', order_status.params["code"]
  end

  private

  def successful_purchase_response
    # %(
    #   Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
    #   to "true" when running remote tests:

    #   $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
    #     test/remote/gateways/remote_payu_co_test.rb \
    #     -n test_successful_purchase
    # )
    %({
      "code":"SUCCESS",
      "transactionResponse":{
        "orderId":7306173,
        "authorizationCode":"00000000",
        "pendingReason":null,
        "operationDate":1438035265501,
        "transactionDate":null,
        "paymentNetworkResponseErrorMessage":null,
        "extraParameters":null,
        "errorCode":null,
        "state":"APPROVED",
        "trazabilityCode":"00000000",
        "transactionTime":null,
        "responseMessage":null,
        "responseCode":"APPROVED",
        "transactionId":"276ab55a-15ca-40c2-9d9f-8d4a0944e8b5",
        "paymentNetworkResponseCode":null
      },
      "error":null
    })
  end

  def failed_purchase_response
    %({
      "code":"SUCCESS",
      "transactionResponse":{
        "orderId":7306172,
        "authorizationCode":null,
        "pendingReason":null,
        "operationDate":null,
        "transactionDate":null,
        "paymentNetworkResponseErrorMessage":null,
        "extraParameters":null,
        "errorCode":null,
        "state":"DECLINED",
        "trazabilityCode":null,
        "transactionTime":null,
        "responseMessage":null,
        "responseCode":"ANTIFRAUD_REJECTED",
        "transactionId":"40b09bca-17a9-426b-9bb8-eb121f3d578d",
        "paymentNetworkResponseCode":null
      },
      "error":null
    })
  end  

  def successful_refund_response
    %({
      "code":"SUCCESS",
      "error":null,
      "transactionResponse":{
        "orderId":5831055,
        "transactionId":null,
        "state":"PENDING",
        "paymentNetworkResponseCode":null,
        "paymentNetworkResponseErrorMessage":null,
        "trazabilityCode":null,
        "authorizationCode":null,
        "pendingReason":"PENDING_REVIEW",
        "responseCode":null,
        "errorCode":null,
        "responseMessage":"5831055",
        "transactionDate":null,
        "transactionTime":null,
        "operationDate":null,
        "extraParameters":null
      }
    })
  end

  def failed_refund_response
    %({"code":"ERROR", "error":"Solicitud ya en proceso", "transactionResponse":null})
  end

  def successful_void_response
    %({
      "code":"SUCCESS",
      "error":null,
      "transactionResponse":{
        "orderId":5831055,
        "transactionId":null,
        "state":"PENDING",
        "paymentNetworkResponseCode":null,
        "paymentNetworkResponseErrorMessage":null,
        "trazabilityCode":null,
        "authorizationCode":null,
        "pendingReason":"PENDING_REVIEW",
        "responseCode":null,
        "errorCode":null,
        "responseMessage":"5831055",
        "transactionDate":null,
        "transactionTime":null,
        "operationDate":null,
        "extraParameters":null
      }
    })
  end

  def failed_void_response
    %({"code":"ERROR", "error":"Solicitud ya en proceso", "transactionResponse":null})
  end

  def order_status_response
    %({
      "code":"SUCCESS", "error":null, "payload":{"id":95632206, "accountId":510231, "status":"CAPTURED", "referenceCode":"payment_1438808613", "description":"Payment", "airlineCode":null, "language":"es", "notifyUrl":null, "shippingAddress":null, "buyer":{"merchantBuyerId":null, "fullName":null, "emailAddress":"damian.galindo@koombea.com", "contactPhone":null}, "antifraudMerchantId":null, "transactions":[{"id":"c30873d3-1bd8-4ba1-aa9e-d77882504861", "order":null, "creditCard":{"maskedNumber":"377813*****7375", "name":"Damian Galindo", "issuerBank":"Bancolombia"}, "bankAccount":null, "type":"AUTHORIZATION_AND_CAPTURE", "parentTransactionId":null, "paymentMethod":"AMEX", "source":null, "paymentCountry":"CO", "transactionResponse":{"state":"APPROVED", "paymentNetworkResponseCode":"1", "paymentNetworkResponseErrorMessage":null, "trazabilityCode":"632414892", "authorizationCode":"387101", "pendingReason":null, "responseCode":"APPROVED", "errorCode":null, "responseMessage":null, "transactionDate":null, "transactionTime":null, "operationDate":1438808597038, "extraParameters":null}, "deviceSessionId":null, "ipAddress":null, "cookie":null, "userAgent":null, "expirationDate":null, "payer":{"merchantPayerId":"1129528587", "fullName":"Damian Galindo", "billingAddress":{"street1":"calle 3b transv 3b - 105", "street2":"Torre 7 Apto 1101", "city":"Barranquilla", "state":"Atlantico", "country":"CO", "postalCode":"080020", "phone":"3004700613"}, "emailAddress":"damian.galindo@koombea.com", "contactPhone":null, "dniNumber":"1129528587"}, "additionalValues":{"PM_TAX_ADMINISTRATIVE_FEE":{"value":0.0, "currency":"COP"}, "TX_ADDITIONAL_VALUE":{"value":0.0, "currency":"COP"}, "PM_TAX_ADMINISTRATIVE_FEE_RETURN_BASE":{"value":0.0, "currency":"COP"}, "TX_VALUE":{"value":6000.0, "currency":"COP"}, "PAYER_INTEREST_VALUE":{"value":0.0, "currency":"COP"}, "PM_TAX_RETURN_BASE":{"value":5172.0, "currency":"COP"}, "PM_ADMINISTRATIVE_FEE":{"value":0.0, "currency":"COP"}, "PM_VALUE":{"value":6000.0, "currency":"COP"}, "TX_ADMINISTRATIVE_FEE":{"value":0.0, "currency":"COP"}, "COMMISSION_VALUE":{"value":2900.0, "currency":"COP"}, "PM_NETWORK_VALUE":{"value":6000.0, "currency":"COP"}, "PM_ADDITIONAL_VALUE":{"value":0.0, "currency":"COP"}, "PM_TAX":{"value":827.0, "currency":"COP"}, "TX_TAX_RETURN_BASE":{"value":5172.0, "currency":"COP"}, "PAYER_PRICING_VALUES":{"value":0.0, "currency":"COP"}, "PM_PURCHASE_VALUE":{"value":5173.0, "currency":"COP"}, "TX_TAX":{"value":827.58, "currency":"COP"}, "MERCHANT_COMMISSION_VALUE":{"value":3364.0, "currency":"COP"}, "TX_TAX_ADMINISTRATIVE_FEE":{"value":0.0, "currency":"COP"}, "PAYER_COMMISSION_VALUE":{"value":0.0, "currency":"COP"}, "TX_TAX_ADMINISTRATIVE_FEE_RETURN_BASE":{"value":0.0, "currency":"COP"}, "MERCHANT_INTEREST_VALUE":{"value":0.0, "currency":"COP"}}, "extraParameters":{"INSTALLMENTS_NUMBER":"1", "MERCHANT_PROFILE_ID":"6804927f-38bb-4325-9e7e-c6907556278f", "PRICING_PROFILE_GROUP_ID":"f65720ab-5bed-4667-bcf9-83e51388a25f"}}], "additionalValues":{"PM_TAX_ADMINISTRATIVE_FEE":{"value":0.0, "currency":"COP"}, "TX_ADDITIONAL_VALUE":{"value":0.0, "currency":"COP"}, "PM_TAX_ADMINISTRATIVE_FEE_RETURN_BASE":{"value":0.0, "currency":"COP"}, "TX_VALUE":{"value":6000.0, "currency":"COP"}, "PAYER_INTEREST_VALUE":{"value":0.0, "currency":"COP"}, "PM_TAX_RETURN_BASE":{"value":5172.0, "currency":"COP"}, "PM_ADMINISTRATIVE_FEE":{"value":0.0, "currency":"COP"}, "PM_VALUE":{"value":6000.0, "currency":"COP"}, "TX_ADMINISTRATIVE_FEE":{"value":0.0, "currency":"COP"}, "PM_NETWORK_VALUE":{"value":6000.0, "currency":"COP"}, "PM_ADDITIONAL_VALUE":{"value":0.0, "currency":"COP"}, "PM_TAX":{"value":827.0, "currency":"COP"}, "TX_TAX_RETURN_BASE":{"value":5172.0, "currency":"COP"}, "PAYER_PRICING_VALUES":{"value":0.0, "currency":"COP"}, "PM_PURCHASE_VALUE":{"value":5173.0, "currency":"COP"}, "TX_TAX":{"value":827.58, "currency":"COP"}, "MERCHANT_COMMISSION_VALUE":{"value":3364.0, "currency":"COP"}, "TX_TAX_ADMINISTRATIVE_FEE":{"value":0.0, "currency":"COP"}, "PAYER_COMMISSION_VALUE":{"value":0.0, "currency":"COP"}, "TX_TAX_ADMINISTRATIVE_FEE_RETURN_BASE":{"value":0.0, "currency":"COP"}, "MERCHANT_INTEREST_VALUE":{"value":0.0, "currency":"COP"}}}
    })
  end
end
