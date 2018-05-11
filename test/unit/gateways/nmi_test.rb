require 'test_helper'

class NmiTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = NmiGateway.new(fixtures(:nmi))

    @amount = 100
    @credit_card = credit_card
    @check = check
    @options = {}
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/username=#{@gateway.options[:login]}/, data)
      assert_match(/password=#{@gateway.options[:password]}/, data)
      assert_match(/type=sale/, data)
      assert_match(/amount=1.00/, data)
      assert_match(/payment=creditcard/, data)
      assert_match(/ccnumber=#{@credit_card.number}/, data)
      assert_match(/cvv=#{@credit_card.verification_value}/, data)
      assert_match(/ccexp=#{sprintf("%.2i", @credit_card.month)}#{@credit_card.year.to_s[-2..-1]}/, data)
      assert_not_match(/dup_seconds/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert response.test?
    assert_equal "2762757839#creditcard", response.authorization
  end

  def test_purchase_with_options
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card,
        recurring: true, order_id: "#1001", description: "AM test",
        currency: "GBP", dup_seconds: 15, customer: "123",
        merchant_defined_field_8: "value8")
    end.check_request do |endpoint, data, headers|
      assert_match(/billing_method=recurring/, data)
      assert_match(/orderid=#{CGI.escape("#1001")}/, data)
      assert_match(/orderdescription=AM\+test/, data)
      assert_match(/currency=GBP/, data)
      assert_match(/dup_seconds=15/, data)
      assert_match(/customer_id=123/, data)
      assert_match(/merchant_defined_field_8=value8/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert response.test?
    assert_equal "DECLINE", response.message
  end

  def test_successful_purchase_with_echeck
    response = stub_comms do
      @gateway.purchase(@amount, @check)
    end.check_request do |endpoint, data, headers|
      assert_match(/username=#{@gateway.options[:login]}/, data)
      assert_match(/password=#{@gateway.options[:password]}/, data)
      assert_match(/type=sale/, data)
      assert_match(/amount=1.00/, data)
      assert_match(/payment=check/, data)
      assert_match(/firstname=#{@check.first_name}/, data)
      assert_match(/lastname=#{@check.last_name}/, data)
      assert_match(/checkname=#{@check.name}/, CGI.unescape(data))
      assert_match(/checkaba=#{@check.routing_number}/, data)
      assert_match(/checkaccount=#{@check.account_number}/, data)
      assert_match(/account_holder_type=#{@check.account_holder_type}/, data)
      assert_match(/account_type=#{@check.account_type}/, data)
      assert_match(/sec_code=WEB/, data)
    end.respond_with(successful_echeck_purchase_response)

    assert_success response
    assert response.test?
    assert_equal "2762759808#check", response.authorization
  end

  def test_failed_purchase_with_echeck
    response = stub_comms do
      @gateway.purchase(@amount, @check)
    end.respond_with(failed_echeck_purchase_response)

    assert_failure response
    assert response.test?
    assert_equal "FAILED", response.message
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/username=#{@gateway.options[:login]}/, data)
      assert_match(/password=#{@gateway.options[:password]}/, data)
      assert_match(/type=auth/, data)
      assert_match(/payment=creditcard/, data)
      assert_match(/ccnumber=#{@credit_card.number}/, data)
      assert_match(/cvv=#{@credit_card.verification_value}/, data)
      assert_match(/ccexp=#{sprintf("%.2i", @credit_card.month)}#{@credit_card.year.to_s[-2..-1]}/, data)
    end.respond_with(successful_authorization_response)

    assert_success response
    assert_equal "2762787830#creditcard", response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/username=#{@gateway.options[:login]}/, data)
      assert_match(/password=#{@gateway.options[:password]}/, data)
      assert_match(/type=capture/, data)
      assert_match(/amount=1.00/, data)
      assert_match(/transactionid=2762787830/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorization_response)

    assert_failure response
    assert_equal "DECLINE", response.message
    assert response.test?
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(100, "")
    end.respond_with(failed_capture_response)

    assert_failure response
  end

  def test_successful_void
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "2762757839#creditcard", response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/username=#{@gateway.options[:login]}/, data)
      assert_match(/password=#{@gateway.options[:password]}/, data)
      assert_match(/type=void/, data)
      assert_match(/transactionid=2762757839/, data)
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void("5d53a33d960c46d00f5dc061947d998c")
    end.respond_with(failed_void_response)

    assert_failure response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "2762757839#creditcard", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/username=#{@gateway.options[:login]}/, data)
      assert_match(/password=#{@gateway.options[:password]}/, data)
      assert_match(/type=refund/, data)
      assert_match(/amount=1.00/, data)
      assert_match(/transactionid=2762757839/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, "")
    end.respond_with(failed_refund_response)

    assert_failure response
  end

  def test_successful_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/username=#{@gateway.options[:login]}/, data)
      assert_match(/password=#{@gateway.options[:password]}/, data)
      assert_match(/type=credit/, data)
      assert_match(/amount=1.00/, data)
      assert_match(/payment=creditcard/, data)
      assert_match(/ccnumber=#{@credit_card.number}/, data)
      assert_match(/cvv=#{@credit_card.verification_value}/, data)
      assert_match(/ccexp=#{sprintf("%.2i", @credit_card.month)}#{@credit_card.year.to_s[-2..-1]}/, data)
    end.respond_with(successful_credit_response)

    assert_success response

    assert_equal "2762828010#creditcard", response.authorization
    assert response.test?
  end

  def test_failed_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(failed_credit_response)

    assert_failure response
    assert response.test?
    assert_match "Invalid Credit Card", response.message
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/username=#{@gateway.options[:login]}/, data)
      assert_match(/password=#{@gateway.options[:password]}/, data)
      assert_match(/type=validate/, data)
      assert_match(/payment=creditcard/, data)
      assert_match(/ccnumber=#{@credit_card.number}/, data)
      assert_match(/cvv=#{@credit_card.verification_value}/, data)
      assert_match(/ccexp=#{sprintf("%.2i", @credit_card.month)}#{@credit_card.year.to_s[-2..-1]}/, data)
    end.respond_with(successful_validate_response)

    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(failed_validate_response)

    assert_failure response
    assert_match "Invalid Credit Card", response.message
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/username=#{@gateway.options[:login]}/, data)
      assert_match(/password=#{@gateway.options[:password]}/, data)
      assert_match(/customer_vault=add_customer/, data)
      assert_match(/payment=creditcard/, data)
      assert_match(/ccnumber=#{@credit_card.number}/, data)
      assert_match(/cvv=#{@credit_card.verification_value}/, data)
      assert_match(/ccexp=#{sprintf("%.2i", @credit_card.month)}#{@credit_card.year.to_s[-2..-1]}/, data)
    end.respond_with(successful_store_response)

    assert_success response
    assert response.test?
    assert_equal "Succeeded", response.message
    assert response.params["customer_vault_id"]
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(failed_store_response)

    assert_failure response
    assert response.test?
    assert_match "Invalid Credit Card", response.message
  end

  def test_successful_store_with_echeck
    response = stub_comms do
      @gateway.store(@check)
    end.check_request do |endpoint, data, headers|
      assert_match(/username=#{@gateway.options[:login]}/, data)
      assert_match(/password=#{@gateway.options[:password]}/, data)
      assert_match(/customer_vault=add_customer/, data)
      assert_match(/payment=check/, data)
      assert_match(/checkname=#{@check.name}/, CGI.unescape(data))
      assert_match(/checkaba=#{@check.routing_number}/, data)
      assert_match(/checkaccount=#{@check.account_number}/, data)
      assert_match(/account_holder_type=#{@check.account_holder_type}/, data)
      assert_match(/account_type=#{@check.account_type}/, data)
      assert_match(/sec_code=WEB/, data)
    end.respond_with(successful_echeck_store_response)

    assert_success response
    assert response.test?
    assert_equal "Succeeded", response.message
    assert response.params["customer_vault_id"]
  end

  def test_avs_result
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorization_response)

    assert_equal 'N', response.avs_result['code']
  end

  def test_cvv_result
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorization_response)

    assert_equal 'N', response.cvv_result['code']
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  def test_includes_cvv_tag
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{cvv}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_blank_cvv_not_sent
    @credit_card.verification_value = nil
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_no_match(%r{cvv}, data)
    end.respond_with(successful_purchase_response)

    @credit_card.verification_value = "  "
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_no_match(%r{cvv}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_supported_countries
    assert_equal 1,
      (['US'] | NmiGateway.supported_countries).size
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], NmiGateway.supported_cardtypes
  end

  def test_duplicate_window_deprecation
    assert_deprecation_warning(NmiGateway::DUP_WINDOW_DEPRECATION_MESSAGE) do
      NmiGateway.duplicate_window = nil
    end
  end

  private

  def successful_purchase_response
    'response=1&responsetext=SUCCESS&authcode=123456&transactionid=2762757839&avsresponse=N&cvvresponse=N&orderid=b6c1c57f709cfaa65a5cf5b8532ad181&type=&response_code=100'
  end

  def failed_purchase_response
    'response=2&responsetext=DECLINE&authcode=&transactionid=2762766725&avsresponse=N&cvvresponse=N&orderid=f4bd34a5a6089aa822d13352807bdf11&type=&response_code=200'
  end

  def successful_echeck_purchase_response
    'response=1&responsetext=SUCCESS&authcode=123456&transactionid=2762759808&avsresponse=&cvvresponse=&orderid=6780868212a4bc8d3d6ffc52d4873587&type=&response_code=100'
  end

  def failed_echeck_purchase_response
    'response=2&responsetext=FAILED&authcode=123456&transactionid=2762783009&avsresponse=&cvvresponse=&orderid=8070b75a09d75c3e84e1c17d44bbbf34&type=&response_code=200'
  end

  def successful_authorization_response
    'response=1&responsetext=SUCCESS&authcode=123456&transactionid=2762787830&avsresponse=N&cvvresponse=N&orderid=7655856b032e28d2106d724fc26cd04d&type=&response_code=100'
  end

  def failed_authorization_response
    'response=2&responsetext=DECLINE&authcode=&transactionid=2762789345&avsresponse=N&cvvresponse=N&orderid=1fe4a8b28a831c6f959d4204158e1ac1&type=&response_code=200'
  end

  def successful_capture_response
    'response=1&responsetext=SUCCESS&authcode=123456&transactionid=2762797441&avsresponse=N&cvvresponse=&orderid=&type=&response_code=100'
  end

  def failed_capture_response
    'response=2&responsetext=DECLINE&authcode=&transactionid=2762804008&avsresponse=N&cvvresponse=&orderid=&type=&response_code=200'
  end

  def successful_void_response
    'response=1&responsetext=Transaction Void Successful&authcode=123456&transactionid=2762811592&avsresponse=&cvvresponse=&orderid=33a327d76cfdb8e98946352607d80eb2&type=void&response_code=100'
  end

  def failed_void_response
    'response=3&responsetext=Only transactions pending settlement can be voided REFID:3161855545&authcode=&transactionid=2762816924&avsresponse=&cvvresponse=&orderid=&type=void&response_code=300'
  end

  def successful_refund_response
    'response=1&responsetext=SUCCESS&authcode=&transactionid=2762823772&avsresponse=&cvvresponse=&orderid=&type=refund&response_code=100'
  end

  def failed_refund_response
    'response=3&responsetext=Invalid Transaction ID specified REFID:3161856100&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=refund&response_code=300'
  end

  def successful_credit_response
    'response=1&responsetext=SUCCESS&authcode=&transactionid=2762828010&avsresponse=&cvvresponse=&orderid=3deb5bbdcba694a09fd7835263ee83ab&type=credit&response_code=100'
  end

  def failed_credit_response
    'response=3&responsetext=Invalid Credit Card Number REFID:3162207528&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=f95e02a07bb77447c8b2001795540771&type=credit&response_code=300'
  end

  def successful_validate_response
    'response=1&responsetext=SUCCESS&authcode=&transactionid=2762837000&avsresponse=N&cvvresponse=N&orderid=&type=validate&response_code=100'
  end

  def failed_validate_response
    'response=3&responsetext=Invalid Credit Card Number REFID:3162208770&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=validate&response_code=300'
  end

  def successful_store_response
    'response=1&responsetext=Customer Added&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=bc28d976f4eb7d379c0dffb5a21342ca&type=&response_code=100&customer_vault_id=256806849'
  end

  def failed_store_response
    'response=3&responsetext=Invalid Credit Card Number REFID:3162210328&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=d5efdca79fdc2770fbe56feca8ed5ee6&type=&response_code=300'
  end

  def successful_echeck_store_response
    'response=1&responsetext=Customer Added&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=35b5500a13d23a7e9706fdf3518556b3&type=&response_code=100&customer_vault_id=1910603011'
  end

  def transcript
    %q(
      amount=1.00&orderid=c9f2fb356d2a839d315aa6e8d7ed2404&orderdescription=Store+purchase&currency=USD&payment=creditcard&firstname=Longbob&lastname=Longsen&ccnumber=4111111111111111&cvv=917&ccexp=0916&email=&ipaddress=&company=Widgets+Inc&address1=456+My+Street&address2=Apt+1&city=Ottawa&state=ON&country=CA&zip=K1C2N6&phone=%28555%29555-5555&type=sale&username=demo&password=password
      response=1&responsetext=SUCCESS&authcode=123456&transactionid=2767466670&avsresponse=N&cvvresponse=N&orderid=c9f2fb356d2a839d315aa6e8d7ed2404&type=sale&response_code=100
      amount=1.00&orderid=e88df316d8ba3c8c6b98aa93b78facc0&orderdescription=Store+purchase&currency=USD&payment=check&checkname=Jim+Smith&checkaba=123123123&checkaccount=123123123&account_holder_type=personal&account_type=checking&sec_code=WEB&email=&ipaddress=&company=Widgets+Inc&address1=456+My+Street&address2=Apt+1&city=Ottawa&state=ON&country=CA&zip=K1C2N6&phone=%28555%29555-5555&type=sale&username=demo&password=password
      response=1&responsetext=SUCCESS&authcode=123456&transactionid=2767467157&avsresponse=&cvvresponse=&orderid=e88df316d8ba3c8c6b98aa93b78facc0&type=sale&response_code=100
    )
  end

  def scrubbed_transcript
    %q(
      amount=1.00&orderid=c9f2fb356d2a839d315aa6e8d7ed2404&orderdescription=Store+purchase&currency=USD&payment=creditcard&firstname=Longbob&lastname=Longsen&ccnumber=[FILTERED]&cvv=[FILTERED]&ccexp=0916&email=&ipaddress=&company=Widgets+Inc&address1=456+My+Street&address2=Apt+1&city=Ottawa&state=ON&country=CA&zip=K1C2N6&phone=%28555%29555-5555&type=sale&username=demo&password=[FILTERED]
      response=1&responsetext=SUCCESS&authcode=123456&transactionid=2767466670&avsresponse=N&cvvresponse=N&orderid=c9f2fb356d2a839d315aa6e8d7ed2404&type=sale&response_code=100
      amount=1.00&orderid=e88df316d8ba3c8c6b98aa93b78facc0&orderdescription=Store+purchase&currency=USD&payment=check&checkname=Jim+Smith&checkaba=[FILTERED]&checkaccount=[FILTERED]&account_holder_type=personal&account_type=checking&sec_code=WEB&email=&ipaddress=&company=Widgets+Inc&address1=456+My+Street&address2=Apt+1&city=Ottawa&state=ON&country=CA&zip=K1C2N6&phone=%28555%29555-5555&type=sale&username=demo&password=[FILTERED]
      response=1&responsetext=SUCCESS&authcode=123456&transactionid=2767467157&avsresponse=&cvvresponse=&orderid=e88df316d8ba3c8c6b98aa93b78facc0&type=sale&response_code=100
    )
  end
end
