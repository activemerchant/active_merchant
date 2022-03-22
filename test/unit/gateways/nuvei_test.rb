require 'test_helper'

class NuveiTest < Test::Unit::TestCase
  include CommStub

  def setup
    @merchant_id = '427583496191624621'
    @merchant_site_id = '427583496191624621'
    @gateway = NuveiGateway.new(
      merchant_id: @merchant_id,
      merchant_site_id: @merchant_site_id,
      secret: 'secretkey',
    )

    @options = {
      order_id: 1,
      billing_address: address,
      description: 'Fake purchase',
      ip: '127.0.0.1'
    }
    @amount = 100
    @credit_card = credit_card
  end

  def test_successful_open_session
    expect_session successful_session_create_response
    response = @gateway.send(:open_session)
    assert response['sessionToken'] == "2da9b9cd-573e-4055-a209-3ac2b855f9af"
  end

  def test_successful_authorize
    expect_session successful_session_create_response
    
    @gateway.expects(:ssl_post)
      .with("https://ppp-test.safecharge.com/ppp/api/v1/initPayment.do", anything, anything)
      .returns(successful_initPayment_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    
    assert_equal '2110000000000587378', response.authorization
    assert_equal 'Succeeded', response.message
    assert response.test?
  end

  def test_failed_authorize_cant_open_session
    expect_session error_session_create_response
    
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal response.message, "Failed to open session"
    assert response.test?
  end

  def test_failed_authorize_bad_card_number
    expect_session successful_session_create_response
    
    @gateway.expects(:ssl_post)
      .with("https://ppp-test.safecharge.com/ppp/api/v1/initPayment.do", anything, anything)
      .returns(error_initPayment_bad_card_number_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    
    assert_nil response.authorization
    assert_equal 'Missing or invalid CardData data. Invalid credit card number 4211111111111111', response.message

    assert response.test?
  end

  def test_failed_authorize_gwError_limit_exceeded
    expect_session successful_session_create_response
    
    @gateway.expects(:ssl_post)
      .with("https://ppp-test.safecharge.com/ppp/api/v1/initPayment.do", anything, anything)
      .returns(error_initPayment_gwError_limit_exceeded)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    
    assert_nil response.authorization
    assert_equal 'Limit exceeding amount', response.message

    assert response.test?
  end

  def test_successful_purchase
    expect_session successful_session_create_response
    
    @gateway.expects(:ssl_post)
      .with("https://ppp-test.safecharge.com/ppp/api/v1/payment.do", anything, anything)
      .returns(successful_payment_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    # Payment authorization is "{transctionId}|{userPaymentOptionId}
    assert_equal response.authorization, "1110000000010304183|53959588"

    assert_equal response.cvv_result['code'], "M"
    assert_equal response.cvv_result['message'], "CVV matches"

    assert_equal response.avs_result['code'], "Y"
    assert_equal response.avs_result['message'], "Street address and 5-digit postal code match."

    assert_equal 'Succeeded', response.message

    assert response.test?
  end

  def test_successful_purchase_no_user_token_id
    expect_session successful_session_create_response
    
    @gateway.expects(:ssl_post)
      .with("https://ppp-test.safecharge.com/ppp/api/v1/payment.do", anything, anything)
      .returns(successful_payment_response_no_user_token_id)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal response.authorization, "1110000000010304183"
    assert_equal 'Succeeded', response.message

    assert response.test?
  end

  def test_failed_purchase_declined_card
    expect_session successful_session_create_response
    
    @gateway.expects(:ssl_post)
      .with("https://ppp-test.safecharge.com/ppp/api/v1/payment.do", anything, anything)
      .returns(error_payment_response_declined_card)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal response.message, "Decline"

    assert response.test?
  end

  def test_failed_purchase_cant_open_session
    expect_session error_session_create_response
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal response.message, "Failed to open session"
    assert response.test?
  end

  def test_successful_refund
    expect_session successful_session_create_response
    
    @gateway.expects(:ssl_post)
      .with("https://ppp-test.safecharge.com/ppp/api/v1/payment.do", anything, anything)
      .returns(successful_payment_response)
    @gateway.expects(:ssl_post)
      .with("https://ppp-test.safecharge.com/ppp/api/v1/refundTransaction.do", anything, anything)
      .returns(successful_refund_response)

    payment = @gateway.purchase(@amount, @credit_card, @options)
    assert_success payment
    assert_equal payment.authorization, "1110000000010304183|53959588"
    
    refund = @gateway.refund(@amount, payment.authorization.split('|')[0])
    assert_success refund
  end
  
  def test_failure_refund_exceeds_total_charge
    expect_session successful_session_create_response
    
    @gateway.expects(:ssl_post)
      .with("https://ppp-test.safecharge.com/ppp/api/v1/payment.do", anything, anything)
      .returns(successful_payment_response)

    @gateway.expects(:ssl_post)
      .with("https://ppp-test.safecharge.com/ppp/api/v1/refundTransaction.do", anything, anything)
      .returns(error_refund_response_exceeded_total_charge)

    payment = @gateway.purchase(@amount, @credit_card, @options)
    assert_success payment
    assert_equal payment.authorization, "1110000000010304183|53959588"
    
    refund = @gateway.refund(@amount, payment.authorization.split('|')[0])
    assert_failure refund
    assert_equal "Credit Amount Exceed Total Charges", refund.message
  end
  
  private

  def expect_session(response)
    @gateway.expects(:ssl_post)
      .with("https://ppp-test.safecharge.com/ppp/api/v1/getSessionToken.do", anything, anything)
      .returns(response)
  end
  
  def successful_session_create_response
    <<-RESPONSE
    {
        "sessionToken": "2da9b9cd-573e-4055-a209-3ac2b855f9af",
        "internalRequestId": 222310158,
        "status": "SUCCESS",
        "errCode": 0,
        "reason": "",
        "merchantId": "#{@merchant_id}",
        "merchantSiteId": "#{@merchant_site_id}",
        "version": "1.0",
        "clientRequestId": "1C6CT7V1L"
    }
    RESPONSE
  end

  def error_session_create_response
    <<-RESPONSE
    {
      "sessionToken": "",
      "internalRequestId": 412644488,
      "status": "ERROR",
      "errCode": 1001,
      "reason": "Invalid checksum",
      "merchantId": "#{@merchant_id}",
      "merchantSiteId": "#{@merchant_site_id}",
      "version": "1.0"
    }
    RESPONSE
  end

  def successful_session_create_response
    <<-RESPONSE
    {
        "sessionToken": "2da9b9cd-573e-4055-a209-3ac2b855f9af",
        "internalRequestId": 222310158,
        "status": "SUCCESS",
        "errCode": 0,
        "reason": "",
        "merchantId": "#{@merchant_id}",
        "merchantSiteId": "#{@merchant_site_id}",
        "version": "1.0",
        "clientRequestId": "1C6CT7V1L"
    }
    RESPONSE
  end

  def successful_payment_response
    <<-RESPONSE
    {
        "orderId": "271308078",
        "userTokenId": "230811147",
        "paymentOption": {
            "userPaymentOptionId": "53959588",
            "card": {
                "ccCardNumber": "4****2535",
                "bin": "400002",
                "last4Digits": "2535",
                "ccExpMonth": "12",
                "ccExpYear": "22",
                "acquirerId": "19",
                "cvv2Reply": "M",
                "avsCode": "Y",
                "cardType": "Credit",
                "cardBrand": "VISA",
                "threeD": {}
            }
        },
        "transactionStatus": "APPROVED",
        "gwErrorCode": 0,
        "gwExtendedErrorCode": 0,
        "transactionType": "Sale",
        "transactionId": "1110000000010304183",
        "externalTransactionId": "",
        "authCode": "111361",
        "customData": "",
        "fraudDetails": {
            "finalDecision": "Accept"
        },
        "sessionToken": "cedbd6c0-52cf-4716-83b1-309e8e8dd2d3",
        "clientUniqueId": "12345",
        "internalRequestId": 222320318,
        "status": "SUCCESS",
        "errCode": 0,
        "reason": "",
        "merchantId": "#{@merchant_id}",
        "merchantSiteId": "#{@merchant_site_id}",
        "version": "1.0",
        "clientRequestId": "1C6CT7V1L"
    }
    RESPONSE
  end

  def successful_payment_response_no_user_token_id
    <<-RESPONSE
    {
        "orderId": "271308078",
        "userTokenId": "",
        "paymentOption": {
            "userPaymentOptionId": "",
            "card": {
                "ccCardNumber": "4****2535",
                "bin": "400002",
                "last4Digits": "2535",
                "ccExpMonth": "12",
                "ccExpYear": "22",
                "acquirerId": "19",
                "cvv2Reply": "",
                "avsCode": "",
                "cardType": "Credit",
                "cardBrand": "VISA",
                "threeD": {}
            }
        },
        "transactionStatus": "APPROVED",
        "gwErrorCode": 0,
        "gwExtendedErrorCode": 0,
        "transactionType": "Sale",
        "transactionId": "1110000000010304183",
        "externalTransactionId": "",
        "authCode": "111361",
        "customData": "",
        "fraudDetails": {
            "finalDecision": "Accept"
        },
        "sessionToken": "cedbd6c0-52cf-4716-83b1-309e8e8dd2d3",
        "clientUniqueId": "12345",
        "internalRequestId": 222320318,
        "status": "SUCCESS",
        "errCode": 0,
        "reason": "",
        "merchantId": "#{@merchant_id}",
        "merchantSiteId": "#{@merchant_site_id}",
        "version": "1.0",
        "clientRequestId": "1C6CT7V1L"
    }
    RESPONSE
  end

  def successful_initPayment_response
    <<-RESPONSE
    {
        "reason": "",
        "orderId": "33704071",
        "transactionStatus": "APPROVED",
        "customData": "merchant custom data",
        "internalRequestId": 10036001,
        "version": "1.0",
        "transactionId": "2110000000000587378",
        "transactionType": "InitAuth3D",
        "gwExtendedErrorCode": 0,
        "gwErrorCode": 0,
        "merchantId": "#{@merchant_id}",
        "merchantSiteId": "#{@merchant_site_id}",
        "clientUniqueId": "",
        "errCode": 0,
        "paymentOption": {
            "card": {
                "ccCardNumber": "5****5761",
                "bin": "511142",
                "threeD": {
                    "methodPayload": "eyJ0aHJlZURTU2VydmVyVHJhbnNJRCI6ImVkNGZlNTkzLWUzMWUtNDEyMC05M2EwLTBkNDBhNzUxNzEzMSIsInRocmVlRFNNZXRob2ROb3RpZmljYXRpb25VUkwiOiJ3d3cuVGhpc0lzQU1ldGhvZE5vdGlmaWNhdGlvblVSTC5jb20ifQ==",
                    "methodUrl": "https://srv-azr-acq2:4435/api/ThreeDSMethod/threeDSMethodURL",
                    "v2supported": "true",
                    "serverTransId": "ed4fe593-e31e-4120-93a0-0d40a7517131",
                    "version": "2.1.0",
                    "directoryServerId":"A000000003",
                    "directoryServerPublicKey":"MIIFrjCCBJagAwIBAgIQB2rJm.."
                },
                "ccExpMonth": "12",
                "ccExpYear": "25",
                "last4Digits": "5761"
            }
        },
        "sessionToken": "e524e7c5-9855-4ce9-b0f9-1045f34fd526",
        "userTokenId": "230811147",
        "status": "SUCCESS"
    }
    RESPONSE
  end

  def error_initPayment_gwError_limit_exceeded
    <<-RESPONSE
    {
      "orderId": "308655828",
      "userTokenId": "230811147",
      "transactionId": "711000000008982555",
      "transactionType": "InitAuth3D",
      "transactionStatus": "ERROR",
      "gwErrorCode": -1100,
      "gwErrorReason": "Limit exceeding amount",
      "gwExtendedErrorCode": 1127,
      "paymentOption": {
        "card": {
          "ccCardNumber": "4****2369",
          "bin": "400837",
          "last4Digits": "2369",
          "ccExpMonth": "12",
          "ccExpYear": "22",
          "acquirerId": "19",
          "cardType": "Debit",
          "issuerCountry": "GB",
          "threeD": {
            "v2supported": "false"
          }
        }
      },
      "customData": "",
      "sessionToken": "4a1ae599-95de-4365-89fe-1dab110e43fe",
      "clientUniqueId": "",
      "internalRequestId": 411246008,
      "status": "SUCCESS",
      "errCode": 0,
      "reason": "",
      "merchantId": "#{@merchant_id}",
      "merchantSiteId": "#{@merchant_site_id}",
      "version": "1.0",
      "clientRequestId": ""
    }
    RESPONSE
  end
  
  def error_initPayment_bad_card_number_response
    <<-RESPONSE
    {
      "userTokenId": "230811147",
      "sessionToken": "b401341c-88c5-472f-bac6-4990160a3a3a",
      "clientUniqueId": "1",
      "internalRequestId": 10036001,
      "status": "ERROR",
      "errCode": 1004,
      "reason": "Missing or invalid CardData data. Invalid credit card number 4211111111111111",
      "merchantId": "#{@merchant_id}",
      "merchantSiteId": "#{@merchant_site_id}",
      "version": "1.0",
      "clientRequestId": "5"
    }
    RESPONSE
  end
  
  def error_payment_response_declined_card
    <<-RESPONSE
    {
      "orderId": "308575998",
      "userTokenId": "230811147",
      "paymentOption": {
        "userPaymentOptionId": "74265028",
        "card": {
          "ccCardNumber": "4****4242",
          "bin": "424242",
          "last4Digits": "4242",
          "ccExpMonth": "12",
          "ccExpYear": "50",
          "acquirerId": "19",
          "cvv2Reply": "",
          "avsCode": "",
          "cardBrand": "VISA",
          "issuerBankName": "",
          "isPrepaid": "false",
          "threeD": {}
        }
      },
      "transactionStatus": "DECLINED",
      "gwErrorCode": -1,
      "gwErrorReason": "Decline",
      "gwExtendedErrorCode": 0,
      "transactionType": "Sale",
      "transactionId": "711000000008955382",
      "externalTransactionId": "",
      "authCode": "",
      "customData": "",
      "fraudDetails": {
        "finalDecision": "Accept"
      },
      "externalSchemeTransactionId": "",
      "sessionToken": "4d98b92a-0687-44c5-a5f8-e9d76adf333b",
      "clientUniqueId": "12345",
      "internalRequestId": 410783398,
      "status": "SUCCESS",
      "errCode": 0,
      "reason": "",
      "merchantId": "#{@merchant_id}",
      "merchantSiteId": "#{@merchant_site_id}",
      "version": "1.0",
      "clientRequestId": "1"
    }
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    {
      "transactionId": "711000000009008691",
      "externalTransactionId": "",
      "gwErrorCode": 0,
      "gwExtendedErrorCode": 0,
      "transactionStatus": "APPROVED",
      "authCode": "111970",
      "CVV2Reply": "",
      "AVSCode": "",
      "transactionType": "Credit",
      "customData": "",
      "acquirerId": "19",
      "bin": "411111",
      "last4Digits": "1111",
      "ccCardNumber": "4****1111",
      "ccExpMonth": "12",
      "ccExpYear": "50",
      "cardBrand": "VISA",
      "issuerBankName": "",
      "isPrepaid": "false",
      "internalRequestId": 411686368,
      "status": "SUCCESS",
      "errCode": 0,
      "reason": "",
      "merchantId": "#{@merchant_id}",
      "merchantSiteId": "#{@merchant_site_id}",
      "version": "1.0",
      "clientRequestId": "17476"
    }
    RESPONSE
  end

  def error_refund_response_exceeded_total_charge
    <<-RESPONSE
    {
      "transactionId": "711000000009008576",
      "externalTransactionId": "",
      "paymentMethodErrorReason": "Credit Amount Exceed Total Charges",
      "gwErrorCode": -1100,
      "gwErrorReason": "Credit Amount Exceed Total Charges",
      "gwExtendedErrorCode": 1106,
      "transactionStatus": "ERROR",
      "authCode": "",
      "CVV2Reply": "",
      "AVSCode": "",
      "transactionType": "Credit",
      "customData": "",
      "acquirerId": "19",
      "bin": "411111",
      "last4Digits": "1111",
      "ccCardNumber": "4****1111",
      "ccExpMonth": "12",
      "ccExpYear": "50",
      "cardBrand": "VISA",
      "issuerBankName": "",
      "isPrepaid": "false",
      "internalRequestId": 411683808,
      "status": "SUCCESS",
      "errCode": 0,
      "reason": "",
      "merchantId": "#{@merchant_id}",
      "merchantSiteId": "#{@merchant_site_id}",
      "version": "1.0",
      "clientRequestId": "14233"
    }
    RESPONSE
  end
end
