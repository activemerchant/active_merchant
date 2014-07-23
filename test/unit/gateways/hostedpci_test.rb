require 'test_helper'

class HostedpciTest < Test::Unit::TestCase
  def setup
    @gateway = HostedpciGateway.new(
                                    :login => 'login',
                                    :password =>   'password',
                                    :hpci_api_host => 'http://api-address.hostedpci.com'
                                    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
      :ip => '127.0.0.1',
      :customer => 'tstuser1',
      :email => 'tstuser1@hostedpci.com'
    }
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_auth_response)

    ##provide a token, rather then a credit card number
    @credit_card.number = '4242000000014242'

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert !response.authorization.empty?

    puts (response.authorization)
    puts (response.success?)
    puts(response.message)
    #puts(response.params)
  end

  def test_successful_capture
    #first perform auth and assert the usual
    @credit_card.number = '4242000000014242'

    @gateway.expects(:ssl_post).returns(successful_auth_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert !response.authorization.empty?

    #now capture funds and assert results
    auth = response.authorization

    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert cap_response = @gateway.capture(@amount, auth, @options)
    assert_instance_of Response, cap_response
    assert_success cap_response
  end

  def test_successful_void
    #first perform auth and assert the usual
    @credit_card.number = '4242000000014242'

    @gateway.expects(:ssl_post).returns(successful_auth_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert !response.authorization.empty?

    #now void the transaction and assert results
    auth = response.authorization

    @gateway.expects(:ssl_post).returns(successful_void_response)
    assert void_response = @gateway.void(auth, @options)
    assert_instance_of Response, void_response
    assert_success void_response
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    ##provide a token, rather then a credit card number
    @credit_card.number = '4242000000014242'

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert !response.authorization.empty?

    puts (response.authorization)
    puts (response.success?)
    puts(response.message)
    #puts(response.params)
  end

  def test_successful_linked_credit
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    ##provide a token, rather then a credit card number
    @credit_card.number = '4242000000014242'

    #create a purchase transaction to credit
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert !response.authorization.empty?

    auth = response.authorization

    #now credit the transaction (might not be settled)
    @gateway.expects(:ssl_post).returns(unsettled_credit_response)
    assert credit_response = @gateway.credit(@amount, auth, @options)
    assert_instance_of Response, credit_response
    assert !credit_response.success?
    assert credit_response.params['status_description'] == 'TRAN NOT SETTLED'

  end

  def test_unsuccessful_api_request

    bad_Gateway = HostedpciGateway.new(
                 :login => 'user_not_available',
                 :password =>   'invalid_pwd',
                 :hpci_api_host => 'http://api-synt1stg.c1.hostedpci.com'
               )

    #set up mock on bad gateway
    bad_Gateway.expects(:ssl_post).returns(failed_api_call_response)

    assert response = bad_Gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.params['error_id'] == 'PPA_ACT_1'

  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    res = 'status=success&operId=&saleId=2615849&pxyResponse.responseStatus.name=&pxyResponse.processorRefId=03WA9XR1F3BU1QV1LE4&pxyResponse.responseStatus.code=10188A&pxyResponse.threeDSErrorId=&pxyResponse.processorType=ipayResponse&pxyResponse.threeDSECI=&pxyResponse.responseStatus.description=Approved&pxyResponse.fullNativeResp=frdChkResp.fullNativeResp%3D%26COMPANY_KEY%3D6990%26ARC%3D00%26APPROVAL_CODE%3D10188A%26LOCAL_TIME%3D194319%26MRC%3D00%26RESPONSE_TEXT%3DApproved%26TRANSACTION_ID%3D03WA9XR1F3BU1QV1LE4%26AMOUNT%3D1.00%26LOCAL_DATE%3D03192012%26TERMINAL_ID%3D6177%26EXCHANGE_RATE%3D1&pxyResponse.threeDSXid=&pxyResponse.threeDSCAVV=&pxyResponse.responseStatus=approved&pxyResponse.responseCVV1=&pxyResponse.fullFraudNativeResp=&pxyResponse.responseCVV2=&pxyResponse.responseAVS2=&pxyResponse.responseAVS1=&pxyResponse.responseAVS4=&pxyResponse.responseAVS3=&pxyResponse.threeDSErrorDesc='
    return res;
  end

  # Place raw failed response from gateway here
  def failed_api_call_response
    res ='status=error&errId=PPA_ACT_1&errParamName=&errParamValue=&'
    return res;
  end

  def successful_auth_response
    res = 'status=success&operId=&authId=2619608&pxyResponse.responseStatus.name=&pxyResponse.processorRefId=03FA9KR0R14TB307ZBJ&pxyResponse.responseStatus.code=10687A&pxyResponse.threeDSErrorId=&pxyResponse.processorType=ipayResponse&pxyResponse.threeDSECI=&pxyResponse.responseStatus.description=Approved&pxyResponse.fullNativeResp=frdChkResp.fullNativeResp%3D%26COMPANY_KEY%3D6990%26ARC%3D00%26APPROVAL_CODE%3D10687A%26LOCAL_TIME%3D142127%26MRC%3D00%26RESPONSE_TEXT%3DApproved%26TRANSACTION_ID%3D03FA9KR0R14TB307ZBJ%26AMOUNT%3D1.00%26LOCAL_DATE%3D03202012%26TERMINAL_ID%3D6177%26EXCHANGE_RATE%3D1&pxyResponse.threeDSXid=&pxyResponse.threeDSCAVV=&pxyResponse.responseStatus=approved&pxyResponse.responseCVV1=&pxyResponse.fullFraudNativeResp=&pxyResponse.responseCVV2=&pxyResponse.responseAVS2=&pxyResponse.responseAVS1=&pxyResponse.responseAVS4=&pxyResponse.responseAVS3=&pxyResponse.threeDSErrorDesc='
    return res;
  end

  def successful_capture_response
    res = 'status=success&operId=&captureId=2623335&pxyResponse.responseStatus.name=&pxyResponse.processorRefId=03WA9KZUGLTT34FJZF3&pxyResponse.responseStatus.code=ERIL95&pxyResponse.threeDSErrorId=&pxyResponse.processorType=ipayResponse&pxyResponse.threeDSECI=&pxyResponse.responseStatus.description=TRAN+CAPTURED&pxyResponse.fullNativeResp=COMPANY_KEY%3D6990%26ARC%3D00%26APPROVAL_CODE%3DERIL95%26LOCAL_TIME%3D145509%26MRC%3D00%26RESPONSE_TEXT%3DTRAN%2BCAPTURED%26TRANSACTION_ID%3D03WA9KZUGLTT34FJZF3%26AMOUNT%3D1.00%26LOCAL_DATE%3D03202012%26TERMINAL_ID%3D6177%26EXCHANGE_RATE%3D1&pxyResponse.threeDSXid=&pxyResponse.threeDSCAVV=&pxyResponse.responseStatus=approved&pxyResponse.responseCVV1=&pxyResponse.responseCVV2=&pxyResponse.responseAVS2=&pxyResponse.responseAVS1=&pxyResponse.responseAVS4=&pxyResponse.responseAVS3=&pxyResponse.threeDSErrorDesc='
    return res;
  end

  def successful_void_response
    res = 'status=success&operId=&voidId=2684848&pxyResponse.responseStatus.name=&pxyResponse.processorRefId=03WA9L1PEP5FVZZ2ZLA&pxyResponse.responseStatus.code=EVBR8E&pxyResponse.threeDSErrorId=&pxyResponse.processorType=ipayResponse&pxyResponse.threeDSECI=&pxyResponse.responseStatus.description=TRAN+VOIDED&pxyResponse.fullNativeResp=COMPANY_KEY%3D6990%26ARC%3D00%26APPROVAL_CODE%3DEVBR8E%26LOCAL_TIME%3D161946%26MRC%3D00%26RESPONSE_TEXT%3DTRAN%2BVOIDED%26TRANSACTION_ID%3D03WA9L1PEP5FVZZ2ZLA%26LOCAL_DATE%3D03202012%26TERMINAL_ID%3D6177&pxyResponse.threeDSXid=&pxyResponse.threeDSCAVV=&pxyResponse.responseStatus=approved&pxyResponse.responseCVV1=&pxyResponse.responseCVV2=&pxyResponse.responseAVS2=&pxyResponse.responseAVS1=&pxyResponse.responseAVS4=&pxyResponse.responseAVS3=&pxyResponse.threeDSErrorDesc='
    return res;
  end

  def unsettled_credit_response
    res = 'status=error&errId=&errParamName=&errParamValue=&pxyResponse.responseStatus.name=&pxyResponse.processorRefId=03FA9L2FHGGJU64RZLK&pxyResponse.threeDSErrorId=&pxyResponse.processorType=ipayResponse&pxyResponse.threeDSECI=&pxyResponse.responseStatus.description=TRAN+NOT+SETTLED&pxyResponse.fullNativeResp=COMPANY_KEY%3D6990%26ARC%3DER%26LOCAL_TIME%3D163149%26MRC%3DNS%26RESPONSE_TEXT%3DTRAN%2BNOT%2BSETTLED%26TRANSACTION_ID%3D03FA9L2FHGGJU64RZLK%26AMOUNT%3D1.00%26LOCAL_DATE%3D03202012%26TERMINAL_ID%3D6177%26EXCHANGE_RATE%3D1&pxyResponse.threeDSXid=&pxyResponse.threeDSCAVV=&pxyResponse.responseStatus=error&pxyResponse.responseCVV1=&pxyResponse.responseCVV2=&pxyResponse.responseAVS2=&pxyResponse.responseAVS1=&pxyResponse.responseAVS4=&pxyResponse.threeDSErrorDesc=&pxyResponse.responseAVS3='
    return res;
  end

end
