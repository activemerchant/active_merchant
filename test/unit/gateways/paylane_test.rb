require 'test_helper'

class PaylaneTest < Test::Unit::TestCase
  def setup
    @gateway = PaylaneGateway.new(login: 'tt', password: 'aa', apikey: 'zz')
    @credit_card = ActiveMerchant::Billing::CreditCard.new(
        :number             => 4111111111111111,
        :month              => 2,
        :year               => 2019,
        :first_name         => 'Bob',
        :last_name          => 'Smith',
        :verification_value => '847',
        :brand              => 'visa'
    )
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

    assert_equal 11535593, response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.stubs(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 643788, response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, '1234', @options)
    assert_success response
    assert_equal 11535603, response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, '1234', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, '1234', @options)
    assert_success response
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, '1234', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('1234', @options)
    assert_success response
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('1234', @options)
    assert_failure response
  end

  def test_successful_verify
    @gateway.stubs(:ssl_post).returns(successful_authorize_response, successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_successful_verify_with_failed_void
    @gateway.stubs(:ssl_post).returns(successful_authorize_response, failed_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response.responses[1]
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to direct.paylane.com:443...
opened
starting SSL for direct.paylane.com:443...
SSL established
<- "POST /rest/cards/sale HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic dGVzdC1hcGktbW9sZWpuaWs6c3BhNmR1NWI=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: direct.paylane.com\r\nContent-Length: 381\r\n\r\n"
<- "{\"sale\":{\"amount\":\"100.00\",\"currency\":\"USD\",\"description\":\"Store Purchase\"},\"card\":{\"card_number\":\"4111111111111111\",\"expiration_month\":\"09\",\"expiration_year\":\"2019\",\"name_on_card\":\"Longbob Longsen\",\"card_code\":\"123\"},\"customer\":{\"ip\":\"127.0.0.1\",\"email\":\"joe@example.com\",\"address\":{\"street_house\":\"456 My Street\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"country_code\":\"CA\"}}}"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 30 Jan 2018 20:07:18 GMT\r\n"
-> "Content-Type: application/json\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "Connection: close\r\n"
-> "Set-Cookie: __cfduid=d763aef0a47d629696b8afd3bb2479b1f1517343029; expires=Wed, 30-Jan-19 20:07:16 GMT; path=/; domain=.paylane.com; HttpOnly\r\n"
-> "Expect-CT: max-age=604800, report-uri=\"https://report-uri.cloudflare.com/cdn-cgi/beacon/expect-ct\"\r\n"
-> "Server: cloudflare\r\n"
-> "CF-RAY: 3e570e79989e6b07-WAW\r\n"
-> "Content-Encoding: gzip\r\n"
-> "\r\n"
    )
  end

  def post_scrubbed
    %q(
      opening connection to direct.paylane.com:443...
opened
starting SSL for direct.paylane.com:443...
SSL established
<- "POST /rest/cards/sale HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: direct.paylane.com\r\nContent-Length: 381\r\n\r\n"
<- "{\"sale\":{\"amount\":\"100.00\",\"currency\":\"USD\",\"description\":\"Store Purchase\"},\"card\":{\"card_number\":\"[FILTERED]\",\"expiration_month\":\"09\",\"expiration_year\":\"2019\",\"name_on_card\":\"Longbob Longsen\",\"card_code\":\"[FILTERED]\"},\"customer\":{\"ip\":\"127.0.0.1\",\"email\":\"joe@example.com\",\"address\":{\"street_house\":\"456 My Street\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"country_code\":\"CA\"}}}"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 30 Jan 2018 20:07:18 GMT\r\n"
-> "Content-Type: application/json\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "Connection: close\r\n"
-> "Set-Cookie: __cfduid=d763aef0a47d629696b8afd3bb2479b1f1517343029; expires=Wed, 30-Jan-19 20:07:16 GMT; path=/; domain=.paylane.com; HttpOnly\r\n"
-> "Expect-CT: max-age=604800, report-uri=\"https://report-uri.cloudflare.com/cdn-cgi/beacon/expect-ct\"\r\n"
-> "Server: cloudflare\r\n"
-> "CF-RAY: 3e570e79989e6b07-WAW\r\n"
-> "Content-Encoding: gzip\r\n"
-> "\r\n"
    )
  end

  def successful_purchase_response
    %q({"success":true,"id_sale":11535593,"id_account":30079})
  end

  def failed_purchase_response
    %q({"success":false,"error":{"error_number":303,"error_description":"Direct debit declined.","id_error":4223206},"id_account":30079})
  end

  def successful_authorize_response
    %q({"success":true,"id_authorization":643788,"id_account":30079})
  end

  def failed_authorize_response
    %q({"success":false,"error":{"error_number":303,"error_description":"Direct debit declined.","id_error":4223207},"id_account":30079})
  end

  def successful_capture_response
    %q({"success":true,"id_sale":11535603,"id_account":30079})
  end

  def failed_capture_response
    %q({"success":false,"error":{"error_number":442,"error_description":"Sale authorization ID 0 not found."},"id_account":30079})
  end

  def successful_refund_response
    %q({"success":true,"id_refund":444343})
  end

  def failed_refund_response
    %q({"success":false,"error":{"error_number":476,"error_description":"Sale ID 0 not found."}})
  end

  def successful_void_response
    %q({"success":true})
  end

  def failed_void_response
    %q({"success":false,"error":{"error_number":442,"error_description":"Sale authorization ID 0 not found."}})
  end

  def successful_verify_response
    %q({"success":true})
  end

  def failed_verify_response
    %q({"success":false,"error":{"error_number":313,"error_description":"Customer name is not valid.","id_error":4223247},"id_account":30079})
  end
end
