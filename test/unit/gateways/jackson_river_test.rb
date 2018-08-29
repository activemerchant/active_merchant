require 'test_helper'

class JacksonRiverTest < Test::Unit::TestCase
  def setup
    @gateway = JacksonRiverGateway.new(api_key: 'login', hostname: 'https://api.example.com/springboard-api/springboard-forms/submit')
    @credit_card = credit_card
    @amount = 100

    @options = {
      first_name: 'Longbob',
      last_name: 'Longsen',
      billing_address: address,
      description: 'Store Purchase',
      form_id: 34467
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '126', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).raises(ActiveMerchant::ResponseError.new(failed_purchase_response))

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'first_name::First Name field is required.', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-'PRE_SCRUBBED'
opening connection to api.example.com:443...
opened
starting SSL for api.example.com:443...
SSL established
<- "POST /springboard-api/springboard-forms/submit?api_key=11111111111111111111111111111111&form_id=34467&offline=true HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded; charset=utf-8\r\nAccept: application/json\r\nAuthorization: Basic Zm9vOmJhcg==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.example.com\r\nContent-Length: 259\r\n\r\n"
<- "address=456+My+Street&address_line_2=Apt+1&amount=1.00&card_expiration_month=9&card_expiration_year=2019&card_number=4111111111111111&city=Ottawa&currency=USD&first_name=Longbob&last_name=Longsen&payment_method=credit&recurs_monthly=recurs&state=ON&zip=K1C2N6"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Wed, 29 Aug 2018 00:43:54 GMT\r\n"
-> "Server: Apache\r\n"
-> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "Expires: Sun, 19 Nov 1978 05:00:00 GMT\r\n"
-> "Cache-Control: no-cache, must-revalidate\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "X-Frame-Options: SameOrigin\r\n"
-> "Vary: Accept\r\n"
-> "Set-Cookie: gs-34467-selected=1.00\r\n"
-> "Set-Cookie: Springboard=b2qJugqJyxIKOUDMcwRHazcugH7TT%2FRV7zeb8mlYqSUAPXp4%2B0MWRMlGgZ86n05BeNkHaTA9s%2Bas2WNCXbVOUhFgjruYYuZeJkZyY3x0GtPQt2keMhsjmjO%2B%2FQC9LIpY%2BVxmR0K8nrRd2eiJ%2BE%2F9kC9mT4NtLgMdt8zMKgaluEE%3D; expires=Sat, 26-Aug-2028 00:43:56 GMT; Max-Age=315360000; path=/\r\n"
-> "Set-Cookie: Springboard=tZkWEQBi6njW3YpXBdA5FgGkL3I61u2YaOAhhr93id94XFcHCJC%2FLTkueTsR1ZmqSDtNbKvqsrAVHjxaiokcl23%2FUZVZoqP8WDWk44EL5bOHsuCl5UyPH5c%2Fhl%2FqJ6bnsXR2QWL8Q49%2BGAS6q0c6LHnJJhDzqrd9zLzu5cBigzkD49GU2X8oDFi%2Fa%2BzHbL8vb3PRbTDr7hte0Si3EFm%2F6WYPEr1Bbw%2Bpu%2BVH1bVSAQBdN2KLdm0cO0v7GUD221yFMIanJWCTdgDHN2bEgO5SltTymRFMAvJMu49X7NNNu%2By01kwuOmfooz5sgOcLWQosbgEOeGj9QexPNGTTC6JFWgk2uOqB1sxMRL4M%2BLT%2FsC93oNRPgqIdIF%2BODZ0%2BA3Eh3DbbaparIfIiVpNcrUn10ev%2BDpj5LfGReKBPMJ1qpmDv%2FiUx85SB3SCf62%2FtAUGlyLPg1OsEj1jSnShDu8U97A1Qj6dFxUjcOjznMhWMgQBoxzIxb3KuTiE0udSts85H; expires=Sat, 26-Aug-2028 00:43:56 GMT; Max-Age=315360000; path=/\r\n"
-> "Set-Cookie: SSESS1ffb8df47221a50eddada80168b84c76=pil5KCcBN0J_CTYl3B51W1lmjBSmUub2YfWE8HyLMEM; expires=Fri, 31-Aug-2018 08:17:16 GMT; Max-Age=200000; path=/; domain=.api.example.com; secure; HttpOnly\r\n"
-> "Content-Length: 58\r\n"
-> "Connection: close\r\n"
-> "Content-Type: application/json\r\n"
-> "\r\n"
reading 58 bytes...
-> "[{\"status\":\"Submission successful\",\"submission_id\":\"126\"}]"
read 58 bytes
Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-'POST_SCRUBBED'
opening connection to api.example.com:443...
opened
starting SSL for api.example.com:443...
SSL established
<- "POST /springboard-api/springboard-forms/submit?api_key=[FILTERED]&form_id=34467&offline=true HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded; charset=utf-8\r\nAccept: application/json\r\nAuthorization: Basic [FILTERED]==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.example.com\r\nContent-Length: 259\r\n\r\n"
<- "address=456+My+Street&address_line_2=Apt+1&amount=1.00&card_expiration_month=9&card_expiration_year=2019&card_number=[FILTERED]&city=Ottawa&currency=USD&first_name=Longbob&last_name=Longsen&payment_method=credit&recurs_monthly=recurs&state=ON&zip=K1C2N6"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Wed, 29 Aug 2018 00:43:54 GMT\r\n"
-> "Server: Apache\r\n"
-> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "Expires: Sun, 19 Nov 1978 05:00:00 GMT\r\n"
-> "Cache-Control: no-cache, must-revalidate\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "X-Frame-Options: SameOrigin\r\n"
-> "Vary: Accept\r\n"
-> "Set-Cookie: gs-34467-selected=1.00\r\n"
-> "Set-Cookie: Springboard=b2qJugqJyxIKOUDMcwRHazcugH7TT%2FRV7zeb8mlYqSUAPXp4%2B0MWRMlGgZ86n05BeNkHaTA9s%2Bas2WNCXbVOUhFgjruYYuZeJkZyY3x0GtPQt2keMhsjmjO%2B%2FQC9LIpY%2BVxmR0K8nrRd2eiJ%2BE%2F9kC9mT4NtLgMdt8zMKgaluEE%3D; expires=Sat, 26-Aug-2028 00:43:56 GMT; Max-Age=315360000; path=/\r\n"
-> "Set-Cookie: Springboard=tZkWEQBi6njW3YpXBdA5FgGkL3I61u2YaOAhhr93id94XFcHCJC%2FLTkueTsR1ZmqSDtNbKvqsrAVHjxaiokcl23%2FUZVZoqP8WDWk44EL5bOHsuCl5UyPH5c%2Fhl%2FqJ6bnsXR2QWL8Q49%2BGAS6q0c6LHnJJhDzqrd9zLzu5cBigzkD49GU2X8oDFi%2Fa%2BzHbL8vb3PRbTDr7hte0Si3EFm%2F6WYPEr1Bbw%2Bpu%2BVH1bVSAQBdN2KLdm0cO0v7GUD221yFMIanJWCTdgDHN2bEgO5SltTymRFMAvJMu49X7NNNu%2By01kwuOmfooz5sgOcLWQosbgEOeGj9QexPNGTTC6JFWgk2uOqB1sxMRL4M%2BLT%2FsC93oNRPgqIdIF%2BODZ0%2BA3Eh3DbbaparIfIiVpNcrUn10ev%2BDpj5LfGReKBPMJ1qpmDv%2FiUx85SB3SCf62%2FtAUGlyLPg1OsEj1jSnShDu8U97A1Qj6dFxUjcOjznMhWMgQBoxzIxb3KuTiE0udSts85H; expires=Sat, 26-Aug-2028 00:43:56 GMT; Max-Age=315360000; path=/\r\n"
-> "Set-Cookie: SSESS1ffb8df47221a50eddada80168b84c76=pil5KCcBN0J_CTYl3B51W1lmjBSmUub2YfWE8HyLMEM; expires=Fri, 31-Aug-2018 08:17:16 GMT; Max-Age=200000; path=/; domain=.api.example.com; secure; HttpOnly\r\n"
-> "Content-Length: 58\r\n"
-> "Connection: close\r\n"
-> "Content-Type: application/json\r\n"
-> "\r\n"
reading 58 bytes...
-> "[{\"status\":\"Submission successful\",\"submission_id\":\"126\"}]"
read 58 bytes
Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    [
      {
        "status" => "Submission successful",
        "submission_id" => "126"
      }
    ].to_json
  end

  def failed_purchase_response
    body = ["first_name::First Name field is required."].to_json

    MockResponse.failed(body, "406")
  end
end
