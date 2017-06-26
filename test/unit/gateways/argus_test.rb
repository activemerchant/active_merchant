require 'test_helper'

class ArgusTest < Test::Unit::TestCase
  def setup
    @gateway = ArgusGateway.new(site_id: '999', req_username: 'login', req_password: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '70516328', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '70575695', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@decline_amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, '70575695', @options)
    assert_success response

    assert_equal '70575695', response.authorization
    assert response.test?
  end

  def test_failed_capture; end

  def test_successful_refund; end

  def test_failed_refund; end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('70578001', @options)
    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('70578001', @options)
    assert_failure response
  end

  def test_successful_verify; end

  def test_successful_verify_with_failed_void; end

  def test_failed_verify; end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
<- "POST /payment/pmt_service.cfm HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: svc.arguspayments.com\r\nContent-Length: 448\r\n\r\n"
<- "amount=1.00&currency=USD&li_prod_id_1=55452&li_value_1=1.00&pmt_expiry=09%2F2018&pmt_key=123&pmt_numb=4000100011112224&request_currency=USD&merch_acct_id=39511&bill_addr=456+My+Street&bill_addr_city=Ottawa&bill_addr_country=CA&bill_addr_state=ON&bill_addr_zip=K1C2N6&request_action=CCAUTHCAP&request_response_format=JSON&request_api_version=%5B3.6%2C+%22JSON%22%5D&site_id=36389&req_username=api%example.com&req_password=xSUsTLQ42ANYTLMHUtop")
  end

  def post_scrubbed
    %q(
<- "POST /payment/pmt_service.cfm HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: svc.arguspayments.com\r\nContent-Length: 448\r\n\r\n"
<- "amount=1.00&currency=USD&li_prod_id_1=55452&li_value_1=1.00&pmt_expiry=09%2F2018&pmt_key=[FILTERED]&pmt_numb=[FILTERED]&request_currency=USD&merch_acct_id=39511&bill_addr=456+My+Street&bill_addr_city=Ottawa&bill_addr_country=CA&bill_addr_state=ON&bill_addr_zip=K1C2N6&request_action=CCAUTHCAP&request_response_format=JSON&request_api_version=%5B3.6%2C+%22JSON%22%5D&site_id=36389&req_username=api%example.com&req_password=[FILTERED])
  end

  def successful_purchase_response
    #       Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
    #       to "true" when running remote tests:
    #
    #       $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
    #         test/remote/gateways/remote_argus_test.rb \
    #         -n test_successful_purchase
    %({"REQUEST_ACTION":"CCAUTHCAP","TRANS_STATUS_NAME":"APPROVED","TRANS_VALUE":1,"CURR_CODE_ALPHA":"USD","TRANS_VALUE_SETTLED":1,"CURR_CODE_ALPHA_SETTLED":"USD","TRANS_EXCH_RATE":"","TRANS_ID":80286684,"CUST_ID":14198335,"XTL_CUST_ID":"","PO_ID":70516328,"XTL_ORDER_ID":"","BATCH_ID":832360,"PROC_NAME":"Test Processor","MERCH_ACCT_ID":39511,"CARD_BRAND_NAME":"Visa","CARD_TYPE":"VISA TRADITIONAL","CARD_PREPAID":0,"CARD_BANK":"UNIVERSITY FIRST FEDERAL CREDIT UNION","CARD_BALANCE":"","PMT_L4":"2224","PMT_ID":16844184,"PMT_ID_XTL":"","PROC_UDF01":"","PROC_UDF02":"","PROC_AUTH_RESPONSE":"TEST52707","PROC_RETRIEVAL_NUM":"48045CE4-618F-4A6D-B8FE2D10CB17E7CA","PROC_REFERENCE_NUM":"TEST752644760","PROC_REDIRECT_URL":"","AVS_RESPONSE":"M","CVV_RESPONSE":"M","REQUEST_API_VERSION":"3.6","PO_LI_ID_1":"36773677","PO_LI_COUNT_1":1,"PO_LI_AMOUNT_1":"1","PO_LI_PROD_ID_1":"55555","MBSHP_ID_1":""})
  end

  def failed_purchase_response
    %({"REQUEST_ACTION":"CCAUTHCAP","TRANS_STATUS_NAME":"DECLINED","TRANS_VALUE":5.05,"TRANS_ID":80350118,"CUST_ID":14198497,"XTL_CUST_ID":"","MERCH_ACCT_ID":39511,"CARD_BRAND_NAME":"Visa","PMT_L4":"2220","API_RESPONSE":"0","API_ADVICE":" ","SERVICE_RESPONSE":600,"SERVICE_ADVICE":"Declined","PROCESSOR_RESPONSE":"505","PROCESSOR_ADVICE":"Declined","INDUSTRY_RESPONSE":"0","INDUSTRY_ADVICE":" ","REF_FIELD":"","PROC_NAME":"Test Processor","AVS_RESPONSE":"","CVV_RESPONSE":"","REQUEST_API_VERSION":"3.6"})
  end

  def successful_authorize_response
    %({"REQUEST_ACTION":"CCAUTHORIZE","TRANS_STATUS_NAME":"APPROVED","TRANS_VALUE":1,"CURR_CODE_ALPHA":"USD","TRANS_VALUE_SETTLED":1,"CURR_CODE_ALPHA_SETTLED":"USD","TRANS_EXCH_RATE":"","TRANS_ID":80351633,"CUST_ID":14198335,"XTL_CUST_ID":"","PO_ID":70575695,"XTL_ORDER_ID":"","BATCH_ID":832360,"PROC_NAME":"Test Processor","MERCH_ACCT_ID":39511,"CARD_BRAND_NAME":"Visa","CARD_TYPE":"VISA TRADITIONAL","CARD_PREPAID":0,"CARD_BANK":"UNIVERSITY FIRST FEDERAL CREDIT UNION","CARD_BALANCE":"","PMT_L4":"2224","PMT_ID":16844184,"PMT_ID_XTL":"","PROC_UDF01":"","PROC_UDF02":"","PROC_AUTH_RESPONSE":"TEST12389","PROC_RETRIEVAL_NUM":"9887FE05-5E3E-4FB9-AD1E5C113F392BAA","PROC_REFERENCE_NUM":"TEST825288379","PROC_REDIRECT_URL":"","AVS_RESPONSE":"M","CVV_RESPONSE":"M","REQUEST_API_VERSION":"3.6","PO_LI_ID_1":"36810339","PO_LI_COUNT_1":1,"PO_LI_AMOUNT_1":"1","PO_LI_PROD_ID_1":"55452","MBSHP_ID_1":""})
  end

  def failed_authorize_response
    %({"REQUEST_ACTION":"CCAUTHORIZE","TRANS_STATUS_NAME":"DECLINED","TRANS_VALUE":5.05,"TRANS_ID":80351592,"CUST_ID":14198497,"XTL_CUST_ID":"","MERCH_ACCT_ID":39511,"CARD_BRAND_NAME":"Visa","PMT_L4":"2220","API_RESPONSE":"0","API_ADVICE":" ","SERVICE_RESPONSE":600,"SERVICE_ADVICE":"Declined","PROCESSOR_RESPONSE":"505","PROCESSOR_ADVICE":"Declined","INDUSTRY_RESPONSE":"0","INDUSTRY_ADVICE":" ","REF_FIELD":"","PROC_NAME":"Test Processor","AVS_RESPONSE":"","CVV_RESPONSE":"","REQUEST_API_VERSION":"3.6"})
  end

  def successful_capture_response
    %({"REQUEST_ACTION":"CCCAPTURE","TRANS_STATUS_NAME":"APPROVED","TRANS_VALUE":1,"CURR_CODE_ALPHA":"USD","TRANS_VALUE_SETTLED":1,"CURR_CODE_ALPHA_SETTLED":"USD","TRANS_EXCH_RATE":"","TRANS_ID":80351634,"CUST_ID":14198335,"XTL_CUST_ID":"","PO_ID":70575695,"XTL_ORDER_ID":"","BATCH_ID":832360,"PROC_NAME":"Test Processor","MERCH_ACCT_ID":39511,"CARD_BRAND_NAME":"Visa","CARD_TYPE":"VISA TRADITIONAL","CARD_PREPAID":0,"CARD_BANK":"UNIVERSITY FIRST FEDERAL CREDIT UNION","CARD_BALANCE":"","PMT_L4":"2224","PMT_ID":16844184,"PMT_ID_XTL":"","PROC_UDF01":"","PROC_UDF02":"","PROC_AUTH_RESPONSE":"TEST53350","PROC_RETRIEVAL_NUM":"C64E1D08-8C9C-45AF-A45BF1725DEFF3C0","PROC_REFERENCE_NUM":"TEST281463494","PROC_REDIRECT_URL":"","AVS_RESPONSE":"M","CVV_RESPONSE":"M","REQUEST_API_VERSION":"3.6","PO_LI_ID_1":"36810339","PO_LI_COUNT_1":1,"PO_LI_AMOUNT_1":1,"PO_LI_PROD_ID_1":55452,"MBSHP_ID_1":""})
  end

  def failed_capture_response; end

  def successful_refund_response; end

  def failed_refund_response; end

  def successful_void_response
    %({"REQUEST_ACTION":"CCREVERSE","TRANS_STATUS_NAME":"APPROVED","TRANS_VALUE":-1,"CURR_CODE_ALPHA":"USD","TRANS_VALUE_SETTLED":-1,"CURR_CODE_ALPHA_SETTLED":"USD","TRANS_EXCH_RATE":"","TRANS_ID":80354325,"CUST_ID":14198335,"XTL_CUST_ID":"","PO_ID":70578001,"XTL_ORDER_ID":"","BATCH_ID":832360,"PROC_NAME":"Test Processor","MERCH_ACCT_ID":39511,"CARD_BRAND_NAME":"Visa","CARD_TYPE":"VISA TRADITIONAL","CARD_PREPAID":0,"CARD_BANK":"UNIVERSITY FIRST FEDERAL CREDIT UNION","CARD_BALANCE":"","PMT_L4":"2224","PMT_ID":16844184,"PMT_ID_XTL":"","PROC_UDF01":"","PROC_UDF02":"","PROC_AUTH_RESPONSE":"TEST82464","PROC_RETRIEVAL_NUM":"DCD5E6EB-38B3-4066-969A1E435DC0CC45","PROC_REFERENCE_NUM":"TEST350588254","PROC_REDIRECT_URL":"","AVS_RESPONSE":"M","CVV_RESPONSE":"M","REQUEST_API_VERSION":"3.6","PO_LI_ID_1":"36811778","PO_LI_COUNT_1":1,"PO_LI_AMOUNT_1":-1,"PO_LI_PROD_ID_1":55452,"MBSHP_ID_1":""})
  end

  def failed_void_response
    %({"REQUEST_ACTION":"CCREVERSE","TRANS_STATUS_NAME":"","TRANS_VALUE":"","TRANS_ID":"","CUST_ID":"","XTL_CUST_ID":"","MERCH_ACCT_ID":"","CARD_BRAND_NAME":"","PMT_L4":"","API_RESPONSE":"113","API_ADVICE":"Invalid Data","SERVICE_RESPONSE":0,"SERVICE_ADVICE":" ","PROCESSOR_RESPONSE":0,"PROCESSOR_ADVICE":" ","INDUSTRY_RESPONSE":0,"INDUSTRY_ADVICE":" ","REF_FIELD":"REQUEST_REF_PO_ID","PROC_NAME":"","AVS_RESPONSE":"","CVV_RESPONSE":"","REQUEST_API_VERSION":"3.6"})
  end
end
