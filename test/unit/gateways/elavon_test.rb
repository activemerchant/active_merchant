require 'test_helper'

class ElavonTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = ElavonGateway.new(
                 :login => 'login',
                 :user => 'user',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '123456;00000000-0000-0000-0000-00000000000', response.authorization
    assert response.test?
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '123456;00000000-0000-0000-0000-00000000000', response.authorization
    assert_equal 'APPROVED', response.message
    assert response.test?
  end

  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    authorization = '123456;00000000-0000-0000-0000-00000000000'

    assert response = @gateway.capture(@amount, authorization, :credit_card => @credit_card)
    assert_instance_of Response, response
    assert_success response

    assert_equal '123456;00000000-0000-0000-0000-00000000000', response.authorization
    assert_equal 'APPROVAL', response.message
    assert response.test?
  end

  def test_successful_capture_with_auth_code
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    authorization = '123456;00000000-0000-0000-0000-00000000000'

    assert response = @gateway.capture(@amount, authorization)
    assert_instance_of Response, response
    assert_success response

    assert_equal '123456;00000000-0000-0000-0000-00000000000', response.authorization
    assert_equal 'APPROVAL', response.message
    assert response.test?
  end

  def test_successful_capture_with_additional_options
    authorization = '123456;00000000-0000-0000-0000-00000000000'
    response = stub_comms do
      @gateway.capture(@amount, authorization, :test_mode => true, :partial_shipment_flag => true)
    end.check_request do |endpoint, data, headers|
      assert_match(/ssl_transaction_type=CCCOMPLETE/, data)
      assert_match(/ssl_test_mode=TRUE/, data)
      assert_match(/ssl_partial_shipment_flag=Y/, data)
    end.respond_with(successful_capture_response)

    assert_instance_of Response, response
    assert_success response

    assert_equal '123456;00000000-0000-0000-0000-00000000000', response.authorization
    assert_equal 'APPROVAL', response.message
    assert response.test?
  end

  def test_successful_purchase_with_ip
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(ip: '203.0.113.0'))
    end.check_request do |_endpoint, data, _headers|
      parsed = CGI.parse(data)
      assert_equal ['203.0.113.0'], parsed['ssl_cardholder_ip']
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_authorization_with_ip
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(ip: '203.0.113.0'))
    end.check_request do |_endpoint, data, _headers|
      parsed = CGI.parse(data)
      assert_equal ['203.0.113.0'], parsed['ssl_cardholder_ip']
    end.respond_with(successful_authorization_response)

    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_authorization_response)
    authorization = '123456INVALID;00000000-0000-0000-0000-00000000000'

    assert response = @gateway.capture(@amount, authorization, :credit_card => @credit_card)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void('123')
    assert_success response
    assert_equal 'APPROVAL', response.message
  end

  def test_unsuccessful_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert response = @gateway.void('123')
    assert_failure response
    assert_equal 'The transaction ID is invalid for this transaction type', response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(123, '456')
    assert_success response
    assert_equal 'APPROVAL', response.message
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(123, '456')
    assert_failure response
    assert_equal 'The refund amount exceeds the original transaction amount.', response.message
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorization_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorization_response, failed_void_response)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_unsuccessful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorization_response, successful_void_response)
    assert_failure response
    assert_equal 'The Credit Card Number supplied in the authorization request appears to be invalid.', response.message
  end

  def test_invalid_login
    @gateway.expects(:ssl_post).returns(invalid_login_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_equal '7000', response.params['result']
    assert_equal 'The VirtualMerchant ID and/or User ID supplied in the authorization request is invalid.', response.message
    assert_failure response
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], ElavonGateway.supported_cardtypes
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'X', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'P', response.cvv_result['code']
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal '7595301425001111', response.params['token']
    assert response.test?
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_update
    @gateway.expects(:ssl_post).returns(successful_update_response)
    token = '7595301425001111'
    assert response = @gateway.update(token, @credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_failed_update
    @gateway.expects(:ssl_post).returns(failed_update_response)
    token = '7595301425001111'
    assert response = @gateway.update(token, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_stripping_non_word_characters_from_zip
    bad_zip = '99577-0727'
    stripped_zip = '995770727'

    @options[:billing_address][:zip] = bad_zip

    @gateway.expects(:commit).with(anything, anything, has_entries(:avs_zip => stripped_zip), anything)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_zip_codes_with_letters_are_left_intact
    @options[:billing_address][:zip] = '.K1%Z_5E3-'

    @gateway.expects(:commit).with(anything, anything, has_entries(:avs_zip => 'K1Z5E3'), anything)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_custom_fields_in_request
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(:customer_number => '123', :custom_fields => {:a_key => 'a value'}))
    end.check_request do |endpoint, data, headers|
      assert_match(/customer_number=123/, data)
      assert_match(/a_key/, data)
      refute_match(/ssl_a_key/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_transcript_scrubbing
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrub), post_scrub
  end

  private

  def successful_purchase_response
    "ssl_card_number=42********4242
    ssl_exp_date=0910
    ssl_amount=1.00
    ssl_invoice_number=
    ssl_description=Test Transaction
    ssl_result=0
    ssl_result_message=APPROVED
    ssl_txn_id=00000000-0000-0000-0000-00000000000
    ssl_approval_code=123456
    ssl_cvv2_response=P
    ssl_avs_response=X
    ssl_account_balance=0.00
    ssl_txn_time=08/07/2009 09:54:18 PM"
  end

  def successful_refund_response
    "ssl_card_number=42*****2222
    ssl_exp_date=
    ssl_amount=1.00
    ssl_customer_code=
    ssl_invoice_number=
    ssl_description=
    ssl_company=
    ssl_first_name=
    ssl_last_name=
    ssl_avs_address=
    ssl_address2=
    ssl_city=
    ssl_state=
    ssl_avs_zip=
    ssl_country=
    ssl_phone=
    ssl_email=
    ssl_result=0
    ssl_result_message=APPROVAL
    ssl_txn_id=AA49315-C3D2B7BA-237C-1168-405A-CD5CAF928B0C
    ssl_approval_code=
    ssl_cvv2_response=
    ssl_avs_response=
    ssl_account_balance=0.00
    ssl_txn_time=08/21/2012 05:43:46 PM"
  end

  def successful_void_response
    "ssl_card_number=42*****2222
    ssl_exp_date=0913
    ssl_amount=1.00
    ssl_invoice_number=
    ssl_description=
    ssl_company=
    ssl_first_name=
    ssl_last_name=
    ssl_avs_address=
    ssl_address2=
    ssl_city=
    ssl_state=
    ssl_avs_zip=
    ssl_country=
    ssl_phone=
    ssl_email=
    ssl_result=0
    ssl_result_message=APPROVAL
    ssl_txn_id=AA49315-F04216E3-E556-E2E0-ADE9-4186A5F69105
    ssl_approval_code=
    ssl_cvv2_response=
    ssl_avs_response=
    ssl_account_balance=1.00
    ssl_txn_time=08/21/2012 05:37:19 PM"
  end

  def failed_purchase_response
    "errorCode=5000
    errorName=Credit Card Number Invalid
    errorMessage=The Credit Card Number supplied in the authorization request appears to be invalid."
  end

  def failed_refund_response
    "errorCode=5091
    errorName=Invalid Refund Amount
    errorMessage=The refund amount exceeds the original transaction amount."
  end

  def failed_void_response
    "errorCode=5040
    errorName=Invalid Transaction ID
    errorMessage=The transaction ID is invalid for this transaction type"
  end

  def invalid_login_response
        <<-RESPONSE
    ssl_result=7000\r
    ssl_result_message=The VirtualMerchant ID and/or User ID supplied in the authorization request is invalid.\r
        RESPONSE
  end

  def successful_authorization_response
    "ssl_card_number=42********4242
    ssl_exp_date=0910
    ssl_amount=1.00
    ssl_invoice_number=
    ssl_description=Test Transaction
    ssl_result=0
    ssl_result_message=APPROVED
    ssl_txn_id=00000000-0000-0000-0000-00000000000
    ssl_approval_code=123456
    ssl_cvv2_response=P
    ssl_avs_response=X
    ssl_account_balance=0.00
    ssl_txn_time=08/07/2009 09:56:11 PM"
  end

  def failed_authorization_response
    "errorCode=5000
    errorName=Credit Card Number Invalid
    errorMessage=The Credit Card Number supplied in the authorization request appears to be invalid."
  end

  def successful_capture_response
    "ssl_card_number=42********4242
    ssl_exp_date=0910
    ssl_amount=1.00
    ssl_customer_code=
    ssl_salestax=
    ssl_invoice_number=
    ssl_result=0
    ssl_result_message=APPROVAL
    ssl_txn_id=00000000-0000-0000-0000-00000000000
    ssl_approval_code=123456
    ssl_cvv2_response=P
    ssl_avs_response=X
    ssl_account_balance=0.00
    ssl_txn_time=08/07/2009 09:56:11 PM"
  end

  def failed_capture_response
    "errorCode=5040
    errorName=Invalid Transaction ID
    errorMessage=The transaction ID is invalid for this transaction type"
  end

  def successful_store_response
    "ssl_transaction_type=CCGETTOKEN
     ssl_result=0
     ssl_token=7595301425001111
     ssl_card_number=41**********1111
     ssl_token_response=SUCCESS
     ssl_add_token_response=Card Updated
     vu_aamc_id="
  end

  def failed_store_response
    "errorCode=5000
    errorName=Credit Card Number Invalid
    errorMessage=The Credit Card Number supplied in the authorization request appears to be invalid."
  end

  def successful_update_response
    "ssl_token=7595301425001111
    ssl_card_type=VISA
    ssl_card_number=************1111
    ssl_exp_date=1015
    ssl_company=
    ssl_customer_id=
    ssl_first_name=John
    ssl_last_name=Doe
    ssl_avs_address=
    ssl_address2=
    ssl_avs_zip=
    ssl_city=
    ssl_state=
    ssl_country=
    ssl_phone=
    ssl_email=
    ssl_description=
    ssl_user_id=webpage
    ssl_token_response=SUCCESS
    ssl_result=0"
  end

  def failed_update_response
    "errorCode=5000
    errorName=Credit Card Number Invalid
    errorMessage=The Credit Card Number supplied in the authorization request appears to be invalid."
  end

  def pre_scrub
    %q{
opening connection to api.demo.convergepay.com:443...
opened
starting SSL for api.demo.convergepay.com:443...
SSL established
<- "POST /VirtualMerchantDemo/process.do HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.demo.convergepay.com\r\nContent-Length: 616\r\n\r\n"
<- "ssl_merchant_id=000127&ssl_pin=IERAOBEE5V0D6Q3Q6R51TG89XAIVGEQ3LGLKMKCKCVQBGGGAU7FN627GPA54P5HR&ssl_show_form=false&ssl_result_format=ASCII&ssl_user_id=ssltest&ssl_invoice_number=&ssl_description=Test+Transaction&ssl_card_number=4124939999999990&ssl_exp_date=0919&ssl_cvv2cvc2=123&ssl_cvv2cvc2_indicator=1&ssl_first_name=Longbob&ssl_last_name=Longsen&ssl_avs_address=456+My+Street&ssl_address2=Apt+1&ssl_avs_zip=K1C2N6&ssl_city=Ottawa&ssl_state=ON&ssl_company=Widgets+Inc&ssl_phone=%28555%29555-5555&ssl_country=CA&ssl_email=paul%40domain.com&ssl_cardholder_ip=203.0.113.0&ssl_amount=1.00&ssl_transaction_type=CCSALE"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Wed, 03 Jan 2018 21:40:26 GMT\r\n"
-> "Pragma: no-cache\r\n"
-> "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
-> "Expires: 0\r\n"
-> "Content-Disposition: inline; filename=response.txt\r\n"
-> "AuthApproved: true\r\n"
-> "AuthResponse: AA\r\n"
-> "Set-Cookie: JSESSIONID=00007wKfJV3-JFME8QiC_RCDjuI:14j4qkv92; HTTPOnly; Path=/; Secure\r\n"
-> "Set-Cookie: JSESSIONID=0000uW6woWZ84eAJunhFLfJz8hS:14j4qkv92; HTTPOnly; Path=/; Secure\r\n"
-> "Connection: close\r\n"
-> "Content-Type: text/plain\r\n"
-> "Content-Language: en-US\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "\r\n"
-> "1A5 \r\n"
reading 421 bytes...
-> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03MR\xEFk\xDB0\x10\xFD\xDE\xBF\xC2\x1F\xB7\x81[\xC9\xB1\x1D\xBB \x98\x7FtP\xD66!+\xDBGs\xB1o\x99\xC0\x96\x84%{q\xFF\xFA\xC9R\x12f\x10\xDC\xBDw\xBEw\xEF8\xAD\xFB\xA6\x85\xB1k\xC44\x1Cqd1\xFDr\xFB\xF2<'w\xDA\x16\xE0Y5\x1D\x18d$\xA7\xB9C`\x90\x930\x8C\xDE\x13_\xA1\xA1Gm\xE0\xCC\\\xC6\xC5,y\x8B\xD7\x9E\x0E\x130\xA0\x8FV9\x1Fu\xA8`4\xD3\x88\xBE\xFB\xDD;WM\xE1;\xFBJ9\xA8\x1E\r\x97\xE2Rp\x05A,\xEC\x17\xEFNht\xF0,Z\x87\xFF\xE6\xA36^\xE6E\x8A\xD3Q\x1E\x1D\xDC\xC3\xFF\xA8F\xE1P\x98u\x03]7\xA2\xD6,N\xD2\xE0u\t~\x98\x11\xD1x\xD63\x11+\x94\t\xA8W\xE5fa;c\xE0/\xB8\xDC\x9A\xB5\x03\xED\xDEn\xDD>\xB8b\xDFi\x15\xBD\xA5\xBE~u1.\xAC*\\\xAA\xFEH\x81\xECS\x92$\x9F\xED\v\xEDK\x1C\x8E\x03\xF0\x9E)\x98\xFA\xAF\x9D\xB4\xB1\xB8\xB7\xF6\x1Cc\a\x98z\xC3\xFCz}\xD2\fv(8!+\xF6\xFB\xC3\xEEg\xF1\xE28s\x16\r\xEF\x18\xD9\x10J\xB3\x82&!\xA9\xD3:O\xF3*|\x8A\xEA2\x8C\xB34\t\xB3o\xDB$,\xD3\xA2,\xB3tC\xB7E\xE9\xFE\x04\xA5F9\xC3:l\x87,\xDEnI\x1C9\xA2\x9D\xE7h\xD5TR\xE8\xCB\xD6W\x8B7\xE4\xE2\xBAu&\x9B#\xF4 Z{\x1C\xD7cX'2\xDCn\x9C\xD0\a\xB2y\x88\b\xCD\x02\x12?\xC6\xE41\xDA\x06\xFBW/\xB1\xDE\x9CY\x14\xB2\xEA\xF0T?\xBFW\xC5\xA1\xFE\aC\x85\x1DS\x8C\x02\x00\x00"
read 421 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
}}
  end

  def post_scrub
    %q{
opening connection to api.demo.convergepay.com:443...
opened
starting SSL for api.demo.convergepay.com:443...
SSL established
<- "POST /VirtualMerchantDemo/process.do HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.demo.convergepay.com\r\nContent-Length: 616\r\n\r\n"
<- "ssl_merchant_id=000127&ssl_pin=[FILTERED]&ssl_show_form=false&ssl_result_format=ASCII&ssl_user_id=ssltest&ssl_invoice_number=&ssl_description=Test+Transaction&ssl_card_number=[FILTERED]&ssl_exp_date=0919&ssl_cvv2cvc2=[FILTERED]&ssl_cvv2cvc2_indicator=1&ssl_first_name=Longbob&ssl_last_name=Longsen&ssl_avs_address=456+My+Street&ssl_address2=Apt+1&ssl_avs_zip=K1C2N6&ssl_city=Ottawa&ssl_state=ON&ssl_company=Widgets+Inc&ssl_phone=%28555%29555-5555&ssl_country=CA&ssl_email=paul%40domain.com&ssl_cardholder_ip=203.0.113.0&ssl_amount=1.00&ssl_transaction_type=CCSALE"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Wed, 03 Jan 2018 21:40:26 GMT\r\n"
-> "Pragma: no-cache\r\n"
-> "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
-> "Expires: 0\r\n"
-> "Content-Disposition: inline; filename=response.txt\r\n"
-> "AuthApproved: true\r\n"
-> "AuthResponse: AA\r\n"
-> "Set-Cookie: JSESSIONID=00007wKfJV3-JFME8QiC_RCDjuI:14j4qkv92; HTTPOnly; Path=/; Secure\r\n"
-> "Set-Cookie: JSESSIONID=0000uW6woWZ84eAJunhFLfJz8hS:14j4qkv92; HTTPOnly; Path=/; Secure\r\n"
-> "Connection: close\r\n"
-> "Content-Type: text/plain\r\n"
-> "Content-Language: en-US\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "\r\n"
-> "1A5 \r\n"
reading 421 bytes...
-> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03MR\xEFk\xDB0\x10\xFD\xDE\xBF\xC2\x1F\xB7\x81[\xC9\xB1\x1D\xBB \x98\x7FtP\xD66!+\xDBGs\xB1o\x99\xC0\x96\x84%{q\xFF\xFA\xC9R\x12f\x10\xDC\xBDw\xBEw\xEF8\xAD\xFB\xA6\x85\xB1k\xC44\x1Cqd1\xFDr\xFB\xF2<'w\xDA\x16\xE0Y5\x1D\x18d$\xA7\xB9C`\x90\x930\x8C\xDE\x13_\xA1\xA1Gm\xE0\xCC\\\xC6\xC5,y\x8B\xD7\x9E\x0E\x130\xA0\x8FV9\x1Fu\xA8`4\xD3\x88\xBE\xFB\xDD;WM\xE1;\xFBJ9\xA8\x1E\r\x97\xE2Rp\x05A,\xEC\x17\xEFNht\xF0,Z\x87\xFF\xE6\xA36^\xE6E\x8A\xD3Q\x1E\x1D\xDC\xC3\xFF\xA8F\xE1P\x98u\x03]7\xA2\xD6,N\xD2\xE0u\t~\x98\x11\xD1x\xD63\x11+\x94\t\xA8W\xE5fa;c\xE0/\xB8\xDC\x9A\xB5\x03\xED\xDEn\xDD>\xB8b\xDFi\x15\xBD\xA5\xBE~u1.\xAC*\\\xAA\xFEH\x81\xECS\x92$\x9F\xED\v\xEDK\x1C\x8E\x03\xF0\x9E)\x98\xFA\xAF\x9D\xB4\xB1\xB8\xB7\xF6\x1Cc\a\x98z\xC3\xFCz}\xD2\fv(8!+\xF6\xFB\xC3\xEEg\xF1\xE28s\x16\r\xEF\x18\xD9\x10J\xB3\x82&!\xA9\xD3:O\xF3*|\x8A\xEA2\x8C\xB34\t\xB3o\xDB$,\xD3\xA2,\xB3tC\xB7E\xE9\xFE\x04\xA5F9\xC3:l\x87,\xDEnI\x1C9\xA2\x9D\xE7h\xD5TR\xE8\xCB\xD6W\x8B7\xE4\xE2\xBAu&\x9B#\xF4 Z{\x1C\xD7cX'2\xDCn\x9C\xD0\a\xB2y\x88\b\xCD\x02\x12?\xC6\xE41\xDA\x06\xFBW/\xB1\xDE\x9CY\x14\xB2\xEA\xF0T?\xBFW\xC5\xA1\xFE\aC\x85\x1DS\x8C\x02\x00\x00"
read 421 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
}}
  end
end
