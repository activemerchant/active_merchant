require 'test_helper'

class QualpayTest < Test::Unit::TestCase
  def setup
    @gateway = QualpayGateway.new(merchant_id: '1234', security_key: '1234')
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

    assert_equal '4ebe68ca2f7511e78c800a12fcf6f1a3', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "005", response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '55fbef8d2f7611e78c800a12fcf6f1a3', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "005", response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, "af267c892f7a11e78c800a12fcf6f1a3", @options)
    assert_success response

    assert_equal 'af267c892f7a11e78c800a12fcf6f1a3', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, "af267c892f7a11e78c800a12fcf6f1a3", @options)
    assert_failure response
    assert_equal "102", response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, "c98b5ef22f7611e78c800a12fcf6f1a3", @options)
    assert_success response

    assert_equal 'c98b5ef22f7611e78c800a12fcf6f1a3', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.refund(@amount, "af267c892f7a11e78c800a12fcf6f1a3", @options)
    assert_failure response
    assert_equal "102", response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void("f578f2242f7611e78c800a12fcf6f1a3", @options)
    assert_success response

    assert_equal 'f578f2242f7611e78c800a12fcf6f1a3', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void("af267c892f7a11e78c800a12fcf6f1a3", @options)
    assert_failure response
    assert_equal "102", response.error_code
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal '779038eb2f7c11e78c800a12fcf6f1a3', response.authorization
    assert response.test?
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal "108", response.error_code
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response

    assert_equal '914333ad2f7c11e78c800a12fcf6f1a3', response.authorization
    assert response.test?
  end

  def test_failed_credit
    @gateway.expects(:ssl_post).returns(failed_credit_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "108", response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
opening connection to api-test.qualpay.com:443...
opened
starting SSL for api-test.qualpay.com:443...
SSL established
<- "POST /pg/sale HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api-test.qualpay.com\r\nContent-Length: 332\r\n\r\n"
<- "{\"amt_tran\":\"1.00\",\"tran_currency\":\"840\",\"merch_ref_num\":\"Store Purchase\",\"card_number\":\"4111111111111111\",\"exp_date\":\"0918\",\"cardholder_name\":\"Longbob Longsen\",\"cvv2\":\"123\",\"avs_address\":\"456 My Street\",\"avs_zip\":\"K1C2N6\",\"merchant_id\":212000135865,\"security_key\":\"aab66c382b9611e782c60a3206e114e0\",\"developer_id\":\"ActiveMerchant\"}"
-> "HTTP/1.1 200 OK\r\n"
-> "Content-Type: application/json\r\n"
-> "Date: Tue, 02 May 2017 20:40:12 GMT\r\n"
-> "Server: nginx/1.11.10\r\n"
-> "Content-Length: 126\r\n"
-> "Connection: Close\r\n"
-> "Set-Cookie: visid_incap_318431=uNKwzgDsQ4yKIVtK3X17EcjuCFkAAAAAQUIPAAAAAADF5ss/urJXeCS3CHMBa+IK; expires=Wed, 02 May 2018 10:04:23 GMT; path=/; Domain=.qualpay.com\r\n"
-> "Set-Cookie: nlbi_318431=wOKrMY0lbk/O3bGp+sC5DQAAAAAbDQQFVMuqwlXwFDejpJfb; path=/; Domain=.qualpay.com\r\n"
-> "Set-Cookie: incap_ses_553_318431=Iht/eh4hIheylxmPzqasB8juCFkAAAAAEsFhHM9N5bcZEhPNyjidRw==; path=/; Domain=.qualpay.com\r\n"
-> "X-Iinfo: 2-59409668-59409685 NNNN CT(37 38 0) RT(1493757640011 104) q(0 0 0 -1) r(1 1) U5\r\n"
-> "X-CDN: Incapsula\r\n"
-> "\r\n"
reading 126 bytes...
-> "{\"rcode\":\"000\",\"rmsg\":\"Approved T53680\",\"pg_id\":\"9b194e582f7711e78c800a12fcf6f1a3\",\"auth_code\":\"T53680\",\"auth_avs_result\":\"A\"}"
read 126 bytes
Conn close
    )
  end

  def post_scrubbed
    %q(
opening connection to api-test.qualpay.com:443...
opened
starting SSL for api-test.qualpay.com:443...
SSL established
<- "POST /pg/sale HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api-test.qualpay.com\r\nContent-Length: 332\r\n\r\n"
<- "{\"amt_tran\":\"1.00\",\"tran_currency\":\"840\",\"merch_ref_num\":\"Store Purchase\",\"card_number\":\"[FILTERED]\",\"exp_date\":\"0918\",\"cardholder_name\":\"Longbob Longsen\",\"cvv2\":\"[FILTERED]\",\"avs_address\":\"456 My Street\",\"avs_zip\":\"K1C2N6\",\"merchant_id\":212000135865,\"security_key\":\"[FILTERED]\",\"developer_id\":\"ActiveMerchant\"}"
-> "HTTP/1.1 200 OK\r\n"
-> "Content-Type: application/json\r\n"
-> "Date: Tue, 02 May 2017 20:40:12 GMT\r\n"
-> "Server: nginx/1.11.10\r\n"
-> "Content-Length: 126\r\n"
-> "Connection: Close\r\n"
-> "Set-Cookie: visid_incap_318431=uNKwzgDsQ4yKIVtK3X17EcjuCFkAAAAAQUIPAAAAAADF5ss/urJXeCS3CHMBa+IK; expires=Wed, 02 May 2018 10:04:23 GMT; path=/; Domain=.qualpay.com\r\n"
-> "Set-Cookie: nlbi_318431=wOKrMY0lbk/O3bGp+sC5DQAAAAAbDQQFVMuqwlXwFDejpJfb; path=/; Domain=.qualpay.com\r\n"
-> "Set-Cookie: incap_ses_553_318431=Iht/eh4hIheylxmPzqasB8juCFkAAAAAEsFhHM9N5bcZEhPNyjidRw==; path=/; Domain=.qualpay.com\r\n"
-> "X-Iinfo: 2-59409668-59409685 NNNN CT(37 38 0) RT(1493757640011 104) q(0 0 0 -1) r(1 1) U5\r\n"
-> "X-CDN: Incapsula\r\n"
-> "\r\n"
reading 126 bytes...
-> "{\"rcode\":\"000\",\"rmsg\":\"Approved T53680\",\"pg_id\":\"9b194e582f7711e78c800a12fcf6f1a3\",\"auth_code\":\"T53680\",\"auth_avs_result\":\"A\"}"
read 126 bytes
Conn close
    )
  end

  def successful_purchase_response
    "{\"rcode\":\"000\",\"rmsg\":\"Approved T07875\",\"pg_id\":\"4ebe68ca2f7511e78c800a12fcf6f1a3\",\"auth_code\":\"T07875\",\"auth_avs_result\":\"A\"}"
  end

  def failed_purchase_response
    "{\"rcode\":\"005\",\"rmsg\":\"Decline\",\"pg_id\":\"3bc3711c2f7611e78c800a12fcf6f1a3\",\"auth_avs_result\":\"A\"}"
  end

  def successful_authorize_response
    "{\"rcode\":\"000\",\"rmsg\":\"Approved T15954\",\"pg_id\":\"55fbef8d2f7611e78c800a12fcf6f1a3\",\"auth_code\":\"T15954\",\"auth_avs_result\":\"A\"}"
  end

  def failed_authorize_response
    "{\"rcode\":\"005\",\"rmsg\":\"Decline\",\"pg_id\":\"9d9abe7f2f7611e78c800a12fcf6f1a3\",\"auth_avs_result\":\"A\"}"
  end

  def successful_capture_response
    "{\"rcode\":\"000\",\"rmsg\":\"Capture request accepted\",\"pg_id\":\"af267c892f7a11e78c800a12fcf6f1a3\"}"
  end

  def failed_capture_response
    "{\"rcode\":\"102\",\"rmsg\":\"Invalid PG Identifier\",\"pg_id\":\"1234\"}"
  end

  def successful_refund_response
    "{\"rcode\":\"000\",\"rmsg\":\"Refund request accepted\",\"pg_id\":\"c98b5ef22f7611e78c800a12fcf6f1a3\"}"
  end

  def failed_refund_response
    "{\"rcode\":\"102\",\"rmsg\":\"Invalid PG Identifier\",\"pg_id\":\"e0a908d32f7611e78c800a12fcf6f1a3\"}"
  end

  def successful_void_response
    "{\"rcode\":\"000\",\"rmsg\":\"Transaction voided\",\"pg_id\":\"f578f2242f7611e78c800a12fcf6f1a3\"}"
  end

  def failed_void_response
    "{\"rcode\":\"102\",\"rmsg\":\"Invalid PG Identifier\",\"pg_id\":\"1234\"}"
  end

  def successful_verify_response
    "{\"rcode\":\"085\",\"rmsg\":\"No reason to decline T09565\",\"pg_id\":\"779038eb2f7c11e78c800a12fcf6f1a3\",\"auth_code\":\"T09565\",\"auth_avs_result\":\"A\"}"
  end

  def failed_verify_response
    "{\"rcode\":\"108\",\"rmsg\":\"Invalid card number (failed mod 10)\",\"pg_id\":\"86f0130c2f7c11e78c800a12fcf6f1a3\"}"
  end

  def successful_credit_response
    "{\"rcode\":\"000\",\"rmsg\":\"Credit transaction accepted\",\"pg_id\":\"914333ad2f7c11e78c800a12fcf6f1a3\"}"
  end

  def failed_credit_response
    "{\"rcode\":\"108\",\"rmsg\":\"Invalid card number (failed mod 10)\",\"pg_id\":\"b499870e2f7c11e78c800a12fcf6f1a3\"}"
  end
end
