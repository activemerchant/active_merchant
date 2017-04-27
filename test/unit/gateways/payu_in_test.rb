require "test_helper"

class PayuInTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PayuInGateway.new(
      key: "key",
      salt: "salt"
    )

    @credit_card = credit_card

    @options = {
      order_id: "1"
    }
  end

  def assert_parameter(parameter, expected_value, data, options={})
    assert (data =~ %r{(?:^|&)#{parameter}=([^&]*)(?:&|$)}), "Unable to find #{parameter} in #{data}"
    value = CGI.unescape($1 || "")
    case expected_value
    when Regexp
      assert_match expected_value, value, "#{parameter} value does not match expected"
    else
      assert_equal expected_value.to_s, value, "#{parameter} value does not match expected"
    end
    if options[:length]
      assert_equal options[:length], value.length, "#{parameter} value of #{value} is the wrong length"
    end
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(100, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_equal "identity", headers["Accept-Encoding"]
      case endpoint
      when /_payment/
        assert_parameter("amount", "1.00", data)
        assert_parameter("txnid", "1", data)
        assert_parameter("productinfo", "Purchase", data)
        assert_parameter("surl", "http://example.com", data)
        assert_parameter("furl", "http://example.com", data)
        assert_parameter("pg", "CC", data)
        assert_parameter("firstname", @credit_card.first_name, data)
        assert_parameter("bankcode", @credit_card.brand.upcase, data)
        assert_parameter("ccnum", @credit_card.number, data)
        assert_parameter("ccvv", @credit_card.verification_value, data)
        assert_parameter("ccname", @credit_card.name, data)
        assert_parameter("ccexpmon", "%02d" % @credit_card.month.to_i, data)
        assert_parameter("ccexpyr", @credit_card.year, data)
        assert_parameter("email", "unknown@example.com", data)
        assert_parameter("phone", "11111111111", data)
        assert_parameter("key", "key", data)
        assert_parameter("txn_s2s_flow", "1", data)
        assert_parameter("hash", "5199c0735c21d647f287a2781024743d35fabfd640bc20f2ae7b5277e3d7d06fa315fcdda266cfa64920517944244c632e5f38768481626b22e2b0d70c806d60", data)
      when /hdfc_not_enrolled/
        assert_parameter("transactionId", "6e7e62723683934e6c5507675df11bdd86197c5c935878ff72e344205f3c8a1d", data)
        assert_parameter("pgId", "8", data)
        assert_parameter("eci", "7", data)
        assert_parameter("nonEnrolled", "1", data)
        assert_parameter("nonDomestic", "0", data)
        assert_parameter("bank", "VISA", data)
        assert_parameter("cccat", "creditcard", data)
        assert_parameter("ccnum", "4b5c9002295c6cd8e5289e2f9c312dc737810a747b84e71665cf077c78fe245a", data)
        assert_parameter("ccname", "53ab689fdb1b025c7e9c53c6b4a6e27f51e0d627579e7c12af2cb6cbc4944cc0", data)
        assert_parameter("ccvv", "cc8d6cfb6b03f94e2a64b490ae10c261c10747f543b1fba09d7f56f9ef6aac04", data)
        assert_parameter("ccexpmon", "5ddf3702e74f473ec89762f6efece025737c2ab999e695cf10496e6fa3946079", data)
        assert_parameter("ccexpyr", "5da83563fcaa945063dc4c2094c48e800badf7c8246c9d13b43757fe99d63e6d", data)
        assert_parameter("is_seamless", "1", data)
      else
        flunk "Unknown endpoint #{endpoint}"
      end
    end.respond_with(successful_purchase_setup_response, successful_purchase_response)

    assert_success response

    assert_equal "403993715512145540", response.authorization
    assert_equal "No Error", response.message
    assert response.test?
  end

  def test_successful_purchase_with_full_options
    response = stub_comms do
      @gateway.purchase(
        100,
        credit_card("4242424242424242", name: "Bobby Jimbob", verification_value: "678", month: "4", year: "2015"),
        order_id: "99",
        description: "Awesome!",
        email: "jim@example.com",
        billing_address: {
          name: "Jim Smith",
          address1: "123 Road",
          address2: "Suite 123",
          city: "Somewhere",
          state: "ZZ",
          country: "US",
          zip: "12345",
          phone: "12223334444"
        },
        shipping_address: {
          name: "Joe Bob",
          address1: "987 Street",
          address2: "Suite 987",
          city: "Anyplace",
          state: "AA",
          country: "IN",
          zip: "98765",
          phone: "98887776666"
        }
      )
    end.check_request do |endpoint, data, headers|
      assert_equal "identity", headers["Accept-Encoding"]
      case endpoint
      when /_payment/
        assert_parameter("amount", "1.00", data)
        assert_parameter("txnid", "99", data)
        assert_parameter("productinfo", "Awesome!", data)
        assert_parameter("surl", "http://example.com", data)
        assert_parameter("furl", "http://example.com", data)
        assert_parameter("pg", "CC", data)
        assert_parameter("firstname", "Bobby", data)
        assert_parameter("lastname", "Jimbob", data)
        assert_parameter("bankcode", "VISA", data)
        assert_parameter("ccnum", "4242424242424242", data)
        assert_parameter("ccvv", "678", data)
        assert_parameter("ccname", "Bobby Jimbob", data)
        assert_parameter("ccexpmon", "04", data)
        assert_parameter("ccexpyr", "2015", data)
        assert_parameter("email", "jim@example.com", data)
        assert_parameter("phone", "12223334444", data)
        assert_parameter("key", "key", data)
        assert_parameter("txn_s2s_flow", "1", data)
        assert_parameter("hash", "1ee17ee9615b55fdee4cd92cee4f28bd88e0c7ff16bd7525cb7b0a792728502f71ffba37606b1b77504d1d0b9d520d39cb1829fffd1aa5eef27dfa4c4a887f61", data)
        assert_parameter("address1", "123 Road", data)
        assert_parameter("address2", "Suite 123", data)
        assert_parameter("city", "Somewhere", data)
        assert_parameter("state", "ZZ", data)
        assert_parameter("country", "US", data)
        assert_parameter("zipcode", "12345", data)
        assert_parameter("shipping_firstname", "Joe", data)
        assert_parameter("shipping_lastname", "Bob", data)
        assert_parameter("shipping_address1", "987 Street", data)
        assert_parameter("shipping_address2", "Suite 987", data)
        assert_parameter("shipping_city", "Anyplace", data)
        assert_parameter("shipping_state", "AA", data)
        assert_parameter("shipping_country", "IN", data)
        assert_parameter("shipping_zipcode", "98765", data)
        assert_parameter("shipping_phone", "98887776666", data)
      when /hdfc_not_enrolled/
        assert_parameter("transactionId", "6e7e62723683934e6c5507675df11bdd86197c5c935878ff72e344205f3c8a1d", data)
        assert_parameter("pgId", "8", data)
        assert_parameter("eci", "7", data)
        assert_parameter("nonEnrolled", "1", data)
        assert_parameter("nonDomestic", "0", data)
        assert_parameter("bank", "VISA", data)
        assert_parameter("cccat", "creditcard", data)
        assert_parameter("ccnum", "4b5c9002295c6cd8e5289e2f9c312dc737810a747b84e71665cf077c78fe245a", data)
        assert_parameter("ccname", "53ab689fdb1b025c7e9c53c6b4a6e27f51e0d627579e7c12af2cb6cbc4944cc0", data)
        assert_parameter("ccvv", "cc8d6cfb6b03f94e2a64b490ae10c261c10747f543b1fba09d7f56f9ef6aac04", data)
        assert_parameter("ccexpmon", "5ddf3702e74f473ec89762f6efece025737c2ab999e695cf10496e6fa3946079", data)
        assert_parameter("ccexpyr", "5da83563fcaa945063dc4c2094c48e800badf7c8246c9d13b43757fe99d63e6d", data)
        assert_parameter("is_seamless", "1", data)
      else
        flunk "Unknown endpoint #{endpoint}"
      end
    end.respond_with(successful_purchase_setup_response, successful_purchase_response)

    assert_success response
  end

  def test_input_constraint_cleanup
    response = stub_comms do
      @gateway.purchase(
        100,
        credit_card(
          "4242424242424242",
          first_name: ("3" + ("a" * 61)),
          last_name: ("3" + ("a" * 21)),
          month: "4",
          year: "2015"
        ),
        order_id: ("!@#" + ("a" * 31)),
        description: ("a" * 101),
        email: ("c" * 51),
        billing_address: {
          name: "Jim Smith",
          address1: ("!#$%^&'\"()" + "Aa0@-_/ ." + ("a" * 101)),
          address2: ("!#$%^&'\"()" + "Aa0@-_/ ." + ("a" * 101)),
          city: ("!#$%^&'\"()" + "Aa0@-_/ ." + ("a" * 51)),
          state: ("!#$%^&'\"()" + "Aa0@-_/ ." + ("a" * 51)),
          country: ("!#$%^&'\"()" + "Aa0@-_/ ." + ("a" * 51)),
          zip: ("a-" + ("1" * 21)),
          phone: ("a-" + ("1" * 51))
        },
        shipping_address: {
          name: (("3" + ("a" * 61)) + " " + ("3" + ("a" * 21))),
          address1: ("!#$%^&'\"()" + "Aa0@-_/ ." + ("a" * 101)),
          address2: ("!#$%^&'\"()" + "Aa0@-_/ ." + ("a" * 101)),
          city: ("!#$%^&'\"()" + "Aa0@-_/ ." + ("a" * 51)),
          state: ("!#$%^&'\"()" + "Aa0@-_/ ." + ("a" * 51)),
          country: ("!#$%^&'\"()" + "Aa0@-_/ ." + ("a" * 51)),
          zip: ("a-" + ("1" * 21)),
          phone: ("a-" + ("1" * 51))
        }
      )
    end.check_request do |endpoint, data, headers|
      case endpoint
      when /_payment/
        assert_parameter("txnid", /^a/, data, length: 30)
        assert_parameter("productinfo", /^a/, data, length: 100)
        assert_parameter("firstname", /^a/, data, length: 60)
        assert_parameter("lastname", /^a/, data, length: 20)
        assert_parameter("email", /^c/, data, length: 50)
        assert_parameter("phone", /^\d/, data, length: 50)
        assert_parameter("address1", /^Aa0@-_\/ \.a/, data, length: 100)
        assert_parameter("address2", /^Aa0@-_\/ \.a/, data, length: 100)
        assert_parameter("city", /^Aa0@-_\/ \.a/, data, length: 50)
        assert_parameter("state", /^Aa0@-_\/ \.a/, data, length: 50)
        assert_parameter("country", /^Aa0@-_\/ \.a/, data, length: 50)
        assert_parameter("zipcode", /^1/, data, length: 20)
        assert_parameter("shipping_firstname", /^a/, data, length: 60)
        assert_parameter("shipping_lastname", /^a/, data, length: 20)
        assert_parameter("shipping_address1", /^Aa0@-_\/ \.a/, data, length: 100)
        assert_parameter("shipping_address2", /^Aa0@-_\/ \.a/, data, length: 100)
        assert_parameter("shipping_city", /^Aa0@-_\/ \.a/, data, length: 50)
        assert_parameter("shipping_state", /^Aa0@-_\/ \.a/, data, length: 50)
        assert_parameter("shipping_country", /^Aa0@-_\/ \.a/, data, length: 50)
        assert_parameter("shipping_zipcode", /^1/, data, length: 20)
        assert_parameter("shipping_phone", /^\d/, data, length: 50)
      end
    end.respond_with(successful_purchase_setup_response, successful_purchase_response)

    assert_success response
  end

  def test_brand_mappings
    stub_comms do
      @gateway.purchase(100, credit_card("4242424242424242", brand: :visa), @options)
    end.check_request do |endpoint, data, _|
      case endpoint
      when /_payment/
        assert_parameter("bankcode", "VISA", data)
      end
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.purchase(100, credit_card("4242424242424242", brand: :master), @options)
    end.check_request do |endpoint, data, _|
      case endpoint
      when /_payment/
        assert_parameter("bankcode", "MAST", data)
      end
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.purchase(100, credit_card("4242424242424242", brand: :american_express), @options)
    end.check_request do |endpoint, data, _|
      case endpoint
      when /_payment/
        assert_parameter("bankcode", "AMEX", data)
      end
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.purchase(100, credit_card("4242424242424242", brand: :diners_club), @options)
    end.check_request do |endpoint, data, _|
      case endpoint
      when /_payment/
        assert_parameter("bankcode", "DINR", data)
      end
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.purchase(100, credit_card("4242424242424242", brand: :maestro), @options)
    end.check_request do |endpoint, data, _|
      case endpoint
      when /_payment/
        assert_parameter("bankcode", "MAES", data)
      end
    end.respond_with(successful_purchase_response)
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(100, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid amount  @~@ ExceptionConstant : INVALID_AMOUNT", response.message
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(100, "abc")
    end.check_request do |endpoint, data, headers|
      assert_parameter("command", "cancel_refund_transaction", data)
      assert_parameter("var1", "abc", data)
      assert_parameter("var2", /./, data)
      assert_parameter("var3", "1.00", data)
      assert_parameter("key", "key", data)
      assert_parameter("txn_s2s_flow", "1", data)
      assert_parameter("hash", "06ee55774af4e3eee3f946d4079d34efca243453199b0d4a1328f248b93428ed5c6342c6d73010c0b86d19afc04ae7a1c62c68c472cc0811d00a9a10ecf28791", data)
    end.respond_with(successful_refund_response)

    assert_success response
    assert_equal "Refund Request Queued", response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(100, "abc")
    assert_failure response
    assert_equal "Invalid payuid", response.message
  end

  def test_refund_without_amount
    assert_raise ArgumentError do
      @gateway.refund(nil, "abc")
    end
  end

  def test_3dsecure_cards_fail
    @gateway.expects(:ssl_post).returns(threedsecure_enrolled_response)

    response = @gateway.purchase(100, @credit_card, @options)
    assert_failure response
    assert_equal "3D-secure enrolled cards are not supported.", response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_invalid_json
    @gateway.expects(:ssl_post).returns(invalid_json_response)

    response = @gateway.purchase(100, @credit_card, @options)
    assert_failure response
    assert_match %r{html}, response.message
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
opening connection to test.payu.in:443...
opened
starting SSL for test.payu.in:443...
SSL established
<- "POST /_payment HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: test.payu.in\r\nContent-Length: 460\r\n\r\n"
<- "amount=1.00&txnid=19ceaa9a230d3057dba07b78ad5c7d46&productinfo=Store+Purchase&surl=http%3A%2F%2Fexample.com&furl=http%3A%2F%2Fexample.com&pg=CC&firstname=Longbob&bankcode=VISA&ccnum=5123456789012346&ccvv=123&ccname=Longbob+Longsen&ccexpmon=5&ccexpyr=2017&email=unknown%40example.com&phone=11111111111&key=Gzv04m&txn_s2s_flow=1&hash=a255c1b5107556b7f00b7c5bbebf92392ec4d2c0675253ca20ef459d4259775efbeae039b59357ddd42374d278dedb432f2e9c238acc6358afe9b22cf908fbb3"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Fri, 08 May 2015 15:41:17 GMT\r\n"
-> "Server: Apache\r\n"
-> "P3P: CP=\"IDC DSP COR ADM DEVi TAIi PSA PSD IVAi IVDi CONi HIS OUR IND CNT\"\r\n"
-> "Set-Cookie: PHPSESSID=ud24vi12os6m7f7g0lpmked4a0; path=/; secure; HttpOnly\r\n"
-> "Expires: Thu, 19 Nov 1981 08:52:00 GMT\r\n"
-> "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
-> "Pragma: no-cache\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Content-Length: 691\r\n"
-> "Connection: close\r\n"
-> "Content-Type: text/html; charset=UTF-8\r\n"
-> "\r\n"
reading 691 bytes...
-> ""
-> "{\"status\":\"success\",\"response\":{\"form_post_vars\":{\"transactionId\":\"b84436e889cf6864a9fa2ab267f3f76a766ad6437b017ccb5093e8217996b814\",\"pgId\":\"8\",\"eci\":\"7\",\"nonEnrolled\":1,\"nonDomestic\":0,\"bank\":\"VISA\",\"cccat\":\"creditcard\",\"ccnum\":\"4b5c9002295c6cd8e5289e2f9c312dc737810a747b84e71665cf077c78fe245a\",\"ccname\":\"53ab689fdb1b025c7e9c53c6b4a6e27f51e0d627579e7c12af2cb6cbc4944cc0\",\"ccvv\":\"f31c6a1d6582f44ee1be4a3e1126b9cb08d1e7006f7afe083d7270b00dcb933f\",\"ccexpmon\":\"5ddf3702e74f473ec89762f6efece025737c2ab999e695cf10496e6fa3946079\",\"ccexpyr\":\"5da83563fcaa945063dc4c2094c48e800badf7c8246c9d13b43757fe99d63e6d\",\"is_seamless\":\"1\"},\"post_uri\":\"https:\\/\\/test.payu.in\\/hdfc_not_enrolled\",\"enrolled\":\"0\"}}"
read 691 bytes
Conn close
opening connection to test.payu.in:443...
opened
starting SSL for test.payu.in:443...
SSL established
<- "POST /hdfc_not_enrolled HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: test.payu.in\r\nContent-Length: 520\r\n\r\n"
<- "transactionId=b84436e889cf6864a9fa2ab267f3f76a766ad6437b017ccb5093e8217996b814&pgId=8&eci=7&nonEnrolled=1&nonDomestic=0&bank=VISA&cccat=creditcard&ccnum=4b5c9002295c6cd8e5289e2f9c312dc737810a747b84e71665cf077c78fe245a&ccname=53ab689fdb1b025c7e9c53c6b4a6e27f51e0d627579e7c12af2cb6cbc4944cc0&ccvv=f31c6a1d6582f44ee1be4a3e1126b9cb08d1e7006f7afe083d7270b00dcb933f&ccexpmon=5ddf3702e74f473ec89762f6efece025737c2ab999e695cf10496e6fa3946079&ccexpyr=5da83563fcaa945063dc4c2094c48e800badf7c8246c9d13b43757fe99d63e6d&is_seamless=1"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Fri, 08 May 2015 15:41:27 GMT\r\n"
-> "Server: Apache\r\n"
-> "P3P: CP=\"IDC DSP COR ADM DEVi TAIi PSA PSD IVAi IVDi CONi HIS OUR IND CNT\"\r\n"
-> "Set-Cookie: PHPSESSID=n717g1mr5lvht96ukdobu6m344; path=/; secure; HttpOnly\r\n"
-> "Expires: Thu, 19 Nov 1981 08:52:00 GMT\r\n"
-> "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
-> "Pragma: no-cache\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Content-Length: 1012\r\n"
-> "Connection: close\r\n"
-> "Content-Type: text/html; charset=UTF-8\r\n"
-> "\r\n"
reading 1012 bytes...
-> ""
-> "{\"status\":\"success\",\"result\":\"mihpayid=403993715511983692&mode=CC&status=success&key=Gzv04m&txnid=19ceaa9a230d3057dba07b78ad5c7d46&amount=1.00&addedon=2015-05-08+21%3A11%3A17&productinfo=Store+Purchase&firstname=Longbob&lastname=&address1=&address2=&city=&state=&country=&zipcode=&email=unknown%40example.com&phone=11111111111&udf1=&udf2=&udf3=&udf4=&udf5=&udf6=&udf7=&udf8=&udf9=&udf10=&card_token=&card_no=512345XXXXXX2346&field0=&field1=512816420000&field2=999999&field3=6816991112151281&field4=-1&field5=&field6=&field7=&field8=&field9=SUCCESS&PG_TYPE=HDFCPG&error=E000&error_Message=No+Error&net_amount_debit=1&unmappedstatus=success&hash=c0d3e5346c37ddd32bb3b386ed1d0709a612d304180e7a25dcbf047cc1c3a4e9de9940af0179c6169c0038b2a826d7ea4b868fcbc4e435928e8cbd25da3c1e56&bank_ref_no=6816991112151281&bank_ref_num=6816991112151281&bankcode=VISA&surl=http%3A%2F%2Fexample.com&curl=http%3A%2F%2Fexample.com&furl=http%3A%2F%2Fexample.com&card_hash=f25e4f9ea802050c23423966d35adc54046f651f0d9a2b837b49c75f964d1fa7\"}"
read 1012 bytes
Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
opening connection to test.payu.in:443...
opened
starting SSL for test.payu.in:443...
SSL established
<- "POST /_payment HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: test.payu.in\r\nContent-Length: 460\r\n\r\n"
<- "amount=1.00&txnid=19ceaa9a230d3057dba07b78ad5c7d46&productinfo=Store+Purchase&surl=http%3A%2F%2Fexample.com&furl=http%3A%2F%2Fexample.com&pg=CC&firstname=Longbob&bankcode=VISA&ccnum=[FILTERED]&ccvv=[FILTERED]&ccname=Longbob+Longsen&ccexpmon=5&ccexpyr=2017&email=unknown%40example.com&phone=11111111111&key=Gzv04m&txn_s2s_flow=1&hash=a255c1b5107556b7f00b7c5bbebf92392ec4d2c0675253ca20ef459d4259775efbeae039b59357ddd42374d278dedb432f2e9c238acc6358afe9b22cf908fbb3"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Fri, 08 May 2015 15:41:17 GMT\r\n"
-> "Server: Apache\r\n"
-> "P3P: CP=\"IDC DSP COR ADM DEVi TAIi PSA PSD IVAi IVDi CONi HIS OUR IND CNT\"\r\n"
-> "Set-Cookie: PHPSESSID=ud24vi12os6m7f7g0lpmked4a0; path=/; secure; HttpOnly\r\n"
-> "Expires: Thu, 19 Nov 1981 08:52:00 GMT\r\n"
-> "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
-> "Pragma: no-cache\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Content-Length: 691\r\n"
-> "Connection: close\r\n"
-> "Content-Type: text/html; charset=UTF-8\r\n"
-> "\r\n"
reading 691 bytes...
-> ""
-> "{\"status\":\"success\",\"response\":{\"form_post_vars\":{\"transactionId\":\"b84436e889cf6864a9fa2ab267f3f76a766ad6437b017ccb5093e8217996b814\",\"pgId\":\"8\",\"eci\":\"7\",\"nonEnrolled\":1,\"nonDomestic\":0,\"bank\":\"VISA\",\"cccat\":\"creditcard\",\"ccnum\":\"[FILTERED]\",\"ccname\":\"53ab689fdb1b025c7e9c53c6b4a6e27f51e0d627579e7c12af2cb6cbc4944cc0\",\"ccvv\":\"[FILTERED]\",\"ccexpmon\":\"5ddf3702e74f473ec89762f6efece025737c2ab999e695cf10496e6fa3946079\",\"ccexpyr\":\"5da83563fcaa945063dc4c2094c48e800badf7c8246c9d13b43757fe99d63e6d\",\"is_seamless\":\"1\"},\"post_uri\":\"https:\\/\\/test.payu.in\\/hdfc_not_enrolled\",\"enrolled\":\"0\"}}"
read 691 bytes
Conn close
opening connection to test.payu.in:443...
opened
starting SSL for test.payu.in:443...
SSL established
<- "POST /hdfc_not_enrolled HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: test.payu.in\r\nContent-Length: 520\r\n\r\n"
<- "transactionId=b84436e889cf6864a9fa2ab267f3f76a766ad6437b017ccb5093e8217996b814&pgId=8&eci=7&nonEnrolled=1&nonDomestic=0&bank=VISA&cccat=creditcard&ccnum=[FILTERED]&ccname=53ab689fdb1b025c7e9c53c6b4a6e27f51e0d627579e7c12af2cb6cbc4944cc0&ccvv=[FILTERED]&ccexpmon=5ddf3702e74f473ec89762f6efece025737c2ab999e695cf10496e6fa3946079&ccexpyr=5da83563fcaa945063dc4c2094c48e800badf7c8246c9d13b43757fe99d63e6d&is_seamless=1"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Fri, 08 May 2015 15:41:27 GMT\r\n"
-> "Server: Apache\r\n"
-> "P3P: CP=\"IDC DSP COR ADM DEVi TAIi PSA PSD IVAi IVDi CONi HIS OUR IND CNT\"\r\n"
-> "Set-Cookie: PHPSESSID=n717g1mr5lvht96ukdobu6m344; path=/; secure; HttpOnly\r\n"
-> "Expires: Thu, 19 Nov 1981 08:52:00 GMT\r\n"
-> "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
-> "Pragma: no-cache\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Content-Length: 1012\r\n"
-> "Connection: close\r\n"
-> "Content-Type: text/html; charset=UTF-8\r\n"
-> "\r\n"
reading 1012 bytes...
-> ""
-> "{\"status\":\"success\",\"result\":\"mihpayid=403993715511983692&mode=CC&status=success&key=Gzv04m&txnid=19ceaa9a230d3057dba07b78ad5c7d46&amount=1.00&addedon=2015-05-08+21%3A11%3A17&productinfo=Store+Purchase&firstname=Longbob&lastname=&address1=&address2=&city=&state=&country=&zipcode=&email=unknown%40example.com&phone=11111111111&udf1=&udf2=&udf3=&udf4=&udf5=&udf6=&udf7=&udf8=&udf9=&udf10=&card_token=&card_no=512345XXXXXX2346&field0=&field1=512816420000&field2=999999&field3=6816991112151281&field4=-1&field5=&field6=&field7=&field8=&field9=SUCCESS&PG_TYPE=HDFCPG&error=E000&error_Message=No+Error&net_amount_debit=1&unmappedstatus=success&hash=c0d3e5346c37ddd32bb3b386ed1d0709a612d304180e7a25dcbf047cc1c3a4e9de9940af0179c6169c0038b2a826d7ea4b868fcbc4e435928e8cbd25da3c1e56&bank_ref_no=6816991112151281&bank_ref_num=6816991112151281&bankcode=VISA&surl=http%3A%2F%2Fexample.com&curl=http%3A%2F%2Fexample.com&furl=http%3A%2F%2Fexample.com&card_hash=[FILTERED]\"}"
read 1012 bytes
Conn close
    POST_SCRUBBED
  end

  def successful_purchase_setup_response
    %({
      "status":"success",
      "response":{
        "form_post_vars":{
          "transactionId":"6e7e62723683934e6c5507675df11bdd86197c5c935878ff72e344205f3c8a1d",
          "pgId":"8",
          "eci":"7",
          "nonEnrolled":1,
          "nonDomestic":0,
          "bank":"VISA",
          "cccat":"creditcard",
          "ccnum":"4b5c9002295c6cd8e5289e2f9c312dc737810a747b84e71665cf077c78fe245a",
          "ccname":"53ab689fdb1b025c7e9c53c6b4a6e27f51e0d627579e7c12af2cb6cbc4944cc0",
          "ccvv":"cc8d6cfb6b03f94e2a64b490ae10c261c10747f543b1fba09d7f56f9ef6aac04",
          "ccexpmon":"5ddf3702e74f473ec89762f6efece025737c2ab999e695cf10496e6fa3946079",
          "ccexpyr":"5da83563fcaa945063dc4c2094c48e800badf7c8246c9d13b43757fe99d63e6d",
          "is_seamless":"1"
        },
        "post_uri":"https:\/\/test.payu.in\/hdfc_not_enrolled",
        "enrolled":"0"
      }
    })
  end

  def successful_purchase_response
    %({
      "status":"success",
      "result":"mihpayid=403993715512145540&mode=CC&status=success&key=Gzv04m&txnid=fcb18f5cd3d85d724b65ce2f541b7624&amount=11.00&addedon=2015-05-26+01%3A58%3A17&productinfo=Store+Purchase&firstname=Longbob&lastname=&address1=&address2=&city=&state=&country=&zipcode=&email=unknown%40example.com&phone=11111111111&udf1=&udf2=&udf3=&udf4=&udf5=&udf6=&udf7=&udf8=&udf9=&udf10=&card_token=&card_no=512345XXXXXX2346&field0=&field1=514682003588&field2=999999&field3=1424005580151461&field4=-1&field5=&field6=&field7=&field8=&field9=SUCCESS&PG_TYPE=HDFCPG&error=E000&error_Message=No+Error&net_amount_debit=11&unmappedstatus=success&hash=6768bf85d0046f7d57ab18804e2bc81ffb08d91eb9db9df89834e70a48e959c646ef00988fe7c5a0493741d7ceb7eaa2fa91a4932ce4c89c7ad49471c68f0008&bank_ref_no=1424005580151461&bank_ref_num=1424005580151461&bankcode=VISA&surl=http%3A%2F%2Fexample.com&curl=http%3A%2F%2Fexample.com&furl=http%3A%2F%2Fexample.com&card_hash=515a2cb0f0e6711f6a3d2c4704cc691d212d4dc0e065c7c8d3441a6b5fc23e97"
    })
  end

  def failed_purchase_response
    %({
      "status":"failed",
      "error":"Invalid amount  @~@ ExceptionConstant : INVALID_AMOUNT"
    })
  end

  def successful_refund_response
    %({
      "status":1,
      "msg":"Refund Request Queued",
      "request_id":"125199106",
      "bank_ref_num":null,
      "mihpayid":403993715512169368,
      "error_code":102
    })
  end

  def failed_refund_response
    %({
      "status":0,
      "msg":"Invalid payuid",
      "mihpayid":""
    })
  end

  def threedsecure_enrolled_response
    %({
      "status":"success",
      "response":{
        "post_uri":"https:\/\/dropit.3dsecure.net:9443\/PIT\/ACS",
        "form_post_vars":{
          "PaReq":"eJxVUl1X4jAQ\/Ss9ffXYNEWg5UzjAQXt6rIg+MFjTWOJC2lIUoT99ZvUsrp5ydzJnHvnzgQuD9uNt2dK80qkPg5C32OCVgUXZeo\/LifnsX9JYLlWjF0vGK0VI\/CTaZ2XzONF6vfC4\/RlEfVfn\/ZmNeZxZ4jjH2WUzF9o6hOYDR\/YjkArQCx\/EAE6Qcuk6DoXhkBOd6NsSi46nah\/AaiFsGUquyZvWnvfznkS2pP0Q0Cf7yDyLSPZKBv98j7YqzfbG+\/eFICaPNCqFkYdSafbA3QCUKsNWRsj9QAh3TiTpWHaBFZNMBPQKuACyfIjP6IyN8zdeVE0LQfvWgJyDIC+PMxqF2mreOAFiScbpqSSi+xelZJn5e4PjeXh5m61SgG5CigsLYlC3A27Ud\/DeBDiAbbzafKQb12r5EFjOzbrtcUgnczwE2DsXr5nwDpRdoUnuycE7CArwWyFFfgXA\/pq+urWrYEaO9BbPlmO6\/Hvm\/fn4ikpp2c7eTafp6lbTFPg2LidIu6FSUPnACBHgdqdo\/ab2Oi\/7\/MXv\/7OxQ==",
          "MD":"1094876012351471",
          "TermUrl":"https:\/\/test.payu.in\/_hdfc_response.php?txtid=0ce5251d1f1c07bfe1f5878d26db4010521e13b6bd6ace16c43ec591f7f7c9cb&action=hdfc2_3dsresponse"
        },
        "enrolled":"1"
      }
    })
  end

  def invalid_json_response
    %(<html>)
  end
end
