# coding: utf-8

require 'test_helper'

class PayConexTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PayConexGateway.new(account_id: 'account', api_accesskey: 'key')
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
    assert_equal "000000001681", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 30002, response.params["error_code"]
  end

  def test_successful_authorize_and_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "000000001721", response.authorization

    @gateway.expects(:ssl_post).returns(successful_capture_response)
    response = @gateway.capture(@amount, response.authorization)
    assert_success response
    assert_equal "CAPTURED", response.message
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 30002, response.params["error_code"]
    assert_equal "DECLINED", response.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, "Authorization")
    assert_failure response
    assert_equal 20006, response.params["error_code"]
    assert_equal "Invalid token_id", response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, "Authorization")
    assert_success response
    assert_equal "000000001801", response.authorization
    assert_equal "VOID", response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, "Authorization")
    assert_failure response
    assert_equal 20017, response.params["error_code"]
    assert_equal "INVALID REFUND AMOUNT", response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    response = @gateway.void("Authorization")
    assert_success response
    assert_equal "000000001881", response.authorization
    assert_equal "APPROVED", response.message
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.refund(@amount, "Authorization")
    assert_failure response
    assert_equal 20687, response.params["error_code"]
    assert_equal "TRANSACTION ID ALREADY REVERSED", response.message
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)
    response = @gateway.verify(@credit_card)
    assert_success response
    assert_equal "000000001981", response.authorization
    assert_equal "APPROVED", response.message
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    response = @gateway.credit(@amount, @credit_card)
    assert_success response
    assert_equal "000000002061", response.authorization
  end

  def test_failed_credit
    @gateway.expects(:ssl_post).returns(failed_credit_response)

    response = @gateway.authorize(@amount, @credit_card)
    assert_failure response
    assert_equal "30370", response.params["error_code"]
    assert_equal "CARD DATA UNREADABLE", response.message
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)
    response = @gateway.store(@credit_card)
    assert_success response
    assert_equal "000000002101", response.authorization
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)

    response = @gateway.store(@credit_card)
    assert_failure response
    assert_equal "30370", response.params["error_code"]
    assert_equal "CARD DATA UNREADABLE", response.message
  end

  def test_card_present_purchase_passes_track_data
    stub_comms do
      @gateway.purchase(@amount, credit_card_with_track_data('4000100011112224'))
    end.check_request do |endpoint, data, headers|
      assert_match(/card_tracks/, data)
    end.respond_with(successful_card_present_purchase_response)
  end

  def test_successful_purchase_using_token
    @gateway.expects(:ssl_post).returns(successful_purchase_using_token_response)
    response = @gateway.purchase(@amount, "TheToken", @options)
    assert_success response
    assert_equal "000000004561", response.authorization
  end

  def test_successful_purchase_using_echeck
    @gateway.expects(:ssl_post).returns(successful_purchase_using_echeck_response)
    response = @gateway.purchase(@amount, check, @options)
    assert_success response
    assert_equal "000000007161", response.authorization
  end

  def test_failed_purchase_using_echeck
    @gateway.expects(:ssl_post).returns(failed_purchase_using_echeck_response)
    response = @gateway.purchase(@amount, check, @options)
    assert_failure response
    assert_equal "Invalid bank_routing_number", response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal post_scrubbed, @gateway.scrub(pre_scrubbed)
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      D,  DEBUG -- : account_id=220614968961&api_accesskey=69e9c4dd6b8ab9ab47da4e288df78315&tender_type=CARD&card_number=4000100011112224&card_expiration=0916&card_verification=123&first_name=Longbob&last_name=Longsen&street_address1=1234+My+Street&street_address2=Apt+1&city=Ottawa&state=ON&zip=K1C2N6&country=CA&phone=%28555%29555-5555&transaction_description=Store+Purchase&response_format=JSON&transaction_amount=1.00&email=joe%40example.com&transaction_type=SALE
      <- "account_id=220614968961&api_accesskey=69e9c4dd6b8ab9ab47da4e288df78315&tender_type=CARD&card_number=4000100011112224&card_expiration=0916&card_verification=123&first_name=Longbob&last_name=Longsen&street_address1=1234+My+Street&street_address2=Apt+1&city=Ottawa&state=ON&zip=K1C2N6&country=CA&phone=%28555%29555-5555&transaction_description=Store+Purchase&response_format=JSON&transaction_amount=1.00&email=joe%40example.com&transaction_type=SALE"
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03"
      -> "eP\xCBn\xC20\x10\xFC\x15\xE43Hy\x00\xA2\xB9E-\a$\xA4\"\xA2r\xE8%\xDA8\vXMlw\xED\xA4\xA5U\xFF\xBDv\b\x90\xD2\xBD\xED\xCC\xEChf\xBF\x99%\x90\x06
      -> "\xDFH\x86f<\x02\x00\x00"
      D, [2015-03-04T18:13:07.219562 #71589] DEBUG -- : {"transaction_id":"000000002021","tender_type":"CARD","transaction_timestamp":"2015-03-04 17:13:04","card_brand":"VISA","transaction_type":"SALE","last4":"2224","card_expiration":"0916","authorization_code":"CVI292","authorization_message":"APPROVED","request_amount":1,"transaction_amount":1,"first_name":"Longbob","last_name":"Longsen","keyed":true,"swiped":false,"transaction_approved":true,"avs_response":"Z","cvv2_response":"U","transaction_description":"Store Purchase","balance":1,"currency":"USD","error":false,"error_code":0,"error_message":null,"error_msg":null}
      {"transaction_id":"000000002021","tender_type":"CARD","transaction_timestamp":"2015-03-04 17:13:04","card_brand":"VISA","transaction_type":"SALE","last4":"2224","card_expiration":"0916","authorization_code":"CVI292","authorization_message":"APPROVED","request_amount":1,"transaction_amount":1,"first_name":"Longbob","last_name":"Longsen","keyed":true,"swiped":false,"transaction_approved":true,"avs_response":"Z","cvv2_response":"U","transaction_description":"Store Purchase","balance":1,"currency":"USD","error":false,"error_code":0,"error_message":null,"error_msg":null}
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      D,  DEBUG -- : account_id=220614968961&api_accesskey=[FILTERED]&tender_type=CARD&card_number=[FILTERED]&card_expiration=0916&card_verification=[FILTERED]&first_name=Longbob&last_name=Longsen&street_address1=1234+My+Street&street_address2=Apt+1&city=Ottawa&state=ON&zip=K1C2N6&country=CA&phone=%28555%29555-5555&transaction_description=Store+Purchase&response_format=JSON&transaction_amount=1.00&email=joe%40example.com&transaction_type=SALE
      <- \"account_id=220614968961&api_accesskey=[FILTERED]&tender_type=CARD&card_number=[FILTERED]&card_expiration=0916&card_verification=[FILTERED]&first_name=Longbob&last_name=Longsen&street_address1=1234+My+Street&street_address2=Apt+1&city=Ottawa&state=ON&zip=K1C2N6&country=CA&phone=%28555%29555-5555&transaction_description=Store+Purchase&response_format=JSON&transaction_amount=1.00&email=joe%40example.com&transaction_type=SALE\"
      -> \"\u001F?\b\u0000\u0000\u0000\u0000\u0000\u0000\u0003\"
      -> \"eP?n?0\u0010?\u0015?3Hy\u0000??E-\a$?\"?r?%?8\vXMlw???U??v\b?????hf??%?\u0006
      -> \"?H?f<\u0002\u0000\u0000\"
      D, [2015-03-04T18:13:07.219562 #71589] DEBUG -- : {\"transaction_id\":\"000000002021\",\"tender_type\":\"CARD\",\"transaction_timestamp\":\"2015-03-04 17:13:04\",\"card_brand\":\"VISA\",\"transaction_type\":\"SALE\",\"last4\":\"2224\",\"card_expiration\":\"0916\",\"authorization_code\":\"CVI292\",\"authorization_message\":\"APPROVED\",\"request_amount\":1,\"transaction_amount\":1,\"first_name\":\"Longbob\",\"last_name\":\"Longsen\",\"keyed\":true,\"swiped\":false,\"transaction_approved\":true,\"avs_response\":\"Z\",\"cvv2_response\":\"U\",\"transaction_description\":\"Store Purchase\",\"balance\":1,\"currency\":\"USD\",\"error\":false,\"error_code\":0,\"error_message\":null,\"error_msg\":null}
      {\"transaction_id\":\"000000002021\",\"tender_type\":\"CARD\",\"transaction_timestamp\":\"2015-03-04 17:13:04\",\"card_brand\":\"VISA\",\"transaction_type\":\"SALE\",\"last4\":\"2224\",\"card_expiration\":\"0916\",\"authorization_code\":\"CVI292\",\"authorization_message\":\"APPROVED\",\"request_amount\":1,\"transaction_amount\":1,\"first_name\":\"Longbob\",\"last_name\":\"Longsen\",\"keyed\":true,\"swiped\":false,\"transaction_approved\":true,\"avs_response\":\"Z\",\"cvv2_response\":\"U\",\"transaction_description\":\"Store Purchase\",\"balance\":1,\"currency\":\"USD\",\"error\":false,\"error_code\":0,\"error_message\":null,\"error_msg\":null}
    POST_SCRUBBED
  end

  def successful_purchase_response
    %({"transaction_id":"000000001681","tender_type":"CARD","transaction_timestamp":"2015-03-04 16:35:52","card_brand":"VISA","transaction_type":"SALE","last4":"2224","card_expiration":"0916","authorization_code":"CVI877","authorization_message":"APPROVED","request_amount":1,"transaction_amount":1,"first_name":"Longbob","last_name":"Longsen","keyed":true,"swiped":false,"transaction_approved":true,"avs_response":"Z","cvv2_response":"U","transaction_description":"Store Purchase","balance":1,"currency":"USD","error":false,"error_code":0,"error_message":null,"error_msg":null})
  end

  def failed_purchase_response
    %({"transaction_id":"000000001701","tender_type":"CARD","transaction_timestamp":"2015-03-04 16:38:37","card_brand":"VISA","transaction_type":"SALE","last4":"2224","card_expiration":"0916","authorization_message":"CALL AUTH CENTER","transaction_amount":1.01,"first_name":"Longbob","last_name":"Longsen","keyed":true,"swiped":false,"transaction_approved":false,"transaction_description":"Store Purchase","reason_code":null,"gateway_id":null,"currency":"USD","error":true,"error_code":30002,"error_message":"DECLINED","error_msg":"DECLINED"})
  end

  def successful_authorize_response
    %({"transaction_id":"000000001721","tender_type":"CARD","transaction_timestamp":"2015-03-04 16:44:34","card_brand":"VISA","transaction_type":"AUTHORIZATION","last4":"2224","card_expiration":"0916","authorization_code":"CVI986","authorization_message":"APPROVED","request_amount":1,"transaction_amount":1,"first_name":"Longbob","last_name":"Longsen","keyed":true,"swiped":false,"transaction_approved":true,"avs_response":"Z","cvv2_response":"U","transaction_description":"Store Purchase","balance":1,"currency":"USD","error":false,"error_code":0,"error_message":null,"error_msg":null})
  end

  def failed_authorize_response
    %({"transaction_id":"000000001741","tender_type":"CARD","transaction_timestamp":"2015-03-04 16:48:29","card_brand":"VISA","transaction_type":"AUTHORIZATION","last4":"2224","card_expiration":"0916","authorization_message":"CALL AUTH CENTER","transaction_amount":1.01,"first_name":"Longbob","last_name":"Longsen","keyed":true,"swiped":false,"transaction_approved":false,"transaction_description":"Store Purchase","reason_code":null,"gateway_id":null,"currency":"USD","error":true,"error_code":30002,"error_message":"DECLINED","error_msg":"DECLINED"})
  end

  def successful_capture_response
    %({"transaction_id":"000000001721","tender_type":"CARD","transaction_timestamp":"2015-03-04 16:44:38","card_brand":"VISA","transaction_type":"CAPTURE","last4":"2224","card_expiration":"0916","authorization_message":"CAPTURED","request_amount":1,"transaction_amount":1,"first_name":"Longbob Longsen","keyed":true,"swiped":false,"transaction_approved":true,"transaction_description":"Store Purchase","currency":"USD","error":false,"error_code":0,"error_message":null,"error_msg":null})
  end

  def failed_capture_response
    %({"error":true,"error_code":20006,"error_message":"Invalid token_id","error_msg":"Invalid token_id"})
  end

  def successful_refund_response
    %({"original_transaction_id":"000000001781","transaction_id":"000000001801","tender_type":"CARD","transaction_timestamp":"2015-03-04 16:52:41","card_brand":"VISA","transaction_type":"REFUND","last4":"2224","card_expiration":"0916","authorization_code":"CVI086","authorization_message":"VOID","request_amount":1,"transaction_amount":1,"first_name":"Longbob Longsen","keyed":true,"swiped":false,"transaction_approved":true,"transaction_description":"Store Purchase","currency":"USD","error":false,"error_code":0,"error_message":null,"error_msg":null})
  end

  def failed_refund_response
    %({"error":true,"error_code":20017,"error_message":"INVALID REFUND AMOUNT","error_msg":"INVALID REFUND AMOUNT"})
  end

  def successful_void_response
    %({"original_transaction_id":"000000001861","transaction_id":"000000001881","tender_type":"CARD","transaction_timestamp":"2015-03-04 17:02:44","card_brand":"VISA","transaction_type":"REVERSAL","last4":"2224","card_expiration":"0916","authorization_code":"CVI194","authorization_message":"APPROVED","request_amount":1,"transaction_amount":1,"first_name":"Longbob Longsen","keyed":true,"swiped":false,"transaction_approved":true,"transaction_description":"Store Purchase","currency":"USD","error":false,"error_code":0,"error_message":null,"error_msg":null})
  end

  def failed_void_response
    %({"error":true,"error_code":20687,"error_message":"TRANSACTION ID ALREADY REVERSED","error_msg":"TRANSACTION ID ALREADY REVERSED"})
  end

  def successful_verify_response
    %({"transaction_id":"000000001981","tender_type":"CARD","transaction_timestamp":"2015-03-04 17:09:34","card_brand":"VISA","transaction_type":"AUTHORIZATION","last4":"2224","card_expiration":"0916","authorization_code":"CVI261","authorization_message":"APPROVED","request_amount":0,"transaction_amount":0,"first_name":"Longbob","last_name":"Longsen","keyed":true,"swiped":false,"transaction_approved":true,"avs_response":"Z","cvv2_response":"U","transaction_description":"Store Purchase","currency":"USD","error":false,"error_code":0,"error_message":null,"error_msg":null})
  end

  def successful_credit_response
    %({"transaction_id":"000000002061","tender_type":"CARD","transaction_timestamp":"2015-03-04 17:58:03","card_brand":"VISA","transaction_type":"CREDIT","last4":"2224","card_expiration":"0916","authorization_message":"CREDIT","request_amount":1,"transaction_amount":1,"first_name":"Longbob","last_name":"Longsen","keyed":true,"swiped":false,"transaction_approved":true,"transaction_description":"Store Purchase","currency":"USD","error":false,"error_code":0,"error_message":null,"error_msg":null})
  end

  def failed_credit_response
    %({"error":true,"error_code":"30370","error_message":"CARD DATA UNREADABLE","error_msg":"CARD DATA UNREADABLE"})
  end

  def successful_store_response
    %({"transaction_id":"000000002101","tender_type":"CARD","transaction_timestamp":"2015-03-04 18:01:45","card_brand":"VISA","transaction_type":"STORE","last4":"2224","card_expiration":"0916","request_amount":0,"transaction_amount":0,"first_name":"Longbob","last_name":"Longsen","keyed":true,"swiped":false,"currency":"USD","error":false,"error_code":0,"error_message":null,"error_msg":null})
  end

  def failed_store_response
    %({"error":true,"error_code":"30370","error_message":"CARD DATA UNREADABLE","error_msg":"CARD DATA UNREADABLE"})
  end

  def successful_card_present_purchase_response
    %({"transaction_id":"000000004441","tender_type":"CARD","transaction_timestamp":"2015-03-05 11:02:54","card_brand":"VISA","transaction_type":"SALE","last4":"2224","card_expiration":"1215","authorization_code":"CVI636","authorization_message":"APPROVED","request_amount":1,"transaction_amount":1,"first_name":"L.","last_name":"LONGSEN","keyed":false,"swiped":true,"transaction_approved":true,"avs_response":"Z","transaction_description":"Store Purchase","balance":1,"currency":"USD","error":false,"error_code":0,"error_message":null,"error_msg":null})
  end

  def successful_purchase_using_token_response
    %({"transaction_id":"000000004561","tender_type":"CARD","transaction_timestamp":"2015-03-05 12:18:18","card_brand":"VISA","transaction_type":"STORE","last4":"2224","card_expiration":"0916","request_amount":0,"transaction_amount":0,"first_name":"Longbob","last_name":"Longsen","keyed":true,"swiped":false,"currency":"USD","error":false,"error_code":0,"error_message":null,"error_msg":null})
  end

  def successful_purchase_using_echeck_response
    %({"transaction_id":"000000007161","tender_type":"ACH","transaction_timestamp":"2015-03-05 16:05:56","card_brand":"ACH","transaction_type":"SALE","last4":"8535","card_expiration":null,"authorization_code":"ACH","authorization_message":"PENDING","request_amount":1,"transaction_amount":1,"first_name":"Jim","last_name":"Smith","keyed":true,"swiped":false,"transaction_approved":true,"transaction_description":"Store Purchase","currency":"USD","check_number":"1","error":false,"error_code":0,"error_message":null,"error_msg":null})
  end

  def failed_purchase_using_echeck_response
    %({"error":true,"error_code":20019,"error_message":"Invalid bank_routing_number","error_msg":"Invalid bank_routing_number"})
  end
end
